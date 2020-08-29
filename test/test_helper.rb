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
`EXERCISM_ENV=test bundle exec setup_exercism_config`
`EXERCISM_ENV=test EXERCISM_SKIP_S3=1 bundle exec setup_exercism_local_aws`

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require "orchestrator"

module Minitest
  class Test
    def config
      Orchestrator::Configuration.instance
    end

    def fetch_job_attrs(job_id)
      client = ExercismConfig::SetupDynamoDBClient.()
      client.get_item(
        table_name: Exercism.config.dynamodb_tooling_jobs_table,
        key: { id: job_id }
      ).item
    end

    def download_s3_file(bucket, key)
      client = ExercismConfig::SetupS3Client.()
      client.get_object(bucket: bucket,
                        key: key).body.read
    end
  end
end
