module Orchestrator
  class RetrieveNextJob
    include Mandate

    def call
      queued_key = Exercism::ToolingJob.key_for_queued
      locked_key = Exercism::ToolingJob.key_for_locked

      job_id = redis.lpop(queued_key)
      return unless job_id && job_id != ""

      begin
        redis.rpush(locked_key, job_id)
        Exercism::ToolingJob.find(job_id)
      rescue StandardError
        redis.lpush(queued_key, job_id)
        nil
      end
    end

    memoize
    def redis
      Exercism.redis_tooling_client
    end
  end
end
