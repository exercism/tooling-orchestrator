$stdout.sync = true
$stderr.sync = true

require 'sinatra/base'
require 'sinatra/json'

module Orchestrator
  module Http
    class WebApplication < Sinatra::Base
      get '/status' do
        json({
          queue_length: application.queue_length
        })
      end

      get '/jobs/next' do
        job = application.lock_next_job!
        if job
          log("Found job #{job}")
          json(job.to_json)
        else
          log('No jobs found')
          status 404
          json({})
        end
      end

      post '/jobs' do
        job = Job.new(
          params['job_type'],
          params['iteration_uuid'],
          params['language'],
          params['exercise'],
          params['s3_uri']
        )
        application.enqueue_job!(job)
        log("Enqueued job #{job.to_json}")
        json({})
      end

      private

      def application
        Orchestrator.application
      end

      def log(*args)
        application.log(*args)
      end
    end
  end
end
