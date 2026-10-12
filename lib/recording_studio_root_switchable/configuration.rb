# frozen_string_literal: true

require "active_support/core_ext/integer/time"
require "i18n"

module RecordingStudioRootSwitchable
  class ConfigurationError < StandardError
    attr_reader :source, :config_key, :detail

    def initialize(source:, config_key:, detail:)
      @source = source
      @config_key = config_key
      @detail = detail

      super("Invalid configuration for #{config_key} from #{source}: #{detail}")
    end
  end

  class Configuration
    SUPPORTED_MERGE_KEYS = %i[
      after_switch_redirect
      allow_anonymous_selections
      device_key_cookie_name
      device_key_cookie_options
      last_used_at_touch_interval
      layout
      page_copy
      store_raw_user_agent
      switch_rate_limit
    ].freeze

    ALLOWED_SAME_SITE = %i[lax strict none].freeze

    # English defaults for the public API and I18n `default:` fallbacks.
    # Rendered copy is resolved per request via {#page_copy_for}; do not treat
    # this constant as the live translation table.
    DEFAULT_PAGE_COPY = {
      title: "Switch",
      subtitle: "",
      scope_heading: "Scopes",
      roots_heading: "Available",
      current_selection_label: "Current selection",
      device_label: "Device key",
      persistence_hint: "",
      selected_badge: "Current",
      switch_action_label: "Switch",
      empty_state_title: "Nothing to switch",
      empty_state_body: "There are no options available right now."
    }.freeze

    PAGE_COPY_I18N_PREFIX = "recording_studio.root_switchable.page_copy"
    PAGE_COPY_STRING_KEY_PREFIX = "i18n:"

    # Keys the mounted page omits when blank (PageTitle subtitle / optional hint).
    # Nil is allowed only for these; required keys still reject nil at configure time.
    OPTIONAL_PAGE_COPY_KEYS = %i[subtitle persistence_hint].freeze

    DEFAULT_SWITCH_RATE_LIMIT = { limit: 30, period: 1.minute }.freeze

    attr_accessor :current_actor_resolver,
                  :default_scope_key_resolver,
                  :device_key_cookie_name,
                  :device_key_cookie_options,
                  :layout,
                  :mounted_page_authorizer,
                  :after_switch_redirect,
                  :allow_anonymous_selections,
                  :store_raw_user_agent,
                  :last_used_at_touch_interval,
                  :switch_rate_limit
    attr_reader :scopes

    def initialize
      @device_key_cookie_name = :recording_studio_root_switchable_device_key
      @device_key_cookie_options = {
        expires: 1.year,
        httponly: true,
        same_site: :lax,
        secure: default_secure_cookie?
      }
      @page_copy_overrides = {}
      @scopes = {}
      @current_actor_resolver = default_current_actor_resolver
      @default_scope_key_resolver = ->(scopes:, **) { scopes.first&.key }
      @layout = nil
      @mounted_page_authorizer = ->(actor:, **) { actor.present? }
      @after_switch_redirect = nil
      @allow_anonymous_selections = false
      @store_raw_user_agent = false
      @last_used_at_touch_interval = 5.minutes
      @switch_rate_limit = DEFAULT_SWITCH_RATE_LIMIT.dup
    end

    # Configured page_copy entries merged over {DEFAULT_PAGE_COPY}. Values may be
    # unresolved (Symbol / i18n:-String / Hash / callable). Prefer {#page_copy_for}
    # at render time for locale-aware strings.
    def page_copy
      DEFAULT_PAGE_COPY.merge(@page_copy_overrides)
    end

    def resolved_device_key_cookie_options
      options = device_key_cookie_options.dup
      options[:secure] = true if options[:same_site].to_s == "none"
      options[:secure] = true if default_secure_cookie? && !options.key?(:secure)
      options[:httponly] = true
      options
    end

    def scope(key, **options)
      definition = scopes[key.to_s] ||= RecordingStudio::RootSwitchable::ScopeDefinition.new(key)
      definition.assign!(options)
      yield(definition) if block_given?
      validate_page_copy!(normalize_hash(definition.page_copy), source: "scope #{definition.key}")
      definition
    end

    def current_actor_for(controller:)
      current_actor_resolver.call(controller: controller)
    end

    def supported_scopes(controller:, actor:, device_key:)
      scopes.values.select do |scope|
        scope.supported?(controller: controller, actor: actor, device_key: device_key)
      end
    end

    def resolve_scope(key:, controller:, actor:, device_key:)
      supported = supported_scopes(controller: controller, actor: actor, device_key: device_key)
      return if supported.empty?

      requested_key = key.presence&.to_s
      return supported.find { |scope| scope.key == requested_key } if requested_key.present?

      default_scope_key = default_scope_key_resolver.call(
        controller: controller,
        actor: actor,
        device_key: device_key,
        scopes: supported
      ).presence&.to_s

      supported.find { |scope| scope.key == default_scope_key } || supported.first
    end

    def authorize_mounted_page?(controller:, actor:, scope:, current_root_recording:)
      !!mounted_page_authorizer.call(
        controller: controller,
        actor: actor,
        scope: scope,
        root_recording: current_root_recording
      )
    rescue StandardError => e
      log_configuration_rescue("mounted_page_authorizer", e)
      false
    end

    def after_switch_redirect_for(**context)
      redirect = after_switch_redirect
      return if redirect.nil?

      return redirect.call(**context) if redirect.respond_to?(:call)

      redirect
    end

    def layout_for(**context)
      configured_layout = layout
      return if configured_layout.nil?

      return configured_layout.call(**context) if configured_layout.respond_to?(:call)

      configured_layout
    end

    def page_copy=(value)
      apply_page_copy(value, source: "runtime configuration")
    end

    # Resolve mounted-page copy for the current request / I18n.locale.
    #
    # Precedence per key: config.page_copy (and scope overrides) > gem translation
    # under +recording_studio.root_switchable.page_copy.*+ > English default from
    # {DEFAULT_PAGE_COPY}.
    #
    # Configured values may be:
    # - +nil+ — only for {OPTIONAL_PAGE_COPY_KEYS}; omitted / blank at render
    # - String — fixed in every locale (backward compatible)
    # - Symbol — I18n key looked up at render time
    # - String starting with +"i18n:"+ — I18n key (prefix stripped); a bare
    #   +"i18n:"+ (empty key) falls back to the gem page_copy key; any other
    #   String is a literal so existing plain-String configs keep rendering
    #   verbatim
    # - callable — invoked per request; keyword args (+key:+ / +locale:+) are
    #   passed only when the callable declares them; otherwise positional args
    #   are passed when arity allows, else called with no arguments
    # - Hash keyed by locale — current locale, then I18n.default_locale, then the
    #   gem key
    def page_copy_for(scope: nil)
      configured = @page_copy_overrides.dup
      configured.merge!(normalize_hash(scope.page_copy)) if scope

      DEFAULT_PAGE_COPY.keys.each_with_object({}) do |key, memo|
        memo[key] = if configured.key?(key)
                      value = configured[key]
                      value.nil? ? nil : resolve_page_copy_value(value, key: key)
                    else
                      translate_page_copy_key(key)
                    end
      end
    end

    def merge!(hash = nil, source: "runtime configuration", **kwargs)
      hash = kwargs if hash.nil?
      normalized_hash = normalize_config_payload(hash, source: source)

      normalized_hash.each do |key, value|
        case key
        when :device_key_cookie_name
          validate_device_key_cookie_name!(value, source: source)
          self.device_key_cookie_name = value
        when :device_key_cookie_options
          cookie_options = normalize_hash_value!(
            key: key,
            value: value,
            source: source
          )
          validate_device_key_cookie_options!(cookie_options, source: source)
          self.device_key_cookie_options = device_key_cookie_options.merge(cookie_options)
        when :layout
          validate_layout!(value, source: source)
          self.layout = value
        when :page_copy
          apply_page_copy(value, source: source)
        when :after_switch_redirect
          validate_after_switch_redirect!(value, source: source)
          self.after_switch_redirect = value
        when :allow_anonymous_selections
          self.allow_anonymous_selections = cast_boolean!(
            key: :allow_anonymous_selections,
            value: value,
            source: source
          )
        when :store_raw_user_agent
          self.store_raw_user_agent = cast_boolean!(
            key: :store_raw_user_agent,
            value: value,
            source: source
          )
        when :last_used_at_touch_interval
          self.last_used_at_touch_interval = value
        when :switch_rate_limit
          rate_limit = normalize_hash_value!(key: key, value: value, source: source)
          self.switch_rate_limit = DEFAULT_SWITCH_RATE_LIMIT.merge(rate_limit)
        end
      end

      self
    end

    private

    def default_secure_cookie?
      defined?(Rails) && Rails.respond_to?(:env) && Rails.env.production?
    end

    def default_current_actor_resolver
      lambda do |controller:|
        if defined?(::Current) && ::Current.respond_to?(:actor) && ::Current.actor.present?
          ::Current.actor
        elsif controller.respond_to?(:current_user, true)
          controller.send(:current_user)
        end
      end
    end

    def normalize_hash(value)
      return {} unless value.respond_to?(:each_pair)

      value.each_pair.with_object({}) do |(key, nested_value), memo|
        memo[key.to_sym] = nested_value
      end
    end

    def normalize_config_payload(value, source:)
      normalized_hash = normalize_hash_value!(
        key: :recording_studio_root_switchable,
        value: value,
        source: source
      )
      unknown_keys = normalized_hash.keys - SUPPORTED_MERGE_KEYS
      return normalized_hash if unknown_keys.empty?

      raise ConfigurationError.new(
        source: source,
        config_key: unknown_keys.first,
        detail: "unsupported configuration key(s): #{unknown_keys.join(', ')}"
      )
    end

    def normalize_hash_value!(key:, value:, source:)
      return normalize_hash(value) if value.respond_to?(:each_pair)

      raise ConfigurationError.new(
        source: source,
        config_key: key,
        detail: "expected a hash-like value"
      )
    end

    def validate_after_switch_redirect!(value, source:)
      return if value.nil? || value.is_a?(String) || value.respond_to?(:call)

      raise ConfigurationError.new(
        source: source,
        config_key: :after_switch_redirect,
        detail: "expected a String, callable, or nil"
      )
    end

    def validate_layout!(value, source:)
      return if value.nil? || value.is_a?(String) || value.is_a?(Symbol) || value.respond_to?(:call)

      raise ConfigurationError.new(
        source: source,
        config_key: :layout,
        detail: "expected a String, Symbol, callable, or nil"
      )
    end

    def validate_device_key_cookie_name!(value, source:)
      return if value.is_a?(String) || value.is_a?(Symbol)

      raise ConfigurationError.new(
        source: source,
        config_key: :device_key_cookie_name,
        detail: "expected a String or Symbol"
      )
    end

    def cast_boolean!(key:, value:, source:)
      return value if [true, false].include?(value)

      raise ConfigurationError.new(
        source: source,
        config_key: key,
        detail: "expected a boolean"
      )
    end

    def validate_device_key_cookie_options!(value, source:)
      if value.key?(:httponly) && value[:httponly] == false
        raise ConfigurationError.new(
          source: source,
          config_key: :device_key_cookie_options,
          detail: "httponly cannot be disabled"
        )
      end

      return unless value.key?(:same_site)

      same_site = value[:same_site].to_s.downcase.to_sym
      return if ALLOWED_SAME_SITE.include?(same_site)

      raise ConfigurationError.new(
        source: source,
        config_key: :device_key_cookie_options,
        detail: "same_site must be one of #{ALLOWED_SAME_SITE.join(', ')}"
      )
    end

    def apply_page_copy(value, source:)
      normalized_copy = normalize_hash_value!(key: :page_copy, value: value, source: source)
      validate_page_copy!(normalized_copy, source: source)

      @page_copy_overrides = normalized_copy
    end

    def validate_page_copy!(value, source:)
      unknown_keys = value.keys - DEFAULT_PAGE_COPY.keys
      unless unknown_keys.empty?
        raise ConfigurationError.new(
          source: source,
          config_key: :page_copy,
          detail: "unsupported page_copy key(s): #{unknown_keys.join(', ')}"
        )
      end

      invalid_value_key = value.find { |key, entry| !valid_page_copy_value?(entry, key: key) }&.first
      return unless invalid_value_key

      raise ConfigurationError.new(
        source: source,
        config_key: :page_copy,
        detail: "expected page_copy.#{invalid_value_key} to be " \
                "#{page_copy_value_type_phrase(invalid_value_key)}"
      )
    end

    def page_copy_value_type_phrase(key)
      allowed = "a String, Symbol i18n key, " \
                "String starting with #{PAGE_COPY_STRING_KEY_PREFIX.inspect}, " \
                "locale Hash, or callable"
      return "nil, #{allowed}" if OPTIONAL_PAGE_COPY_KEYS.include?(key)

      allowed
    end

    def valid_page_copy_value?(entry, key:)
      return true if entry.nil? && OPTIONAL_PAGE_COPY_KEYS.include?(key)
      return false if entry.nil?
      return true if entry.is_a?(String)
      return true if entry.is_a?(Symbol)
      return true if entry.respond_to?(:call)
      return false unless entry.respond_to?(:each_pair)

      entry.each_pair.all? do |locale, text|
        (locale.is_a?(String) || locale.is_a?(Symbol)) && text.is_a?(String)
      end
    end

    def resolve_page_copy_value(value, key:)
      return translate_configured_i18n_key(value, key: key) if value.is_a?(Symbol)

      if value.is_a?(String)
        if page_copy_string_i18n_key?(value)
          stripped = value.delete_prefix(PAGE_COPY_STRING_KEY_PREFIX)
          return translate_page_copy_key(key) if stripped.empty?

          return translate_configured_i18n_key(stripped, key: key)
        end

        return value
      end

      return resolve_page_copy_callable(value, key: key) if value.respond_to?(:call)
      return resolve_page_copy_locale_hash(value, key: key) if value.respond_to?(:each_pair)

      raise ConfigurationError.new(
        source: "page_copy resolution",
        config_key: :page_copy,
        detail: "unsupported page_copy.#{key} value: #{value.class}"
      )
    end

    def page_copy_string_i18n_key?(value)
      value.start_with?(PAGE_COPY_STRING_KEY_PREFIX)
    end

    def resolve_page_copy_locale_hash(value, key:)
      normalized = value.each_pair.with_object({}) do |(locale, text), memo|
        memo[locale.to_sym] = text
      end

      if normalized.key?(I18n.locale.to_sym)
        normalized.fetch(I18n.locale.to_sym)
      elsif normalized.key?(I18n.default_locale.to_sym)
        normalized.fetch(I18n.default_locale.to_sym)
      else
        translate_page_copy_key(key)
      end
    end

    def resolve_page_copy_callable(value, key:)
      parameters = value.respond_to?(:parameters) ? value.parameters : value.method(:call).parameters
      key_names = parameters.filter_map do |type, name|
        name if %i[key keyreq].include?(type)
      end
      has_keyrest = parameters.any? { |type, _| type == :keyrest }
      req_positional = parameters.count { |type, _| type == :req }
      opt_positional = parameters.count { |type, _| type == :opt }
      has_rest = parameters.any? { |type, _| type == :rest }

      kwargs = {}
      if has_keyrest
        kwargs = { key: key, locale: I18n.locale }
      else
        kwargs[:key] = key if key_names.include?(:key)
        kwargs[:locale] = I18n.locale if key_names.include?(:locale)
      end

      positional_slots = req_positional + opt_positional
      if has_rest || positional_slots.positive?
        args = []
        args << key if has_rest || positional_slots >= 1
        args << I18n.locale if has_rest || positional_slots >= 2
        return kwargs.empty? ? value.call(*args) : value.call(*args, **kwargs)
      end

      return value.call(**kwargs) unless kwargs.empty?

      value.call
    end

    def translate_configured_i18n_key(i18n_key, key:)
      I18n.t(
        i18n_key,
        default: [
          :"#{PAGE_COPY_I18N_PREFIX}.#{key}",
          DEFAULT_PAGE_COPY.fetch(key)
        ]
      )
    end

    def translate_page_copy_key(key)
      I18n.t(
        "#{PAGE_COPY_I18N_PREFIX}.#{key}",
        default: DEFAULT_PAGE_COPY.fetch(key)
      )
    end

    def log_configuration_rescue(hook_name, error)
      return unless defined?(Rails) && Rails.respond_to?(:env) && !Rails.env.production?

      logger = Rails.logger if Rails.respond_to?(:logger)
      return unless logger

      logger.warn(
        "RecordingStudioRootSwitchable: #{hook_name} raised #{error.class}: #{error.message}"
      )
    end
  end
end
