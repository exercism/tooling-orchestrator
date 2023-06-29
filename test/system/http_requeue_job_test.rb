require_relative 'base'

module Orchestrator
  class HttpProcessJobTest < SystemBaseTestCase
    def test_requeues_job
      job_id = SecureRandom.uuid

      RequeueJob.expects(:call).with(job_id)
      patch "/jobs/#{job_id}/requeue"

      assert_equal 200, last_response.status
      assert_equal('{}', last_response.body)
    end
  end
end
