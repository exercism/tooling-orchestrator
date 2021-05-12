require 'test_helper'

module Orchestrator
  class RetrieveNextJobTest < Minitest::Test
    def test_full_flow
      job_1_id = Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, :ruby, "two-fer")
      Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, :ruby, "two-fer")

      redis = Exercism.redis_tooling_client
      assert_equal 2, redis.llen(Exercism::ToolingJob.key_for_queued)
      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_locked)

      assert_equal job_1_id, RetrieveNextJob.().id
      assert_equal 1, redis.llen(Exercism::ToolingJob.key_for_queued)
      assert_equal 1, redis.llen(Exercism::ToolingJob.key_for_locked)

      assert_equal job_1_id, redis.lindex(Exercism::ToolingJob.key_for_locked, 0)
    end

    def test_no_jobs
      assert_nil RetrieveNextJob.()
    end
  end
end
