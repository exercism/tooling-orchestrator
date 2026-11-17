# This script runs the soak test. It starts the real orchestrator, fake
# invokers and a fake website, pushes jobs through while it breaks things,
# and then checks that no job was lost. See the README for how to run it.
require_relative 'boot'
require 'net/http'
require 'socket'
require 'fileutils'

module Soak
  MODE = ENV.fetch('SOAK_MODE', 'ci')
  CI = MODE == 'ci'
  def self.setting(name, in_ci:, long:)
    value = ENV.fetch(name, '')
    return Integer(value) unless value.empty?

    CI ? in_ci : long
  end

  SEED = setting('SOAK_SEED', in_ci: 1234, long: rand(1_000_000))
  JOBS = setting('SOAK_JOBS', in_ci: 300, long: 3000)
  JOBS_PER_SECOND = CI ? 5.0 : 10.0
  TASKS = 2
  INVOKERS = CI ? 8 : 16
  BACKGROUND_SHARE = 0.3
  DRAIN_SECONDS = CI ? 90 : 180
  PORTS = (0...TASKS).map { |i| 4000 + i }.freeze
  SPI_PORT = 4100
  ROOT = File.expand_path('..', __dir__)
  LOG_DIR = File.join(ROOT, 'soak', 'tmp', 'logs').freeze

  # One job in every POISON_EVERY is a poison job. Every invoker that takes
  # it hands it back, so it will end with status 514.
  POISON_EVERY = 40

  def self.log(message) = puts("[soak #{Time.now.strftime('%H:%M:%S')}] #{message}")

  # This records what the fake invokers and the chaos do, so that a failure
  # can be traced through the orchestrator's logs.
  EVENTS_MUTEX = Mutex.new
  def self.event(message)
    EVENTS_MUTEX.synchronize do
      @events ||= File.open(File.join(LOG_DIR, 'events.log'), 'w').tap { |file| file.sync = true }
      @events.puts("#{Time.now.strftime('%H:%M:%S.%L')} #{message}")
    end
  end

  def self.poison?(id) = id.split('-').last.to_i % POISON_EVERY == POISON_EVERY - 1
  def self.redis = Exercism.redis_tooling_client

  # The three Valkey nodes start empty. This splits the hash slots between
  # them and joins them into one cluster, as valkey-cli --cluster create would.
  module Cluster
    def self.create!
      hosts = NODES.map { |url| URI(url) }
      clients = hosts.map { |uri| Redis.new(host: uri.host, port: uri.port) }
      wait_until("Valkey to start") { clients.all? { |c| alive?(c) } }

      if clients.first.cluster('INFO').include?('cluster_state:ok')
        Soak.log("The cluster already exists")
        return
      end

      slots = (0..16_383).each_slice((16_384 / clients.size.to_f).ceil).to_a
      clients.zip(slots).each { |client, range| client.cluster('ADDSLOTSRANGE', range.first, range.last) }
      hosts.drop(1).each do |uri|
        ip = Addrinfo.getaddrinfo(uri.host, nil, :INET).first.ip_address
        clients.first.cluster('MEET', ip, uri.port)
      end
      wait_until("the cluster to form") { clients.all? { |c| c.cluster('INFO').include?('cluster_state:ok') } }
      Soak.log("Created a #{clients.size}-node cluster")
    end

    def self.alive?(client)
      client.ping == 'PONG'
    rescue StandardError
      false
    end

    def self.wait_until(what, seconds: 60)
      deadline = Time.now + seconds
      until yield
        raise "Timed out waiting for #{what}" if Time.now > deadline

        sleep 0.5
      end
    end
  end

  # This is a fake version of the website's SPI endpoint. Like the real
  # website, it reads the job's result, records it, and deletes the job's
  # record. If the record has already gone, it returns an error, as the real
  # website would. While it is "slow", it waits longer than the
  # orchestrator's timeout before it does any of this. While it is
  # "failing", it returns errors.
  class Website
    attr_reader :results, :calls
    attr_accessor :mode

    def initialize
      @mode = :normal
      @results = {}
      @calls = Hash.new(0)
      @mutex = Mutex.new
    end

    def start!
      server = TCPServer.new('0.0.0.0', SPI_PORT)
      Thread.new { loop { Thread.new(server.accept) { |socket| handle(socket) } } }
    end

    private
    def handle(socket)
      request_line = socket.gets.to_s
      length = 0
      while (line = socket.gets) && line != "\r\n"
        length = line.split(':', 2).last.to_i if line.downcase.start_with?('content-length')
      end
      socket.read(length) if length.positive?

      id = request_line[%r{/spi/tooling_jobs/([^ ?]+)}, 1]
      respond(socket, receive(id) ? 200 : 500)
    rescue StandardError
      nil
    ensure
      close(socket)
    end

    def close(socket)
      socket.close
    rescue StandardError
      nil
    end

    def receive(id)
      case mode
      when :failing then return false
      when :slow then sleep 6
      end

      job = Exercism::ToolingJob.find(id)
      @mutex.synchronize do
        @calls[id] += 1
        @results[id] ||= job.execution_status.to_i
      end
      job.processed!
      true
    rescue TypeError, JSON::ParserError
      false
    end

    def respond(socket, status)
      socket.write("HTTP/1.1 #{status} X\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}")
    end
  end

  # This is a fake invoker. It long-polls a random orchestrator task, as the
  # load balancer would, "runs" the job for a random time and reports a
  # result. Now and then it hands the job back, as a real invoker does when
  # its health check fails.
  class Invoker
    def initialize(index, runs, mutex)
      @index = index
      @rng = Random.new(SEED + index)
      @runs = runs
      @mutex = mutex
    end

    def start! = @thread = Thread.new { work }

    def kill!
      Soak.event("invoker #{@index} killed while holding #{@job_id || 'nothing'}")
      @thread&.kill
    end

    private
    def work
      loop do
        port = PORTS.sample(random: @rng)
        response = request(Net::HTTP::Get, port, '/jobs/next?wait=5')
        next sleep(0.1) unless response&.code == '200'

        run(port, JSON.parse(response.body)['id'])
      rescue StandardError
        sleep 0.2
      end
    end

    def run(port, id)
      @job_id = id
      @mutex.synchronize { @runs[id] += 1 }
      Soak.event("invoker #{@index} took #{id} from task #{port}")
      sleep(@rng.rand < 0.1 ? @rng.rand(3.0..10.0) : @rng.rand(0.0..1.5))

      if Soak.poison?(id) || @rng.rand < 0.03
        code = request(Net::HTTP::Patch, port, "/jobs/#{id}/requeue")&.code
        Soak.event("invoker #{@index} handed back #{id} (#{code})")
        return
      end

      body = URI.encode_www_form('status' => 200, 'output[results.json]' => '{"status":"pass"}')
      2.times do
        code = request(Net::HTTP::Patch, port, "/jobs/#{id}", body)&.code
        Soak.event("invoker #{@index} reported #{id} (#{code})")
        break if code == '200'
      end
    ensure
      @job_id = nil
    end

    def request(klass, port, path, body = nil)
      http = Net::HTTP.new('127.0.0.1', port)
      http.read_timeout = 30
      request = klass.new(path)
      if body
        request.body = body
        request.content_type = 'application/x-www-form-urlencoded'
      end
      http.request(request)
    rescue StandardError
      nil
    end
  end

  # This starts and stops the orchestrator's processes. Each task runs Puma
  # and the background process, as an ECS task does.
  class Orchestrators
    def initialize
      FileUtils.mkdir_p(LOG_DIR)
      @pids = {}
    end

    def start_all!
      PORTS.each_index do |task|
        start!(task, :web)
        start!(task, :background)
      end
    end

    def restart!(task, kind)
      Soak.event("restarting #{kind} process of task #{task}")
      kill(@pids[[task, kind]])
      start!(task, kind)
    end

    def stop_all!
      @pids.each_value { |pid| kill(pid) }
    end

    def given_up_ids
      Dir["#{LOG_DIR}/*.log"].flat_map do |file|
        File.read(file).scan(/Gave up telling the website about job (\S+) after/).flatten
      end.uniq
    end

    private
    def kill(pid)
      Process.kill('KILL', pid)
      Process.wait(pid)
    rescue StandardError
      nil
    end

    def start!(task, kind)
      command =
        if kind == :web
          "bundle exec puma -C config/puma.rb -b tcp://127.0.0.1:#{PORTS[task]} soak/config.ru"
        else
          'bundle exec ruby soak/background.rb'
        end
      log = File.open("#{LOG_DIR}/#{kind}-#{task}.log", 'a')
      @pids[[task, kind]] = Process.spawn(command, chdir: ROOT, out: log, err: log)
    end
  end

  # This picks something to break every few seconds.
  class Chaos
    def initialize(rng, invokers, orchestrators, website)
      @rng = rng
      @invokers = invokers
      @orchestrators = orchestrators
      @website = website
      @counts = Hash.new(0)
    end

    attr_reader :counts

    def start! = @thread = Thread.new { loop { sleep(@rng.rand(1.0..4.0)) && strike! } }
    def stop! = @thread&.kill

    private
    def strike!
      roll = @rng.rand
      if roll < 0.4
        kill_invoker!
      elsif roll < 0.55
        restart!(:web)
      elsif roll < 0.75
        restart!(:background)
      elsif roll < 0.85
        break_website!(:slow)
      else
        break_website!(:failing)
      end
    end

    def kill_invoker!
      index = @rng.rand(@invokers.size)
      @invokers[index].kill!
      @invokers[index].start!
      @counts[:invokers_killed] += 1
    end

    def restart!(kind)
      @orchestrators.restart!(@rng.rand(TASKS), kind)
      @counts[:"#{kind}_restarts"] += 1
    end

    def break_website!(mode)
      seconds = mode == :failing ? @rng.rand(3.0..15.0) : @rng.rand(3.0..8.0)
      @counts[:"website_#{mode}"] += 1
      Soak.event("website #{mode} for #{seconds.round(1)}s")
      Thread.new do
        @website.mode = mode
        sleep seconds
        @website.mode = :normal
      end
    end
  end

  # These are all the keys added by the new queue code. Once every job has
  # finished, each one should be empty.
  def self.queue_keys
    queue = Orchestrator::Queue.instance
    {
      queue.queued_key => :llen, queue.background_key => :llen,
      queue.leased_key => :llen, queue.deadlines_key => :hlen,
      queue.reclaims_key => :hlen, queue.reports_key => :hlen,
      queue.moving_key => :llen, queue.moving_since_key => :hlen
    }
  end

  def self.leftover_keys(ids)
    queue = Orchestrator::Queue.instance
    left = queue_keys.filter_map do |key, size|
      count = redis.send(size, key)
      next unless count.positive?

      members = size == :llen ? redis.lrange(key, 0, 4) : redis.hkeys(key).first(5)
      "#{key} (#{count}: #{members.join(', ')})"
    end
    ids.each do |id|
      left << queue.taken_key(id) if redis.exists?(queue.taken_key(id))
      left << queue.recovering_key(id) if redis.exists?(queue.recovering_key(id))
    end
    left
  end

  def self.up?(port)
    Net::HTTP.get_response(URI("http://127.0.0.1:#{port}/")).code == '200'
  rescue StandardError
    false
  end

  def self.clear!
    queue_keys.each_key { |key| redis.del(key) }
  end

  def self.run!
    log("Mode: #{MODE}, seed: #{SEED}, jobs: #{JOBS}")
    log("To repeat this run, set SOAK_SEED=#{SEED} SOAK_JOBS=#{JOBS} SOAK_MODE=#{MODE}")
    FileUtils.rm_rf(LOG_DIR)
    FileUtils.mkdir_p(LOG_DIR)
    Cluster.create!
    clear!

    rng = Random.new(SEED)
    website = Website.new
    website.start!
    orchestrators = Orchestrators.new
    orchestrators.start_all!
    Cluster.wait_until("the orchestrator to start") do
      PORTS.all? { |port| up?(port) }
    end

    runs = Hash.new(0)
    mutex = Mutex.new
    invokers = Array.new(INVOKERS) { |i| Invoker.new(i, runs, mutex).tap(&:start!) }
    chaos = Chaos.new(rng, invokers, orchestrators, website)
    chaos.start!

    ids = Array.new(JOBS) { |i| "soak-#{SEED}-#{i}" }
    ids.each do |id|
      background = rng.rand < BACKGROUND_SHARE
      Exercism::ToolingJob.create!(
        id, :test_runner, SecureRandom.uuid, '', :ruby, 'two-fer', run_in_background: background
      )
      sleep(1 / JOBS_PER_SECOND)
    end
    log("Created #{JOBS} jobs. Stopping the chaos and waiting for the queue to drain.")
    chaos.stop!
    website.mode = :normal

    wait("every job to reach the website") { (ids - website.results.keys - orchestrators.given_up_ids).empty? }

    # A fake invoker may still be running a second copy of a job that has
    # already finished. Once every job has reached the website, we stop the
    # invokers, as if their machines had died. The orchestrator then has time
    # to clear up any copy that they were holding, before we check the keys.
    invokers.each(&:kill!)
    wait("every queue key to empty") { leftover_keys(ids).empty? }

    lost = ids - website.results.keys - orchestrators.given_up_ids
    left = leftover_keys(ids)
    orchestrators.stop_all!
    report(ids, website, orchestrators, runs, chaos, lost, left)
  end

  def self.wait(what, &)
    Cluster.wait_until(what, seconds: DRAIN_SECONDS, &)
  rescue RuntimeError => e
    log(e.message)
  end

  def self.report(ids, website, orchestrators, runs, chaos, lost, left)
    gave_up = orchestrators.given_up_ids & ids
    statuses = website.results.values.tally
    ran_twice = runs.count { |_, n| n > 1 }

    log("Chaos: #{chaos.counts.sort.map { |k, v| "#{k}=#{v}" }.join(', ')}")
    by_status = statuses.sort.map { |s, n| "#{s}: #{n}" }.join(', ')
    log("Jobs: #{ids.size}. The website got a result for #{website.results.size} (#{by_status}).")
    log("The orchestrator gave up telling the website about #{gave_up.size} jobs.")
    log("#{ran_twice} jobs ran more than once. The most runs for one job was #{runs.values.max || 0}.")
    log("#{website.calls.count { |_, n| n > 1 }} jobs reached the website more than once.")

    if lost.empty? && left.empty?
      log("PASS: no job was lost, and every queue key is empty.")
      exit 0
    end

    log("FAIL: #{lost.size} jobs were lost: #{lost.first(20).join(', ')}") unless lost.empty?
    log("FAIL: these keys are not empty: #{left.first(20).join(', ')}") unless left.empty?
    (lost + left.flat_map { |entry| entry.scan(/soak-\d+-\d+/) }).uniq.first(5).each do |id|
      lines = Dir["#{LOG_DIR}/*.log"].flat_map do |file|
        File.readlines(file).grep(/#{id}\b/).map { |line| "#{File.basename(file)}: #{line}" }
      end
      log("Log lines for #{id}:\n#{lines.first(40).join}")
    end
    exit 1
  end
end

Soak.run!
