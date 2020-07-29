module Orchestrator
  class Configuration
    include Singleton

    def dynamodb_endpoint
      Exercism.config.dynamodb_endpoint
    end

    def jobs_table
      Exercism.config.dynamodb_tooling_jobs_table
    end

    def env
      @env ||= case ENV["APP_ENV"].to_s
        when "test"
          :test
        when "production"
          :production
        else
          :development
        end
    end
  end
end

