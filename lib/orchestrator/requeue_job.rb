module Orchestrator
  # When an invoker has taken a job but can't run it, because its own health
  # check failed, the invoker calls this. We then put the job back at the
  # front of the queue. This counts as one of the job's limited attempts.
  # Otherwise a job that breaks machines would go back on the queue forever.
  class RequeueJob
    include Mandate
    initialize_with :job_id

    def call
      if !queue.leased?(job_id)
        requeue_unleased_job
      elsif already_has_result?
        # Another invoker has already reported this job, so it mustn't run
        # again. If the website doesn't have the result yet,
        # RecoverStrandedJobs will tell it.
        nil
      elsif queue.take(job_id)
        FailExhaustedJob.(job_id) if queue.requeue(job_id) == :failed
        redis.lrem(locked_key, 1, job_id)
      end

      # If someone else has already taken the job, RecoverStrandedJobs is
      # dealing with it, so we leave it alone.
    end

    private
    def already_has_result?
      Exercism::ToolingJob.find(job_id).respond_to?(:execution_status)
    rescue TypeError, JSON::ParserError
      false
    end

    # If an older orchestrator handed out the job, the job isn't in `leased`,
    # and is only on `locked`. If it is still there, this puts it back on the
    # queue. If it isn't there, something else has already dealt with it.
    def requeue_unleased_job
      return unless redis.lrem(locked_key, 1, job_id).positive?

      redis.lpush(Exercism::ToolingJob.key_for_queued, job_id)
    end

    def queue = Queue.instance
    def locked_key = Exercism::ToolingJob.key_for_locked
    def redis = Exercism.redis_tooling_client
  end
end
