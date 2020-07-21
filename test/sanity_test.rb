require 'test_helper'

module Orchestrator
  class SanityTest < Minitest::Test
    def test_sanity
      assert Orchestrator.application
    end
  end
end

