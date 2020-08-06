module Orchestrator
  class Configuration
    include Singleton

    def dynamodb_endpoint
      Exercism.config.dynamodb_endpoint
    end

    def jobs_table
      Exercism.config.dynamodb_tooling_jobs_table
    end
  end
end
