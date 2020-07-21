module Orchestrator
  class Queue
    class MissingJobError < RuntimeError
    end

    def initialize
      @pending = []
      @locked = {}
    end

    def enqueue!(job)
      @pending.push(job)
    end

    def lock_next_job!
      job = pending.shift
      return nil unless job

      locked[job] = Time.now.to_i
      job
    end

    def take_job!(id)
      take_pending_job!(id) ||
      take_locked_job!(id) ||
      (raise MissingJobError)
    end

    def pending_size
      pending.size
    end

    def locked_size
      locked.size
    end

    def size
      pending_size + locked_size
    end

    private
    attr_reader :pending, :locked

    def take_pending_job!(id)
      idx = pending.find_index{|job|job.id == id}
      pending[idx].tap do |job|
        pending.delete_at(idx)
      end if idx
    end

    def take_locked_job!(id)
      locked.select{|job, _|job.id == id}.keys.first.tap do |job|
        locked.delete(job) if job
      end
    end
  end
end
