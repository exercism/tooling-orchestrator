require_relative 'base'

module Orchestrator
  class HttpProcessJobTest < SystemBaseTestCase
    def test_processes_job
      job_id = SecureRandom.uuid
      status = SecureRandom.uuid
      output = SecureRandom.uuid
      context = SecureRandom.uuid
      invocation_data = SecureRandom.uuid

      ProcessJob.expects(:call).with(
        job_id,
        {
          'status' => status,
          'output' => output,
          'context' => context,
          'invocation_data' => invocation_data
        },
        anything
      )
      patch "/jobs/#{job_id}",
            status: status,
            output: output,
            context: context,
            invocation_data: invocation_data

      assert_equal 200, last_response.status
      assert_equal('{}', last_response.body)
    end
  end
end
