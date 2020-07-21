$stdout.sync = true
$stderr.sync = true

require "sinatra/base"
require "sinatra/json"

module Orchestrator
  module Http
    class WebApplication < Sinatra::Base
      get '/status' do
        json({
          queue_length: Orchestrator.application.queue_length
        })
      end

      get "/iterations/next" do
        job = Orchestrator.application.lock_next_job!
        if job
          json(job.to_json)
        else
          status 404
          json({})
        end
      end
    end
  end
end
