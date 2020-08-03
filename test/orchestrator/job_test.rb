require 'test_helper'

module Orchestrator
  class JobTest < Minitest::Test
    def test_to_json
      job_id = SecureRandom.hex
      language = :ruby
      exercise = :bob
      s3_uri = "s3://..."
      job_type = "test_runner"

      job = Job.new(job_type, job_id, language, exercise, s3_uri)

      expected = {
        type: job_type,
        id: job_id,
        language: language,
        exercise: exercise,
        s3_uri: s3_uri,
        container_version: nil,
        execution_timeout: nil
      }
      assert_equal expected, job.to_h
    end
  end
end
