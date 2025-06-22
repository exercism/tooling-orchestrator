require 'test_helper'

module Orchestrator
  class RetrieveNextJobTest < Minitest::Test
    def test_full_flow
      job_1 = Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, "123", "", :ruby, "two-fer")
      Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, "123", "", :ruby, "two-fer")

      redis = Exercism.redis_tooling_client
      assert_equal 2, redis.llen(Exercism::ToolingJob.key_for_queued)
      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_locked)

      assert_equal job_1, RetrieveNextJob.()
      assert_equal 1, redis.llen(Exercism::ToolingJob.key_for_queued)
      assert_equal 1, redis.llen(Exercism::ToolingJob.key_for_locked)

      assert_equal job_1.id, redis.lindex(Exercism::ToolingJob.key_for_locked, 0)
    end

    def test_no_jobs
      assert_nil RetrieveNextJob.()
    end
  end
end
