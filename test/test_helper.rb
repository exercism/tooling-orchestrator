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
      # The keys added by Queue have names that start with "{test:queued}".
      redis = Exercism.redis_tooling_client
      keys = redis.keys("test:*") + redis.keys("{test:*")
      redis.del(*keys) unless keys.empty?
    end

    # This sets up a check that we tell the website about a job's
    # result, with the right timeouts.
    def expects_spi_patch(job_id)
      url = "#{Exercism.config.spi_url}/spi/tooling_jobs/#{job_id}"
      RestClient::Request.expects(:execute).with do |args|
        args[:method] == :patch && args[:url] == url &&
          args[:open_timeout] == Orchestrator::InformSPI::OPEN_TIMEOUT &&
          args[:read_timeout] == Orchestrator::InformSPI::READ_TIMEOUT
      end
    end
  end
end
