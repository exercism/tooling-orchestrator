require 'test_helper'

module Orchestrator
  class RequeueJobTest < Minitest::Test
    def test_full_flow
      redis = Exercism.redis_tooling_client
      job = Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, :ruby, "two-fer")

      # Put the job onto the locked queue
      retrieved_job = Orchestrator::RetrieveNextJob.()

      # Sanity checks
      assert_equal job.id, retrieved_job.id
      assert_equal 1, redis.llen(Exercism::ToolingJob.key_for_locked)
      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_queued)

      RequeueJob.(job.id)

      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_locked)
      assert_equal 1, redis.llen(Exercism::ToolingJob.key_for_queued)
    end
  end
end
