# frozen_string_literal: true

module RecordingStudioRootSwitchable
  module SwitchRateLimiter
    module_function

    def allowed?(actor:, device_key:)
      limit, period = rate_limit_settings
      return true if limit.blank? || period.blank?
      return true unless cache_available?

      count = Rails.cache.increment(cache_key_for(actor, device_key), 1, expires_in: period, initial: 0)
      count.to_i <= limit.to_i
    rescue StandardError
      true
    end

    def rate_limit_settings
      config = RecordingStudioRootSwitchable.configuration.switch_rate_limit || {}
      [config[:limit] || config["limit"], config[:period] || config["period"]]
    end
    private_class_method :rate_limit_settings

    def cache_available?
      defined?(Rails) && Rails.respond_to?(:cache) && Rails.cache
    end
    private_class_method :cache_available?

    def cache_key_for(actor, device_key)
      [
        "recording_studio_root_switchable",
        "switch_rate",
        actor_cache_identity(actor),
        device_key.to_s
      ].join(":")
    end
    private_class_method :cache_key_for

    def actor_cache_identity(actor)
      return actor.cache_key_with_version if actor.respond_to?(:cache_key_with_version)
      return actor.to_gid_param if actor.respond_to?(:to_gid_param)
      return actor.id if actor.respond_to?(:id)

      "anonymous"
    end
    private_class_method :actor_cache_identity
  end
end
