module Orchestrator
  class Job
    attr_reader :type, :id, :language, :exercise
    def initialize(type, id, language, exercise)
      @type = type
      @id = id
      @language = language
      @exercise = exercise
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
        container_version: nil,
        timeout: nil
      }
    end
  end
end
