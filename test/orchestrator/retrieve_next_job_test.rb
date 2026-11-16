require 'test_helper'

module Orchestrator
  class RetrieveNextJobTest < Minitest::Test
    def test_full_flow
      job_1 = Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, "123", "", :ruby, "two-fer")
      Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, "123", "", :ruby, "two-fer")

      assert_equal 2, redis.llen(Exercism::ToolingJob.key_for_queued)
      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_locked)

      assert_equal job_1, RetrieveNextJob.()
      assert_equal 1, redis.llen(Exercism::ToolingJob.key_for_queued)
      assert_equal 1, redis.llen(Exercism::ToolingJob.key_for_locked)

      assert_equal job_1.id, redis.lindex(Exercism::ToolingJob.key_for_locked, 0)
      assert Queue.instance.deadline(job_1.id)
    end

    def test_no_jobs
      assert_nil RetrieveNextJob.()
    end

    def test_drops_a_job_if_its_data_has_gone
      redis.rpush(Exercism::ToolingJob.key_for_queued, "missing")
      job = Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, "123", "", :ruby, "two-fer")

      assert_nil RetrieveNextJob.()
      assert_nil Queue.instance.deadline("missing")

      # The missing job doesn't block the queue
      assert_equal job, RetrieveNextJob.()
    end

    # The soak test found this. A job with a saved result mustn't run again,
    # and it mustn't be dropped before the website has the result.
    def test_keeps_a_job_that_already_has_a_result_for_the_website
      job = Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, "123", "", :ruby, "two-fer")
      job.executed!(200, {})
      redis.rpush(Exercism::ToolingJob.key_for_queued, job.id)

      assert_nil RetrieveNextJob.()
      assert Queue.instance.leased?(job.id)
      assert_in_delta Time.now.to_f + Orchestrator.config.retry_seconds, Queue.instance.deadline(job.id), 1
    end

    private
    def redis = Exercism.redis_tooling_client
  end
end
