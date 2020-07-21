require_relative 'base'

module Orchestrator
  class StatusTest < SystemBaseTestCase
    def test_status
      application.enqueue_job!(1)
      application.enqueue_job!(2)
      application.enqueue_job!(3)

      get "/status"
      assert_equal 200, last_response.status

      expected = {
        queue_length: 3
      }.to_json
      assert_equal expected, last_response.body
    end

    def test_next_iteration_no_job
      get "/iterations/next"
      assert_equal 404, last_response.status
      assert_equal Hash.new.to_json, last_response.body
    end
  end
end


