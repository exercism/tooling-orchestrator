require 'test_helper'

module Orchestrator
  class ProcessJobTest < Minitest::Test
    def test_full_flow
      job_id = SecureRandom.uuid
      status = SecureRandom.uuid
      output = {
        'representation.txt' => "Foobar",
        'mapping.json' => '{"foo": "bar"}'
      }

      RestClient.expects(:patch).with(
        "#{Exercism.config.spi_url}/spi/tooling_jobs/#{job_id}",
        {}
      )

      ProcessJob.(
        job_id,
        {
          'status' => status,
          'output' => output
        }, Exercism.dynamodb_client
      )

      attrs = fetch_job_attrs(job_id)
      assert_equal "executed", attrs['job_status']
      assert_equal status, attrs['execution_status']
      assert_nil attrs['locked_until']

      assert_equal output['representation.txt'], attrs["execution_output"]["representation.txt"]
      assert_equal output['mapping.json'], attrs["execution_output"]["mapping.json"]
    end

    def test_copes_with_missing_data
      RestClient.expects(:patch)
      ProcessJob.(
        SecureRandom.uuid,
        {
          'status' => 513
        }, Exercism.dynamodb_client
      )
    end
  end
end
