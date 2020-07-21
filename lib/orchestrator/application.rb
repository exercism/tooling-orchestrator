module Orchestrator
  class Application
    include Singleton

    def initialize
      @__queue__ = Concurrent::MVar.new(Queue.new)

      # TOOD: Add a 1sec timer to unlock any locked jobs
      # that are 15s or older
    end

    def queue_length
      with_queue(&:size)
    end

    def enqueue_job!(iteration)
      with_queue { |q| q.enqueue!(iteration) }
    end

    def lock_next_job!
      with_queue(&:lock_next_job!)
    end

    def take_job!(id)
      with_queue{|q|q.take_job(id)}
    end

    private
    def with_queue
      @__queue__.borrow {|queue| yield(queue) }
    end
  end
end
