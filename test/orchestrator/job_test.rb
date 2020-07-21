require 'test_helper'

module Orchestrator
  class JobTest < Minitest::Test
    def test_to_json
      iteration_uuid = 123
      language = :ruby
      exercise = :bob
      s3_uri = "s3://..."
      job_type = "test_runner"
       
      job = Job.new(job_type, iteration_uuid, language, exercise, s3_uri)

      expected = {
        job_type: job_type,
        iteration_uuid: iteration_uuid,
        language: language,
        exercise: exercise,
        s3_uri: s3_uri,
        container_version: nil,
        execution_timeou: nil
      }
      assert_equal expected, job.to_json
    end
  end
end
