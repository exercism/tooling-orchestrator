module Orchestrator
  class RequeueJob
    include Mandate
    initialize_with :job_id

    def call
      queued_key = Exercism::ToolingJob.key_for_queued
      locked_key = Exercism::ToolingJob.key_for_locked

      # Remove job from the locked queue
      # then add it back to the normal one
      begin
        redis.del(locked_key, job_id)
        redis.lpush(queued_key, job_id)
      rescue StandardError
        nil
      end
    end

    memoize
    def redis
      Exercism.redis_tooling_client
    end
  end
end


