# frozen_string_literal: true

require "active_support/core_ext/integer/time"

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
      device_key_cookie_name
      device_key_cookie_options
      layout
      page_copy
    ].freeze

    DEFAULT_PAGE_COPY = {
      title: "Switch root",
      subtitle: "Choose which accessible root Recording Studio should treat as current for this device and scope.",
      scope_heading: "Scopes",
      roots_heading: "Available roots",
      current_selection_label: "Current selection",
      device_label: "Device key",
      persistence_hint: "Selections are stored per actor, device, and scope.",
      selected_badge: "Current",
      switch_action_label: "Switch root",
      empty_state_title: "No roots are available",
      empty_state_body: "This scope does not currently expose any accessible roots for the current actor."
    }.freeze

    attr_accessor :current_actor_resolver,
                  :default_scope_key_resolver,
                  :device_key_cookie_name,
                  :device_key_cookie_options,
                  :layout,
                  :mounted_page_authorizer,
                  :after_switch_redirect
    attr_reader :page_copy, :scopes

    def initialize
      @device_key_cookie_name = :recording_studio_root_switchable_device_key
      @device_key_cookie_options = {
        expires: 1.year,
        httponly: true,
        same_site: :lax
      }
      @page_copy = DEFAULT_PAGE_COPY.dup
      @scopes = {}
      @current_actor_resolver = default_current_actor_resolver
      @default_scope_key_resolver = ->(scopes:, **) { scopes.first&.key }
      @layout = nil
      @mounted_page_authorizer = ->(actor:, **) { actor.present? }
      @after_switch_redirect = nil
    end

    def scope(key, **options)
      definition = scopes[key.to_s] ||= RecordingStudio::RootSwitchable::ScopeDefinition.new(key)
      definition.assign!(options)
      yield(definition) if block_given?
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
    rescue StandardError
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

    def page_copy_for(scope: nil)
      copy = @page_copy.dup
      return copy unless scope

      copy.merge(scope.page_copy)
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
          self.device_key_cookie_options = normalize_hash_value!(
            key: key,
            value: value,
            source: source
          )
        when :layout
          validate_layout!(value, source: source)
          self.layout = value
        when :page_copy
          apply_page_copy(value, source: source)
        when :after_switch_redirect
          validate_after_switch_redirect!(value, source: source)
          self.after_switch_redirect = value
        end
      end

      self
    end

    private

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

    def apply_page_copy(value, source:)
      normalized_copy = normalize_hash_value!(key: :page_copy, value: value, source: source)
      validate_page_copy!(normalized_copy, source: source)

      @page_copy = DEFAULT_PAGE_COPY.merge(normalized_copy)
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

      invalid_value_key = value.find { |_, entry| !entry.is_a?(String) }&.first
      return unless invalid_value_key

      raise ConfigurationError.new(
        source: source,
        config_key: :page_copy,
        detail: "expected page_copy.#{invalid_value_key} to be a String"
      )
    end
  end
end
