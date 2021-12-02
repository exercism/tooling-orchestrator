module Orchestrator
  class ProcessBackgroundQueue
    include Mandate

    MAX_QUEUE_LENGTH = 10

    def call
      $stdout.sync = true
      $stderr.sync = true

      should_exist = false
      %w[INT TERM].each do |sig|
        trap sig do
          puts "Exit signal recieved"
          should_exist = true
        end
      end

      loop do
        break if should_exist

        sleep(1)
        execute
      rescue StandardError => e
        # If stuff goes wrong should we abort the machine
        # or should we just give it a shot. Maybe have a counter?
        puts e
      end
    end

    def execute
      count = MAX_QUEUE_LENGTH - redis.llen(Exercism::ToolingJob.key_for_queued)

      # This can be zero or a negative number
      return if count < 1

      # Note - this isn't in a transaction, so things could potentially get lost here
      ids = redis.lpop(Exercism::ToolingJob.key_for_queued_in_background, count)
      redis.rpush(Exercism::ToolingJob.key_for_queued, ids)
    end

    memoize
    def redis
      Exercism.redis_tooling_client
    end
  end
end
