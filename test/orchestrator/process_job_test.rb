require 'test_helper'

module Orchestrator
  class ProcessJobTest < Minitest::Test
    def test_full_flow
      job = Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, "123", "", :ruby, "two-fer")

      status = "really-great"
      output = {
        'representation.txt' => "Foobar",
        'mapping.json' => '{"foo": "bar"}'
      }

      RestClient.expects(:patch).with(
        "#{Exercism.config.spi_url}/spi/tooling_jobs/#{job.id}",
        {}
      )

      ProcessJob.(
        job.id,
        {
          'status' => status,
          'output' => output
        }
      )

      redis = Exercism.redis_tooling_client
      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_locked)
      assert_equal 1, redis.llen(Exercism::ToolingJob.key_for_executed)

      job = Exercism::ToolingJob.find(job.id)
      assert_equal output['representation.txt'], job.execution_output["representation.txt"]
      assert_equal output['mapping.json'], job.execution_output["mapping.json"]
    end

    def test_copes_with_missing_data
      job = Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, "123", "", :ruby, "two-fer")
      RestClient.expects(:patch)
      ProcessJob.(
        job.id,
        {
          'status' => 513
        }
      )
    end
  end
end
