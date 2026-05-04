# frozen_string_literal: true

require "test_helper"

class DeviceKeyTest < Minitest::Test
  FakeEncryptedCookies = Struct.new(:store) do
    def [](key)
      store[key]
    end

    def []=(key, value)
      store[key] = value.fetch(:value)
    end
  end

  FakeCookies = Struct.new(:encrypted)
  PrivateCookieController = Struct.new(:cookie_store) do
    private

    def cookies
      cookie_store
    end
  end

  def setup
    RecordingStudio::RootSwitchable::Current.reset
  end

  def teardown
    RecordingStudio::RootSwitchable::Current.reset
  end

  def test_fetch_reuses_existing_cookie_backed_device_key
    cookies = FakeCookies.new(FakeEncryptedCookies.new({ recording_studio_root_switchable_device_key: "device-1" }))

    device_key = RecordingStudio::RootSwitchable::DeviceKey.fetch(controller: nil, cookies: cookies)

    assert_equal "device-1", device_key
  end

  def test_fetch_generates_and_persists_device_key
    cookies = FakeCookies.new(FakeEncryptedCookies.new({}))

    SecureRandom.stub(:uuid, "generated-device-key") do
      device_key = RecordingStudio::RootSwitchable::DeviceKey.fetch(controller: nil, cookies: cookies)

      assert_equal "generated-device-key", device_key
      assert_equal "generated-device-key", cookies.encrypted[:recording_studio_root_switchable_device_key]
    end
  end

  def test_fetch_supports_controller_with_private_cookies_method
    cookies = FakeCookies.new(FakeEncryptedCookies.new({ recording_studio_root_switchable_device_key: "device-2" }))
    controller = PrivateCookieController.new(cookies)

    device_key = RecordingStudio::RootSwitchable::DeviceKey.fetch(controller: controller)

    assert_equal "device-2", device_key
  end
end
