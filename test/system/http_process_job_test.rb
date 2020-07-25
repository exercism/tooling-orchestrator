require_relative 'base'

module Orchestrator
  class HttpProcessJobTest < SystemBaseTestCase
    def test_processes_job
      job_id = SecureRandom.uuid
      status = SecureRandom.uuid
      result = SecureRandom.uuid
      context = SecureRandom.uuid
      invocation_data = SecureRandom.uuid

      ProcessJob.expects(:call).with(job_id, {
        'status' => status, 
        'result' => result,
        'context' => context,
        'invocation_data' => invocation_data
      }, anything)
      patch "/jobs/#{job_id}", 
        status: status, 
        result: result,
       context: context, 
        invocation_data: invocation_data

      assert_equal 200, last_response.status
      assert_equal Hash.new.to_json, last_response.body
    end
  end
end

