require 'test_helper'

module Orchestrator
  class ProcessJobTest < Minitest::Test
    def test_full_flow
      job_id = SecureRandom.uuid
      status = SecureRandom.uuid
      result = SecureRandom.uuid
      context = SecureRandom.uuid
      invocation_data = SecureRandom.uuid

      RestClient.expects(:patch).with(
        "#{Exercism.config.spi_url}/spi/tooling_jobs/#{job_id}",
        {}
      )

      ProcessJob.(job_id, {
                    'status' => status,
                    'result' => result,
                    'context' => context,
                    'invocation_data' => invocation_data
                  }, ExercismConfig::SetupDynamoDBClient.())

      attrs = fetch_job_attrs(job_id)
      assert_equal "executed", attrs['job_status']
      assert_equal result, attrs['result']
      assert_equal status, attrs['execution_status']
      assert_equal context, attrs['execution_context']
      assert_equal invocation_data, attrs['execution_invocation_data']
      assert_nil attrs['locked_until']
    end
  end
end
