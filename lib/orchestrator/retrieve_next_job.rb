module Orchestrator
  class RetrieveNextJob
    include Mandate

    def call
      job_id = queue.claim
      return if job_id.nil? || job_id.empty?

      job = find_job(job_id)

      # If a job's data has gone, nobody can run it. We drop it, so that it
      # can't block the queue.
      unless job
        queue.finish(job_id)
        return
      end

      # If a job already has a saved result, it must not run again, but the
      # website may not have the result yet. So we keep the job in `leased`
      # with a short deadline, and RecoverStrandedJobs will tell the website.
      # The soak test found this.
      if job.respond_to?(:execution_status)
        queue.hold(job_id)
        return
      end

      # We keep the `locked` list up to date for any code that still reads
      # it. If the job is lost, its lease will bring it back.
      redis.rpush(Exercism::ToolingJob.key_for_locked, job_id)
      job
    end

    private
    # When the job's data is missing, ToolingJob.find raises a TypeError. If
    # anything else goes wrong (for example, if we can't reach Redis), we
    # raise the error as normal, and the job's lease will bring the job back.
    def find_job(job_id)
      Exercism::ToolingJob.find(job_id)
    rescue TypeError, JSON::ParserError
      nil
    end

    def queue = Queue.instance
    def redis = Exercism.redis_tooling_client
  end
end
