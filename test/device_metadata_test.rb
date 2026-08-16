# frozen_string_literal: true

require "test_helper"

class DeviceMetadataTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioRootSwitchable.instance_variable_get(:@configuration)
    RecordingStudioRootSwitchable.reset_configuration!
  end

  def teardown
    RecordingStudioRootSwitchable.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_capture_extracts_browser_platform_and_type_from_desktop_user_agent
    controller = Struct.new(:request).new(
      Struct.new(:user_agent).new(
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
        "(KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36"
      )
    )

    metadata = RecordingStudio::RootSwitchable::DeviceMetadata.capture(controller: controller)

    assert_equal "Chrome", metadata[:device_browser]
    assert_equal "Chrome on macOS", metadata[:device_label]
    assert_equal "macOS", metadata[:device_platform]
    assert_equal "desktop", metadata[:device_type]
    assert_nil metadata[:user_agent]
  end

  def test_capture_includes_raw_user_agent_when_enabled
    RecordingStudioRootSwitchable.configuration.store_raw_user_agent = true
    controller = Struct.new(:request).new(
      Struct.new(:user_agent).new(
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
        "(KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36"
      )
    )

    metadata = RecordingStudio::RootSwitchable::DeviceMetadata.capture(controller: controller)

    assert_includes metadata[:user_agent], "Chrome/135.0.0.0"
  end

  def test_capture_returns_empty_hash_without_user_agent
    controller = Struct.new(:request).new(Struct.new(:user_agent).new(nil))

    assert_equal({}, RecordingStudio::RootSwitchable::DeviceMetadata.capture(controller: controller))
  end
end
