module Orchestrator
  class Application
    include Singleton

    def initialize
      @__queue__ = Concurrent::MVar.new(Array.new)
    end

    def with_queue
      @__queue__.borrow {|queue| yield(queue) }
    end
  end
end
