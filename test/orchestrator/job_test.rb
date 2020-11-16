require 'test_helper'

module Orchestrator
  class JobTest < Minitest::Test
    def test_to_json
      job_id = SecureRandom.hex
      language = :ruby
      exercise = :bob
      job_type = "test_runner"

      job = Job.new(job_type, job_id, language, exercise)

      expected = {
        type: job_type,
        id: job_id,
        language: language,
        exercise: exercise,
        container_version: nil,
        timeout: nil
      }
      assert_equal expected, job.to_h
    end
  end
end
