module Orchestrator
  class ProcessJob
    include Mandate
    initialize_with :job_id, :data

    def call
      Queue.instance.hold(job_id)
      update_job
      InformSPI.(job_id)

      # Once the website knows the result, we release the job's lease. If the
      # call to the website fails, the background process will keep retrying
      # it until the website has the result.
      Queue.instance.finish(job_id)
    end

    private
    def update_job
      job = Exercism::ToolingJob.find(job_id)
      job.executed!(data['status'], data['output'])
    end
  end
end
