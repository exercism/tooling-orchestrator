require 'test_helper'
require 'rack/test'

module Orchestrator
  class SystemBaseTestCase < Minitest::Test
    include Rack::Test::Methods

    def app
      Http::WebApplication
    end

    def application
      Orchestrator::Application.new
    end
  end
end
