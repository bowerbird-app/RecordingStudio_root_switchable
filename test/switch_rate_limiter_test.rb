# frozen_string_literal: true

require "test_helper"
require "active_support/cache"
require "active_support/core_ext/integer/time"
require "active_support/core_ext/object/blank"

class SwitchRateLimiterTest < Minitest::Test
  ActorWithCacheKey = Struct.new(:cache_key_with_version)
  ActorWithGid = Struct.new(:to_gid_param)
  ActorWithId = Struct.new(:id)

  class << self
    attr_accessor :rails_cache_stub
  end

  def setup
    @original_configuration = RecordingStudioRootSwitchable.instance_variable_get(:@configuration)
    RecordingStudioRootSwitchable.reset_configuration!
    @memory = ActiveSupport::Cache::MemoryStore.new
    install_rails_cache_stub!
    self.class.rails_cache_stub = @memory
    RecordingStudioRootSwitchable.configuration.switch_rate_limit = { limit: 3, period: 1.minute }
  end

  def teardown
    self.class.rails_cache_stub = nil
    RecordingStudioRootSwitchable.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_allows_requests_under_the_configured_limit
    actor = ActorWithId.new(42)

    3.times do
      assert RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(actor: actor, device_key: "device-a")
    end
  end

  def test_blocks_once_the_configured_limit_is_exceeded
    actor = ActorWithId.new(42)

    3.times do
      assert RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(actor: actor, device_key: "device-a")
    end

    refute RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(actor: actor, device_key: "device-a")
  end

  def test_uses_legacy_ttl_cache_key_shape
    actor = ActorWithId.new(99)

    RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(actor: actor, device_key: "phone")

    expected_key = "recording_studio_root_switchable:switch_rate:99:phone"
    assert_equal 1, @memory.read(expected_key)
  end

  def test_prefers_cache_key_with_version_for_actor_identity
    actor = ActorWithCacheKey.new("users/7-20260101")

    RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(actor: actor, device_key: "desk")

    assert_equal 1, @memory.read(
      "recording_studio_root_switchable:switch_rate:users/7-20260101:desk"
    )
  end

  def test_falls_back_to_gid_then_id_then_anonymous
    gid_actor = ActorWithGid.new("gid-param-1")
    RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(actor: gid_actor, device_key: "a")
    assert_equal 1, @memory.read(
      "recording_studio_root_switchable:switch_rate:gid-param-1:a"
    )

    RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(actor: Object.new, device_key: "b")
    assert_equal 1, @memory.read(
      "recording_studio_root_switchable:switch_rate:anonymous:b"
    )
  end

  def test_isolates_buckets_per_actor_and_device
    actor = ActorWithId.new(1)

    3.times do
      assert RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(actor: actor, device_key: "one")
    end
    refute RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(actor: actor, device_key: "one")

    assert RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(actor: actor, device_key: "two")
    assert RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(
      actor: ActorWithId.new(2),
      device_key: "one"
    )
  end

  def test_blank_limit_or_period_disables_limiting
    RecordingStudioRootSwitchable.configuration.switch_rate_limit = { limit: nil, period: 1.minute }
    assert RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(
      actor: ActorWithId.new(1),
      device_key: "device"
    )

    RecordingStudioRootSwitchable.configuration.switch_rate_limit = { limit: 1, period: nil }
    assert RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(
      actor: ActorWithId.new(1),
      device_key: "device"
    )
    assert_nil @memory.read("recording_studio_root_switchable:switch_rate:1:device")
  end

  def test_non_positive_limit_blocks_when_increment_returns_a_count
    actor = ActorWithId.new(1)

    # MemoryStore#increment returns an Integer; main then blocked via count <= 0.
    RecordingStudioRootSwitchable.configuration.switch_rate_limit = { limit: 0, period: 1.minute }
    refute RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(actor: actor, device_key: "device")
    refute RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(actor: actor, device_key: "device")

    RecordingStudioRootSwitchable.configuration.switch_rate_limit = { limit: -1, period: 1.minute }
    refute RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(actor: actor, device_key: "device")
  end

  def test_limit_zero_allows_when_store_increment_raises
    boom_store = Object.new
    boom_store.define_singleton_method(:increment) do |*|
      raise StandardError, "cache down"
    end
    self.class.rails_cache_stub = boom_store
    RecordingStudioRootSwitchable.configuration.switch_rate_limit = { limit: 0, period: 1.minute }

    assert RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(
      actor: ActorWithId.new(1),
      device_key: "device"
    )
  end

  def test_limit_zero_allows_on_null_store
    # NullStore#increment returns nil; nil.to_i <= 0 => allow (same as main).
    self.class.rails_cache_stub = ActiveSupport::Cache::NullStore.new
    RecordingStudioRootSwitchable.configuration.switch_rate_limit = { limit: 0, period: 1.minute }

    assert RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(
      actor: ActorWithId.new(1),
      device_key: "device"
    )
  end

  def test_limit_negative_one_blocks_on_null_store
    # nil.to_i <= -1 => 0 <= -1 => block (main's comparison, not "nil always allows").
    self.class.rails_cache_stub = ActiveSupport::Cache::NullStore.new
    RecordingStudioRootSwitchable.configuration.switch_rate_limit = { limit: -1, period: 1.minute }

    refute RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(
      actor: ActorWithId.new(1),
      device_key: "device"
    )
  end

  def test_limit_zero_with_string_period_fails_open
    # Main called increment(expires_in: "60"), which raised and rescued to allow.
    RecordingStudioRootSwitchable.configuration.switch_rate_limit = { limit: 0, period: "60" }

    assert RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(
      actor: ActorWithId.new(1),
      device_key: "device"
    )
    assert_nil @memory.read("recording_studio_root_switchable:switch_rate:1:device")
  end

  def test_string_period_fails_open_like_main
    # Main passed period to expires_in:; a String raised and the rescue allowed.
    # Shared RateLimiter would coerce "60".to_i and start limiting — keep fail-open.
    RecordingStudioRootSwitchable.configuration.switch_rate_limit = { limit: 1, period: "60" }

    3.times do
      assert RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(
        actor: ActorWithId.new(1),
        device_key: "device"
      )
    end
    assert_nil @memory.read("recording_studio_root_switchable:switch_rate:1:device")
  end

  def test_string_config_keys_are_accepted
    RecordingStudioRootSwitchable.configuration.switch_rate_limit = {
      "limit" => 1,
      "period" => 60
    }

    assert RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(
      actor: ActorWithId.new(5),
      device_key: "web"
    )
    refute RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(
      actor: ActorWithId.new(5),
      device_key: "web"
    )
  end

  def test_cache_errors_fail_open
    boom_store = Object.new
    boom_store.define_singleton_method(:increment) do |*|
      raise StandardError, "cache down"
    end
    self.class.rails_cache_stub = boom_store

    assert RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(
      actor: ActorWithId.new(1),
      device_key: "device"
    )
  end

  def test_missing_rails_cache_allows_even_when_limit_is_zero
    self.class.rails_cache_stub = nil
    RecordingStudioRootSwitchable.configuration.switch_rate_limit = { limit: 0, period: 1.minute }

    assert RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(
      actor: ActorWithId.new(1),
      device_key: "device"
    )
  end

  def test_passes_rails_cache_store_object_to_shared_limiter
    # Main always used Rails.cache; this gem has no switch_rate cache_store config.
    captured = nil
    allow_stub = lambda do |**options|
      captured = options
      true
    end

    RecordingStudioCache::RateLimiter.stub(:allow?, allow_stub) do
      assert RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(
        actor: ActorWithId.new(1),
        device_key: "device"
      )
    end

    refute_nil captured
    assert_same @memory, captured[:store]
    assert_same Rails.cache, captured[:store]
    assert_equal :rails_cache, captured[:backend]
    assert_equal :ttl, captured[:strategy]
  end

  private

  def install_rails_cache_stub!
    return if self.class.instance_variable_get(:@rails_cache_stub_installed)

    Rails.define_singleton_method(:cache) { SwitchRateLimiterTest.rails_cache_stub }
    self.class.instance_variable_set(:@rails_cache_stub_installed, true)
  end
end
