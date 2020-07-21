ENV["APP_ENV"] = "test"

gem "minitest"
require "minitest/autorun"
require "minitest/pride"
require "minitest/mock"
require "mocha/minitest"
require "timecop"

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "orchestrator"

module Minitest
  class Test
  end
end

