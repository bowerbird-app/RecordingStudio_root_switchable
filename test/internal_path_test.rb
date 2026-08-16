# frozen_string_literal: true

require "test_helper"

class InternalPathTest < Minitest::Test
  def test_accepts_relative_internal_paths
    assert_equal "/projects/current", RecordingStudio::RootSwitchable::InternalPath.sanitize("/projects/current")
  end

  def test_rejects_absolute_urls
    assert_nil RecordingStudio::RootSwitchable::InternalPath.sanitize("https://example.com/phish")
  end

  def test_rejects_protocol_relative_urls
    assert_nil RecordingStudio::RootSwitchable::InternalPath.sanitize("//example.com/phish")
  end

  def test_rejects_backslash_open_redirect_tricks
    assert_nil RecordingStudio::RootSwitchable::InternalPath.sanitize("/\\example.com")
  end

  def test_rejects_encoded_protocol_relative_urls
    assert_nil RecordingStudio::RootSwitchable::InternalPath.sanitize("/%2F%2Fexample.com")
  end
end
