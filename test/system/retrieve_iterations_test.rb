require_relative 'base'

module Orchestrator
  class RetrieveIterationsTest < SystemBaseTestCase
    def test_next_iteration_no_job
      get "/jobs/next"
      assert_equal 404, last_response.status
      assert_equal Hash.new.to_json, last_response.body
    end
  end
end
