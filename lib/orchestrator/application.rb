module Orchestrator
  class Application

    def initialize
      @__client__ = Concurrent::MVar.new(
        Aws::DynamoDB::Client.new(
          endpoint: Orchestrator.config.dynamodb_endpoint,
          profile: "exercism_website",
          region: "eu-west-2"
        )
      )
    end

    def log(msg)
      p "** #{msg}"
    end

    def lock_next_job!
      with_client do |client|
        RetrieveNextJob.(client)
      end
    end

    def process_job!(job_id, data)
      with_client do |client|
        ProcessJob.(job_id, data, client)
      end
    end

    private
    def with_client
      @__client__.borrow {|client| yield(client) }
    end
  end
end
