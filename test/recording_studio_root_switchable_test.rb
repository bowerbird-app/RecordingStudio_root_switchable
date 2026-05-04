# frozen_string_literal: true

require "test_helper"

class RecordingStudioRootSwitchableTest < Minitest::Test
  def test_version_exists
    refute_nil RecordingStudioRootSwitchable::VERSION
  end

  def test_engine_exists
    assert_kind_of Class, RecordingStudioRootSwitchable::Engine
  end

  def test_public_current_helpers_are_exposed
    RecordingStudio::RootSwitchable::Current.scope_key = "roots"

    assert_equal "roots", RecordingStudio::RootSwitchable.current_root_scope_key
  ensure
    RecordingStudio::RootSwitchable::Current.reset
  end
end
