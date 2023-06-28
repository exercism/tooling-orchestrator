ENV["APP_ENV"] ||= "development"

require 'concurrent-ruby'
require 'json'
require 'mandate'
require 'rest-client'
require 'singleton'
require 'exercism-config'
require 'redis'

require "zeitwerk"
loader = Zeitwerk::Loader.for_gem
loader.setup

module Orchestrator
  def self.application
    Application.instance
  end

  def self.config
    Configuration.instance
  end

  def self.process_background_queue
    ProcessBackgroundQueue.()
  end
end
