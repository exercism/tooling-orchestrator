require 'test_helper'

module Orchestrator
  class RequeueJobTest < Minitest::Test
    def test_full_flow
      job = create_job
      other_job = create_job

      # Put the job onto the locked queue
      retrieved_job = Orchestrator::RetrieveNextJob.()

      # Sanity checks
      assert_equal job.id, retrieved_job.id
      assert_equal 1, redis.llen(Exercism::ToolingJob.key_for_locked)
      assert_equal 1, redis.llen(Exercism::ToolingJob.key_for_queued)

      RequeueJob.(job.id)

      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_locked)
      assert_equal [job.id, other_job.id], redis.lrange(Exercism::ToolingJob.key_for_queued, 0, -1)
      assert_nil Queue.instance.deadline(job.id)
    end

    def test_leaves_other_locked_jobs_alone
      job = create_job
      other_job = create_job
      RetrieveNextJob.()
      RetrieveNextJob.()

      RequeueJob.(job.id)

      assert_equal [other_job.id], redis.lrange(Exercism::ToolingJob.key_for_locked, 0, -1)
    end

    def test_requeues_a_job_locked_before_leases_existed
      job = create_job
      redis.lpop(Exercism::ToolingJob.key_for_queued)
      redis.rpush(Exercism::ToolingJob.key_for_locked, job.id)

      RequeueJob.(job.id)

      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_locked)
      assert_equal [job.id], redis.lrange(Exercism::ToolingJob.key_for_queued, 0, -1)
    end

    # The soak test found this. If an invoker hands back a job after another
    # invoker has reported it, the job mustn't go back on the queue.
    def test_leaves_a_job_that_already_has_a_result
      job = create_job
      RetrieveNextJob.()
      Exercism::ToolingJob.find(job.id).executed!(200, {})

      RequeueJob.(job.id)

      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_queued)
      assert Queue.instance.leased?(job.id)
    end

    def test_ignores_an_unknown_job
      RequeueJob.("unknown")

      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_queued)
    end

    def test_gives_up_on_a_job_after_too_many_attempts
      job = create_job

      Orchestrator.config.max_reclaims.times do
        RetrieveNextJob.()
        RequeueJob.(job.id)
      end

      expects_spi_patch(job.id)
      RetrieveNextJob.()
      RequeueJob.(job.id)

      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_queued)
      assert_nil Queue.instance.deadline(job.id)
      assert_equal Queue::RECLAIMS_EXHAUSTED_STATUS, Exercism::ToolingJob.find(job.id).execution_status
    end

    private
    def redis = Exercism.redis_tooling_client

    def create_job
      Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, SecureRandom.uuid, "", :ruby, "two-fer")
    end
  end
end
