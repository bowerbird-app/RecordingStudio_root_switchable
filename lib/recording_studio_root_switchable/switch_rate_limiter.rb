# frozen_string_literal: true

require "recording_studio_cache"

module RecordingStudioRootSwitchable
  # Thin adapter over {RecordingStudioCache::RateLimiter} that preserves the
  # historical SwitchRateLimiter key shape, TTL window, and fail-open rescue.
  #
  # Main always incremented through +Rails.cache+ (there is no gem-level
  # +cache_store+ / +config.cache+ for switch rate limits). The adapter passes
  # that store as +store:+ so the shared limiter cannot fall through to
  # +RecordingStudioCache.store+.
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

      store = cache_store
      return true unless store

      allowed_with_store?(store:, actor:, device_key:, limit:, period:)
    rescue StandardError
      true
    end

    def allowed_with_store?(store:, actor:, device_key:, limit:, period:)
      # Shared RateLimiter treats limit <= 0 as disabled. Main still incremented
      # first, then compared with count.to_i <= limit.to_i (raise => allow).
      return non_positive_limit_allowed?(store:, actor:, device_key:, limit:, period:) if limit.to_i <= 0

      # Positive limits: String period raised from expires_in: on main (fail open).
      # Shared RateLimiter would coerce via to_i — keep fail-open here.
      return true unless period.is_a?(Numeric)

      shared_limiter_allows?(actor:, device_key:, limit:, period:, store:)
    end
    private_class_method :allowed_with_store?

    def shared_limiter_allows?(actor:, device_key:, limit:, period:, store:)
      RecordingStudioCache::RateLimiter.allow?(
        **limiter_options(actor: actor, device_key: device_key, limit: limit, period: period, store: store)
      )
    end
    private_class_method :shared_limiter_allows?

    # Mirrors main's increment-then-compare for limit <= 0 without using the
    # shared limiter (which would treat <= 0 as disabled / always allow).
    def non_positive_limit_allowed?(store:, actor:, device_key:, limit:, period:)
      count = store.increment(storage_key_for(actor, device_key), 1, expires_in: period)
      count.to_i <= limit.to_i
    rescue StandardError
      true
    end
    private_class_method :non_positive_limit_allowed?

    def rate_limit_settings
      config = RecordingStudioRootSwitchable.configuration.switch_rate_limit || {}
      [config[:limit] || config["limit"], config[:period] || config["period"]]
    end
    private_class_method :rate_limit_settings

    # Same store main used: +Rails.cache+. Not configurable on this gem.
    def cache_store
      return unless defined?(Rails) && Rails.respond_to?(:cache)

      Rails.cache
    end
    private_class_method :cache_store

    def storage_key_for(actor, device_key)
      "#{CACHE_KEY_PREFIX}:#{actor_cache_identity(actor)}:#{device_key}"
    end
    private_class_method :storage_key_for

    def limiter_options(actor:, device_key:, limit:, period:, store:)
      LIMITER_DEFAULTS.merge(
        key: "#{actor_cache_identity(actor)}:#{device_key}",
        limit: limit,
        period: period,
        store: store
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
