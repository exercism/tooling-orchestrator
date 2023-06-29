require_relative 'base'

module Orchestrator
  class HttpProcessJobTest < SystemBaseTestCase
    def test_processes_job
      job_id = SecureRandom.uuid
      status = SecureRandom.uuid
      output = SecureRandom.uuid

      ProcessJob.expects(:call).with(
        job_id,
        {
          'status' => status,
          'output' => output
        },
        anything
      )
      patch("/jobs/#{job_id}", status:, output:)

      assert_equal 200, last_response.status
      assert_equal('{}', last_response.body)
    end
  end
end
