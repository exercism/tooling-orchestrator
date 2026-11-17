require 'test_helper'

module Orchestrator
  class ProcessJobTest < Minitest::Test
    def test_full_flow
      job = Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, "123", "", :ruby, "two-fer")
      RetrieveNextJob.()

      status = "really-great"
      output = {
        'representation.txt' => "Foobar",
        'mapping.json' => '{"foo": "bar"}'
      }

      expects_spi_patch(job.id)

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

      assert_nil Queue.instance.deadline(job.id)

      job = Exercism::ToolingJob.find(job.id)
      assert_equal output['representation.txt'], job.execution_output["representation.txt"]
      assert_equal output['mapping.json'], job.execution_output["mapping.json"]
    end

    # The invoker gets an error response, and the job keeps its lease, as it
    # does for any other failure to reach the website.
    def test_raises_and_keeps_the_lease_when_the_website_times_out
      job = Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, "123", "", :ruby, "two-fer")
      RetrieveNextJob.()

      expects_spi_patch(job.id).raises(RestClient::Exceptions::ReadTimeout)

      assert_raises(RestClient::Exceptions::ReadTimeout) do
        ProcessJob.(job.id, { 'status' => 200, 'output' => {} })
      end
      assert Queue.instance.deadline(job.id)
    end

    def test_copes_with_missing_data
      job = Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, "123", "", :ruby, "two-fer")
      expects_spi_patch(job.id)
      ProcessJob.(
        job.id,
        {
          'status' => 513
        }
      )
    end
  end
end
