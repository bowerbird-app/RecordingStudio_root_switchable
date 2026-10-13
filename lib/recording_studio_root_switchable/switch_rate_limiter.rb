# frozen_string_literal: true

require "recording_studio_cache"

module RecordingStudioRootSwitchable
  # Thin adapter over {RecordingStudioCache::RateLimiter} that preserves the
  # historical SwitchRateLimiter key shape, TTL window, and fail-open rescue.
  module SwitchRateLimiter
    CACHE_KEY_PREFIX = "recording_studio_root_switchable:switch_rate"
    LIMITER_DEFAULTS = {
      backend: :rails_cache,
      strategy: :ttl,
      prefix: CACHE_KEY_PREFIX,
      separator: ":",
      fail_closed: false,
      rescue_errors: [StandardError]
    }.freeze

    module_function

    def allowed?(actor:, device_key:)
      limit, period = rate_limit_settings
      return true if limit.blank? || period.blank?

      RecordingStudioCache::RateLimiter.allow?(**limiter_options(actor, device_key, limit, period))
    rescue StandardError
      true
    end

    def rate_limit_settings
      config = RecordingStudioRootSwitchable.configuration.switch_rate_limit || {}
      [config[:limit] || config["limit"], config[:period] || config["period"]]
    end
    private_class_method :rate_limit_settings

    def limiter_options(actor, device_key, limit, period)
      LIMITER_DEFAULTS.merge(
        key: "#{actor_cache_identity(actor)}:#{device_key}",
        limit: limit,
        period: period,
        store: Rails.cache
      )
    end
    private_class_method :limiter_options

    def actor_cache_identity(actor)
      return actor.cache_key_with_version if actor.respond_to?(:cache_key_with_version)
      return actor.to_gid_param if actor.respond_to?(:to_gid_param)
      return actor.id if actor.respond_to?(:id)

      "anonymous"
    end
    private_class_method :actor_cache_identity
  end
end
