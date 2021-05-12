require 'test_helper'

module Orchestrator
  class ProcessJobTest < Minitest::Test
    def test_full_flow
      job_id = Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, :ruby, "two-fer")

      status = "really-great"
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
        }
      )

      job = Exercism::ToolingJob.find(job_id)

      redis = Exercism.redis_tooling_client
      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_locked)
      assert_equal 1, redis.llen(Exercism::ToolingJob.key_for_executed)

      assert_equal output['representation.txt'], job.execution_output["representation.txt"]
      assert_equal output['mapping.json'], job.execution_output["mapping.json"]
    end

    def test_copes_with_missing_data
      job_id = Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, :ruby, "two-fer")
      RestClient.expects(:patch)
      ProcessJob.(
        job_id,
        {
          'status' => 513
        }
      )
    end
  end
end
