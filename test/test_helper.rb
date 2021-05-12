ENV["APP_ENV"] = "test"

# This must happen above the env require below
if ENV["CAPTURE_CODE_COVERAGE"]
  require 'simplecov'
  SimpleCov.start 'rails'
end

gem "minitest"
require "minitest/autorun"
require "minitest/pride"
require "minitest/mock"
require "mocha/minitest"
require "timecop"

# TODO: - Move this to a method within exercism_config gem
# `EXERCISM_ENV=test bundle exec setup_exercism_config`
# `EXERCISM_ENV=test EXERCISM_SKIP_S3=1 bundle exec setup_exercism_local_aws`

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require "orchestrator"

# Silence the noise. Comment this to see exception
# messages and other things that are printed during tests.
module Kernel
  def puts(*args); end
end

module Minitest
  class Test
    def setup
      redis = Exercism.redis_tooling_client
      keys = redis.keys("test:*")
      redis.del(*keys) unless keys.empty?
    end
  end
end
