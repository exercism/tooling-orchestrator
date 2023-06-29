require 'test_helper'

module Orchestrator
  class JobTest < Minitest::Test
    def test_to_json
      job_id = SecureRandom.hex
      language = :ruby
      exercise = :bob
      source = { foo: 'bar' }
      job_type = "test_runner"

      job = Job.new(job_type, job_id, language, exercise, source)

      expected = {
        type: job_type,
        id: job_id,
        language:,
        exercise:,
        source:,
        container_version: nil,
        timeout: nil
      }
      assert_equal expected, job.to_h
    end
  end
end
