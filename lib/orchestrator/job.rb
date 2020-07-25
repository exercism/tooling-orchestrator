module Orchestrator
  class Job
    attr_reader :id, :type, :language, :exercise, :s3_uri
    def initialize(type, id, language, exercise, s3_uri)
      @type = type
      @id = id
      @language = language
      @exercise = exercise
      @s3_uri = s3_uri
    end

    def to_s
      "#{id} | #{type}"
    end

    def to_h
      {
        id: id,
        type: type,
        language: language,
        exercise: exercise,
        s3_uri: s3_uri,
        container_version: nil,
        execution_timeout: nil
      }
    end
  end
end

