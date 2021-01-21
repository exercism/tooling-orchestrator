module Orchestrator
  class Job
    attr_reader :type, :id, :language, :exercise, :source

    def initialize(type, id, language, exercise, source)
      @type = type
      @id = id
      @language = language
      @exercise = exercise
      @source = source
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
        source: source,
        container_version: nil,
        timeout: nil
      }
    end
  end
end
