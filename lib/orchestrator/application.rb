module Orchestrator
  class Application
    include Singleton

    def log(msg)
      puts "** #{msg}"
    end

    def lock_next_job!(wait: 0)
      RetrieveNextJob.(wait:)
    end

    def process_job!(job_id, data)
      ProcessJob.(job_id, data)
    end

    def requeue_job!(job_id)
      RequeueJob.(job_id)
    end
  end
end
