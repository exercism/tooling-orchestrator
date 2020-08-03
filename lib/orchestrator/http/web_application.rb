$stdout.sync = true
$stderr.sync = true

require 'sinatra/base'
require 'sinatra/json'

module Orchestrator
  module Http
    class WebApplication < Sinatra::Base
      get '/jobs/next' do
        job = application.lock_next_job!
        if job
          log("Found job #{job}")
          log(job.to_h)
          json(job.to_h)
        else
          log('No jobs found')
          status 404
        end
      rescue Aws::DynamoDB::Errors::ResourceNotFoundException
        log("Cannot connect to AWS")
        log('No jobs found')
        status 500
      end

      patch '/jobs/:id' do
        log("Got back job ##{params[:id]}")

        keys = %w[status result context invocation_data]
        application.process_job!(params[:id], params.slice(*keys))
        json({})
      end

      private
      def application
        @application ||= Orchestrator::Application.new
      end

      def log(*args)
        application.log(*args)
      end
    end
  end
end
