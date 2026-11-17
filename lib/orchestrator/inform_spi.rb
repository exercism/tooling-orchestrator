module Orchestrator
  # This tells the website that a job's result is ready. If the call fails,
  # it raises an error.
  class InformSPI
    include Mandate
    initialize_with :job_id

    # RecoverStrandedJobs also makes this call, so we use short timeouts. Then
    # a slow website can't hold it up. RestClient's default is about 60
    # seconds.
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 5

    def call
      RestClient::Request.execute(
        method: :patch,
        url: "#{Exercism.config.spi_url}/spi/tooling_jobs/#{job_id}",
        payload: {},
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT
      )
    end
  end
end
