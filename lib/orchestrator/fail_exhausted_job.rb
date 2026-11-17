module Orchestrator
  # This command gives up on a job that has gone back on the queue too many
  # times, and marks it as failed. It reports the failure to the website in
  # the same way as a result from an invoker, so the student will see an
  # error.
  class FailExhaustedJob
    include Mandate
    initialize_with :job_id

    def call
      Application.instance.log("Job #{job_id} has gone back on the queue too many times, so we are failing it.")
      ProcessJob.(job_id, { 'status' => Queue::RECLAIMS_EXHAUSTED_STATUS })
    rescue TypeError, JSON::ParserError
      # The job's data has gone, so there is nothing to report. Just drop it.
      Queue.instance.finish(job_id)
    end
  end
end
