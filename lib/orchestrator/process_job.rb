module Orchestrator
  class ProcessJob
    include Mandate
    initialize_with :job_id, :data

    def call
      update_job
      inform_spi
      # rescue
      # TODO - Re-enqueue the job?
    end

    private
    def update_job
      job = Exercism::ToolingJob.find(job_id)
      job.executed!(data['status'], data['output'], data['exception'])
    end

    def inform_spi
      RestClient.patch(
        "#{Exercism.config.spi_url}/spi/tooling_jobs/#{job_id}",
        {}
      )
    end
  end
end
