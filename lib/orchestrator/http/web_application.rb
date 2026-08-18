$stdout.sync = true
$stderr.sync = true

require 'sinatra/base'
require 'sinatra/json'

module Orchestrator
  module Http
    class WebApplication < Sinatra::Base
      set :host_authorization, { permitted_hosts: [] }

      # Ping check for ELBs
      get '/' do
        json(ruok: :yes)
        status 200
      end

      get '/jobs/next' do
        job = application.lock_next_job!
        if job
          log("Found job #{job}")
          log(job.to_h)
          json(job.to_h)
        else
          # Deliberately unlogged. ~99% of polls land here — roughly 3,400 a
          # minute across the fleet — and "no work right now" is not an event
          # worth recording. It was the single largest source of log volume.
          status 404
        end
      rescue Aws::DynamoDB::Errors::ResourceNotFoundException
        log("Cannot connect to AWS")
        status 500
      end

      patch '/jobs/:id' do
        log("Got back job ##{params[:id]}")

        keys = %w[status output]
        application.process_job!(params[:id], params.slice(*keys))
        json({})
      end

      patch '/jobs/:id/requeue' do
        log("Requeuing job ##{params[:id]}")

        application.requeue_job!(params[:id])
        json({})
      end

      private
      def application = Orchestrator.application
      def log(*args)= application.log(*args)
    end
  end
end
