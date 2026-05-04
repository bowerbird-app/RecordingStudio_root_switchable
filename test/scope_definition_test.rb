# frozen_string_literal: true

require "test_helper"

class ScopeDefinitionTest < Minitest::Test
  def test_defaults_fail_closed_without_explicit_access_callbacks
    scope = RecordingStudio::RootSwitchable::ScopeDefinition.new(:roots)

    assert_empty scope.available_roots_for(actor: Object.new)
    refute scope.allowed?(actor: Object.new, recording: Object.new)
  end
end
