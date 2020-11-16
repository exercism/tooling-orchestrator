require_relative 'base'

module Orchestrator
  class HttpNextJobTest < SystemBaseTestCase
    def test_with_job
      job = Job.new(nil, 1, nil, nil)

      RetrieveNextJob.expects(:call).returns(job)
      get "/jobs/next"
      assert_equal 200, last_response.status
      assert_equal job.to_h.to_json, last_response.body
    end

    def test_with_no_job
      RetrieveNextJob.expects(:call).returns(nil)

      get "/jobs/next"
      assert_equal 404, last_response.status
    end
  end
end
