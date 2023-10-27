# Background queue length:
# Exercism.redis_tooling_client.llen(Exercism::ToolingJob.key_for_queued_for_background_processing)
module Orchestrator
  class ProcessBackgroundQueue
    include Mandate

    MAX_QUEUE_LENGTH = 25

    def call
      $stdout.sync = true
      $stderr.sync = true

      puts "|| Starting background queue processor"

      should_exit = false
      %w[INT TERM].each do |sig|
        trap sig do
          puts "Exit signal recieved"
          should_exit = true
        end
      end

      loop do
        break if should_exit

        sleep(0.1)
        execute
      rescue StandardError => e
        # If stuff goes wrong should we abort the machine
        # or should we just give it a shot. Maybe have a counter?
        puts e
      end
    end

    def execute
      if redis.llen(Exercism::ToolingJob.key_for_queued_for_background_processing).zero?
        sleep(1)
        return
      end

      count = MAX_QUEUE_LENGTH - redis.llen(Exercism::ToolingJob.key_for_queued)

      # This can be zero or a negative number
      return if count < 1

      puts "|| Moving #{count} jobs from background queue"

      # In Redis 6.2 we could use the count in lpop
      count.times do
        # Note - this isn't in a transaction, so things could potentially get lost here
        id = redis.lpop(Exercism::ToolingJob.key_for_queued_for_background_processing)
        redis.rpush(Exercism::ToolingJob.key_for_queued, id) if id
      end
    end

    memoize
    def redis
      Exercism.redis_tooling_client
    end
  end
end
