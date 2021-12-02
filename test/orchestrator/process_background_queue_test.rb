require 'test_helper'

module Orchestrator
  class ProcessBackgroundQueueTest < Minitest::Test
    def test_is_fine_with_nothing_in_background_queue
      cmd = ProcessBackgroundQueue.new
      cmd.expects(:loop).yields
      cmd.()
    end

    def test_moves_up_to_10_things_over
      15.times do
        Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, :ruby, "two-fer", run_in_background: true)
      end

      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_queued)
      assert_equal 15, redis.llen(Exercism::ToolingJob.key_for_queued_for_background_processing)

      cmd = ProcessBackgroundQueue.new
      cmd.expects(:loop).yields
      cmd.()

      assert_equal 10, redis.llen(Exercism::ToolingJob.key_for_queued)
      assert_equal 5, redis.llen(Exercism::ToolingJob.key_for_queued_for_background_processing)
    end

    def test_sets_max_queue_size_as_10
      15.times do
        Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, :ruby, "two-fer", run_in_background: true)
      end
      6.times do
        Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, :ruby, "two-fer", run_in_background: false)
      end

      assert_equal 6, redis.llen(Exercism::ToolingJob.key_for_queued)
      assert_equal 15, redis.llen(Exercism::ToolingJob.key_for_queued_for_background_processing)

      cmd = ProcessBackgroundQueue.new
      cmd.expects(:loop).yields
      cmd.()

      assert_equal 10, redis.llen(Exercism::ToolingJob.key_for_queued)
      assert_equal 11, redis.llen(Exercism::ToolingJob.key_for_queued_for_background_processing)
    end

    def redis
      Exercism.redis_tooling_client
    end
  end
end
