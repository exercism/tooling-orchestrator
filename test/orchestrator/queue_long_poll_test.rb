require 'test_helper'

module Orchestrator
  class QueueLongPollTest < Minitest::Test
    def teardown
      super
      Timecop.return
    end

    def test_claim_with_wait_returns_a_job_that_arrives_mid_wait
      job_id = SecureRandom.uuid
      Thread.new do
        sleep(0.3)
        Exercism::ToolingJob.create!(job_id, :test_runner, SecureRandom.uuid, "", :ruby, "two-fer")
      end

      started = monotonic_now
      id = queue.claim(wait: 5)

      assert_equal job_id, id
      assert_in_delta 0.3, monotonic_now - started, 0.25
      assert queue.deadline(id)
      assert_equal [id], redis.lrange(queue.leased_key, 0, -1)
    end

    def test_claim_with_wait_returns_nil_after_the_wait
      started = monotonic_now
      assert_nil queue.claim(wait: 0.5)
      assert_operator monotonic_now - started, :>=, 0.5
    end

    def test_claim_with_wait_answers_straight_away_when_no_blocking_connection_is_free
      pool = mock
      pool.expects(:with).raises(ConnectionPool::TimeoutError)
      queue.stubs(:blocking_pool).returns(pool)

      assert_nil queue.claim(wait: 5)
    end

    private
    def queue = Queue.instance
    def redis = Exercism.redis_tooling_client
    def monotonic_now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    def create_job
      Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, SecureRandom.uuid, "", :ruby, "two-fer")
    end
  end
end
