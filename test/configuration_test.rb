require 'test_helper'

module Orchestrator
  class ConfigurationTest < Minitest::Test
    def dynamodb_endpoint_proxies
      expected = mock
      Exercism.config.expects(:dynamodb_endpoint).returns(expected)
      assert_equal endpoint, config.dynamodb_endpoint
    end

    def jobs_table_proxies
      expected = mock
      Exercism.config.expects(:dynamodb_tooling_jobs_table).returns(expected)
      assert_equal endpoint, config.jobs_table
    end
  end
end
