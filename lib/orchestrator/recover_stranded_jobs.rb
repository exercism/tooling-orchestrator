module Orchestrator
  # This command deals with jobs that have run out of time. Every
  # orchestrator task runs it. Before a task deals with a job, it takes the
  # job (see Queue#take), so only one task deals with each job at a time.
  #
  # If a job already has a saved result, the website hasn't heard about it
  # yet, so we tell the website again. We never run that job again.
  #
  # Otherwise the machine that was running the job has probably died, so we
  # put the job back on the queue. If it has gone back too many times, we
  # give up and fail it.
  class RecoverStrandedJobs
    include Mandate

    # Calls to the website can be slow, so we make no more than this many in
    # one pass. Any other jobs stay out of time, and the next pass deals with
    # them.
    MAX_WEBSITE_CALLS_PER_PASS = 5

    def call
      recover_jobs_out_of_time
    end

    private
    def recover_jobs_out_of_time
      website_calls = 0

      queue.expired_ids.each do |job_id|
        break if website_calls >= MAX_WEBSITE_CALLS_PER_PASS
        next unless queue.take(job_id)

        website_calls += 1 if deal_with(job_id)
      rescue StandardError => e
        # We still hold the job for RETRY_SECONDS. After that, a later pass
        # will try again.
        log("Could not deal with job #{job_id}: #{e.message}")
        website_calls += 1
      end
    end

    # This returns true if it called the website.
    def deal_with(job_id)
      # If an invoker finished the job a moment ago, there is nothing to do.
      return false unless queue.leased?(job_id)

      job = find_job(job_id)

      # If the job's data has gone, nobody can run it or report it, so we
      # drop it.
      unless job
        queue.finish(job_id)
        return false
      end

      return inform_spi(job_id) if job.respond_to?(:execution_status)

      requeue(job_id)
    end

    def inform_spi(job_id)
      attempts = queue.count_report_attempt(job_id)
      if attempts > Orchestrator.config.max_report_attempts
        log("Gave up telling the website about job #{job_id} after #{attempts - 1} attempts.")
        queue.finish(job_id)
        return false
      end

      InformSPI.(job_id)
      queue.finish(job_id)
      true
    end

    def requeue(job_id)
      if queue.requeue(job_id) == :failed
        FailExhaustedJob.(job_id)
        forget_lock(job_id)
        return true
      end

      log("Job #{job_id} ran out of time, so we put it back on the queue.")
      forget_lock(job_id)
      false
    end

    def forget_lock(job_id) = redis.lrem(Exercism::ToolingJob.key_for_locked, 1, job_id)

    # When the job's data is missing, ToolingJob.find raises a TypeError.
    def find_job(job_id)
      Exercism::ToolingJob.find(job_id)
    rescue TypeError, JSON::ParserError
      nil
    end

    def log(message) = Application.instance.log(message)
    def queue = Queue.instance
    def redis = Exercism.redis_tooling_client
  end
end
