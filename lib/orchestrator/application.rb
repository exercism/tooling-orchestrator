module Orchestrator
  class Application
    include Singleton

    # Rather than using an mvar for this, we could just
    # use dynamodb's own internal consistency stuff, which
    # would work fine. Howver, that costs twice as much, so
    # we're doing it manually instead :)
    #
    # This does mean that having multiple versions of this
    # orchestrator running simultaneously may lead to jobs
    # being processed twice, which isn't in itself a problem -
    # it just makes things occasionally slower end-to-end.
    def initialize
      @__client__ = Concurrent::MVar.new(
        ExercismConfig::SetupDynamoDBClient.()
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
      @__client__.borrow { |client| yield(client) }
    end
  end
end
