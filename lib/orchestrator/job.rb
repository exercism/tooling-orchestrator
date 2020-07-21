module Orchestrator
  class Job
    attr_reader :id

    def initialize(type, iteration_uuid, language, exercise, s3_uri)
      @type = type
      @iteration_uuid = iteration_uuid
      @language = language
      @exercise = exercise
      @s3_uri = s3_uri
      @id = SecureRandom.uuid
    end

    def to_s
      "#{id} | #{type}: #{iteration_uuid}"
    end

    def to_json
      {
        id: id,
        job_type: type,
        language: language,
        exercise: exercise,
        s3_uri: s3_uri,
        container_version: nil,
        execution_timeout: nil
      }
    end

    private
    attr_reader :type, :iteration_uuid, :language, :exercise, :s3_uri
  end
end

