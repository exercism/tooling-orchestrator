require 'test_helper'

module Orchestrator
  class QueuePromotionTest < Minitest::Test
    def teardown
      super
      Timecop.return
    end

    def test_moving_keys_share_the_background_hash_slot
      assert_equal "{test:queued_for_background_processing}:moving", queue.moving_key
      assert_equal "{test:queued_for_background_processing}:moving_since", queue.moving_since_key
    end

    def test_promote_from_background
      id = create_job(run_in_background: true).id

      assert_equal id, queue.promote_from_background
      assert_equal [id], redis.lrange(queue.queued_key, 0, -1)
      assert_equal 0, redis.llen(queue.background_key)
      assert_equal 0, redis.llen(queue.moving_key)
      assert_nil redis.hget(queue.moving_since_key, id)
    end

    def test_promote_from_an_empty_background_queue
      assert_nil queue.promote_from_background
      assert_equal 0, redis.llen(queue.queued_key)
    end

    def test_a_promotion_interrupted_by_a_crash_is_recovered
      id = create_job(run_in_background: true).id

      # If a process dies after it moves the job to `moving`, but before it
      # adds the job to the main queue, the job ends up in this state
      queue.stubs(:complete_promotion).raises(RuntimeError)
      assert_raises(RuntimeError) { queue.promote_from_background }
      queue.unstub(:complete_promotion)
      assert_equal 0, redis.llen(queue.background_key)
      assert_equal 0, redis.llen(queue.queued_key)

      # Because the move may still be in progress, it is too soon to recover it
      queue.recover_promotions
      assert_equal 0, redis.llen(queue.queued_key)

      Timecop.travel(Time.now + Configuration::PROMOTION_TIMEOUT_SECONDS + 1)
      queue.recover_promotions
      assert_equal [id], redis.lrange(queue.queued_key, 0, -1)
      assert_equal 0, redis.llen(queue.moving_key)
    end

    # If a process dies before it notes the time of the move, the job is in
    # `moving` with no time
    def test_a_move_with_no_time_is_recovered_later
      id = create_job(run_in_background: true).id
      redis.lmove(queue.background_key, queue.moving_key, :left, :right)

      queue.recover_promotions
      assert_equal 0, redis.llen(queue.queued_key)
      assert redis.hget(queue.moving_since_key, id)

      Timecop.travel(Time.now + Configuration::PROMOTION_TIMEOUT_SECONDS + 1)
      queue.recover_promotions
      assert_equal [id], redis.lrange(queue.queued_key, 0, -1)
    end

    # If a move finishes while recover_promotions is reading, it mustn't
    # leave a time behind.
    def test_leaves_no_time_for_a_move_that_just_finished
      id = create_job(run_in_background: true).id
      redis.stubs(:lrange).returns([id])

      queue.recover_promotions
      assert_nil redis.hget(queue.moving_since_key, id)
    end

    def test_only_one_task_recovers_each_move
      id = create_job(run_in_background: true).id
      redis.lmove(queue.background_key, queue.moving_key, :left, :right)
      redis.hset(queue.moving_since_key, id, Time.now.to_f - Configuration::PROMOTION_TIMEOUT_SECONDS - 1)
      redis.set(queue.recovering_key(id), 1)

      queue.recover_promotions
      assert_equal 0, redis.llen(queue.queued_key)
    end

    private
    def queue = Queue.instance
    def redis = Exercism.redis_tooling_client

    def create_job(run_in_background: false)
      Exercism::ToolingJob.create!(
        SecureRandom.uuid, :test_runner, SecureRandom.uuid, "", :ruby, "two-fer", run_in_background:
      )
    end
  end
end
