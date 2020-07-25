ENV["APP_ENV"] ||= "development"

require 'concurrent-ruby'
require 'json'
require 'mandate'
require 'rest-client'
require 'singleton'
require 'aws-sdk-dynamodb'
require 'exercism_config'

require "zeitwerk"
loader = Zeitwerk::Loader.for_gem
loader.setup

module Orchestrator
  def self.config
    Configuration.instance
  end

  def self.dynamodb_client

  end
end

# Get a new application on this main thread
# before sinatra or anything else kicks in
#Orchestrator.application
