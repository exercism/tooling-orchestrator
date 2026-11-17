require 'test_helper'

module Orchestrator
  class QueueTest < Minitest::Test
    def teardown
      super
      Timecop.return
    end

    def test_keys_share_the_queued_hash_slot
      assert_equal "test:queued", queue.queued_key
      assert_equal "{test:queued}:leased", queue.leased_key
      assert_equal "{test:queued}:deadlines", queue.deadlines_key
      assert_equal "{test:queued}:reclaims", queue.reclaims_key
      assert_equal "{test:queued}:reports", queue.reports_key
      assert_equal "{test:queued}:taken:1", queue.taken_key(1)
    end

    def test_claim_gives_the_job_a_lease
      Timecop.freeze
      id = create_job.id

      assert_equal id, queue.claim
      assert_equal 0, redis.llen(queue.queued_key)
      assert_equal [id], redis.lrange(queue.leased_key, 0, -1)
      assert_in_delta Time.now.to_f + Orchestrator.config.lease_seconds, queue.deadline(id), 0.01
    end

    def test_claim_returns_nil_when_empty
      assert_nil queue.claim
    end

    def test_finish_removes_the_lease
      id = create_job.id
      queue.claim
      queue.finish(id)

      assert_nil queue.deadline(id)
      refute queue.leased?(id)
    end

    def test_expired_ids_lists_jobs_that_have_run_out_of_time
      id = create_job.id
      queue.claim
      assert_empty queue.expired_ids

      expire_leases
      assert_equal [id], queue.expired_ids
    end

    # This is the state if the orchestrator crashes after it moves a job to
    # `leased`, but before it saves the job's deadline
    def test_expired_ids_gives_a_job_with_no_deadline_a_short_one
      id = create_job.id
      redis.lmove(queue.queued_key, queue.leased_key, :left, :right)

      assert_empty queue.expired_ids
      assert queue.deadline(id)

      Timecop.travel(Time.now + Orchestrator.config.deadline_grace_seconds + 1)
      assert_equal [id], queue.expired_ids
    end

    def test_expired_ids_keeps_a_full_deadline
      id = create_job.id
      queue.claim
      deadline = queue.deadline(id)

      queue.expired_ids
      assert_equal deadline, queue.deadline(id)
    end

    # The soak test found this. If a job finishes while expired_ids is
    # reading, it mustn't leave a deadline behind.
    def test_expired_ids_leaves_no_deadline_for_a_job_that_just_finished
      id = create_job.id
      redis.stubs(:lrange).returns([id])

      assert_empty queue.expired_ids
      assert_nil queue.deadline(id)
    end

    def test_only_one_caller_can_take_a_job
      id = create_job.id
      queue.claim

      assert queue.take(id)
      refute queue.take(id)
      assert_in_delta Orchestrator.config.retry_seconds, redis.ttl(queue.taken_key(id)), 1
    end

    def test_requeue_gives_up_on_a_job_after_too_many_attempts
      id = create_job.id

      Orchestrator.config.max_reclaims.times do
        assert_equal id, queue.claim
        assert_equal :requeued, queue.requeue(id)
      end

      assert_equal id, queue.claim
      assert_equal :failed, queue.requeue(id)

      # Until we mark the job as failed, it stays in `leased`
      assert_equal 0, redis.llen(queue.queued_key)
      assert queue.leased?(id)
    end

    def test_finish_forgets_the_counts
      id = create_job.id
      queue.claim
      queue.requeue(id)
      queue.claim
      queue.count_report_attempt(id)
      queue.finish(id)

      assert_nil redis.hget(queue.reclaims_key, id)
      assert_nil redis.hget(queue.reports_key, id)
    end

    def test_requeue
      id = create_job.id
      queue.claim

      assert_equal :requeued, queue.requeue(id)
      assert_equal [id], redis.lrange(queue.queued_key, 0, -1)
      assert_nil queue.deadline(id)
      refute queue.leased?(id)
      assert_equal "1", redis.hget(queue.reclaims_key, id)
    end

    private
    def queue = Queue.instance
    def redis = Exercism.redis_tooling_client

    def create_job
      Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, SecureRandom.uuid, "", :ruby, "two-fer")
    end

    def expire_leases
      Timecop.travel(Time.now + Orchestrator.config.lease_seconds + 1)
    end
  end
end
