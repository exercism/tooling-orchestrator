module Orchestrator
  class Configuration
    include Singleton

    def dynamodb_endpoint
      case env
      when :production
        Exercism.config.dynamodb_endpoint
      else
        "http://localhost:3039"
      end
    end

    def jobs_table
      case env
      when :test
        "boffin_jobs-test"
      else
        "boffin_jobs"
      end
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

