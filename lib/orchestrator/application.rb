module Orchestrator
  class Application
    include Singleton

    def log(msg)
      puts "** #{msg}"
    end

    def lock_next_job!
      RetrieveNextJob.()
    end

    def process_job!(job_id, data)
      ProcessJob.(job_id, data)
    end
  end
end
