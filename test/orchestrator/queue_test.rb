require 'test_helper'

module Orchestrator
  class QueueTest < Minitest::Test
    def test_size
      job_1 = Job.new(nil, nil, nil, nil, nil)
      job_2 = Job.new(nil, nil, nil, nil, nil)

      queue = Queue.new
      assert_equal 0, queue.size
      assert_equal 0, queue.pending_size
      assert_equal 0, queue.locked_size

      queue.enqueue!(job_1)
      assert_equal 1, queue.size
      assert_equal 1, queue.pending_size
      assert_equal 0, queue.locked_size

      queue.enqueue!(job_2)
      assert_equal 2, queue.size
      assert_equal 2, queue.pending_size
      assert_equal 0, queue.locked_size

      queue.lock_next_job!
      assert_equal 2, queue.size
      assert_equal 1, queue.pending_size
      assert_equal 1, queue.locked_size

      queue.take_job!(job_1.id)
      assert_equal 1, queue.size
      assert_equal 1, queue.pending_size
      assert_equal 0, queue.locked_size
    end

    def test_enqueue!
      job = Job.new(nil, nil, nil, nil, nil)

      queue = Queue.new
      queue.enqueue!(job)
      assert_equal 1, queue.pending_size
      assert_equal 0, queue.locked_size
    end

    def test_lock_next_job!
      job = Job.new(nil, nil, nil, nil, nil)

      queue = Queue.new
      queue.enqueue!(job)
      queue.lock_next_job!
      assert_equal 0, queue.pending_size
      assert_equal 1, queue.locked_size
    end

    def test_take_job_from_pending!
      job = Job.new(nil, nil, nil, nil, nil)

      queue = Queue.new
      queue.enqueue!(job)
      assert_equal job, queue.take_job!(job.id)
      assert_equal 0, queue.pending_size
      assert_equal 0, queue.locked_size
    end

    def test_take_job_from_locked!
      job = Job.new(nil, nil, nil, nil, nil)

      queue = Queue.new
      queue.enqueue!(job)
      queue.lock_next_job!
      assert_equal job, queue.take_job!(job.id)
      assert_equal 0, queue.pending_size
      assert_equal 0, queue.locked_size
    end

    def test_take_job_fails_if_missing
      job = Job.new(nil, nil, nil, nil, nil)

      queue = Queue.new
      queue.enqueue!(job)
      queue.lock_next_job!
      assert_raises Queue::MissingJobError do
        queue.take_job!("foobar")
      end
    end
  end
end
