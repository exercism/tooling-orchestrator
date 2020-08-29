require 'test_helper'

module Orchestrator
  class ProcessJobTest < Minitest::Test
    def test_full_flow
      job_id = SecureRandom.uuid
      status = SecureRandom.uuid
      context = SecureRandom.uuid
      invocation_data = SecureRandom.uuid
      output = {
        'representation.txt' => "Foobar",
        'mapping.json' => '{"foo": "bar"}'
      }

      RestClient.expects(:patch).with(
        "#{Exercism.config.spi_url}/spi/tooling_jobs/#{job_id}",
        {}
      )

      ProcessJob.(job_id, {
                    'status' => status,
                    'output' => output,
                    'context' => context,
                    'invocation_data' => invocation_data
                  }, ExercismConfig::SetupDynamoDBClient.())

      attrs = fetch_job_attrs(job_id)
      assert_equal "executed", attrs['job_status']
      assert_equal status, attrs['execution_status']
      assert_equal context, attrs['execution_context']
      assert_equal invocation_data, attrs['execution_invocation_data']
      assert_nil attrs['locked_until']

      assert_equal output["representation.txt"],
                   download_s3_file(
                     Exercism.config.aws_tooling_jobs_bucket,
                     attrs['output']["representation.txt"]
                   )

      assert_equal output["mapping.json"],
                   download_s3_file(
                     Exercism.config.aws_tooling_jobs_bucket,
                     attrs['output']["mapping.json"]
                   )
    end
  end
end
