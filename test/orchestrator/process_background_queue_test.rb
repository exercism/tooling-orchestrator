require 'test_helper'

module Orchestrator
  class ProcessBackgroundQueueTest < Minitest::Test
    MAX_QUEUE_LENGTH = ProcessBackgroundQueue::MAX_QUEUE_LENGTH

    def test_is_fine_with_nothing_in_background_queue
      cmd = ProcessBackgroundQueue.new
      cmd.expects(:loop).yields
      cmd.()
    end

    def test_moves_up_to_MAX_QUEUE_LENGTH_things_over # rubocop:disable Naming/MethodName
      (MAX_QUEUE_LENGTH + 5).times do
        Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, "123", "", :ruby, "two-fer",
                                     run_in_background: true)
      end

      assert_equal 0, redis.llen(Exercism::ToolingJob.key_for_queued)
      assert_equal MAX_QUEUE_LENGTH + 5, redis.llen(Exercism::ToolingJob.key_for_queued_for_background_processing)

      cmd = ProcessBackgroundQueue.new
      cmd.expects(:loop).yields
      cmd.()

      assert_equal MAX_QUEUE_LENGTH, redis.llen(Exercism::ToolingJob.key_for_queued)
      assert_equal 5, redis.llen(Exercism::ToolingJob.key_for_queued_for_background_processing)
    end

    def test_sets_max_queue_size_as_MAX_QUEUE_LENGTH # rubocop:disable Naming/MethodName
      (MAX_QUEUE_LENGTH + 5).times do
        Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, "123", "", :ruby, "two-fer",
                                     run_in_background: true)
      end
      (MAX_QUEUE_LENGTH - 4).times do
        Exercism::ToolingJob.create!(SecureRandom.uuid, :test_runner, "123", "", :ruby, "two-fer",
                                     run_in_background: false)
      end

      assert_equal MAX_QUEUE_LENGTH - 4, redis.llen(Exercism::ToolingJob.key_for_queued)
      assert_equal MAX_QUEUE_LENGTH + 5, redis.llen(Exercism::ToolingJob.key_for_queued_for_background_processing)

      cmd = ProcessBackgroundQueue.new
      cmd.expects(:loop).yields
      cmd.()

      assert_equal MAX_QUEUE_LENGTH, redis.llen(Exercism::ToolingJob.key_for_queued)
      assert_equal MAX_QUEUE_LENGTH + 1, redis.llen(Exercism::ToolingJob.key_for_queued_for_background_processing)
    end

    def redis
      Exercism.redis_tooling_client
    end
  end
end
