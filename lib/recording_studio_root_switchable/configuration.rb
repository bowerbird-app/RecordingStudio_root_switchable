# frozen_string_literal: true

require "active_support/core_ext/integer/time"

module RecordingStudioRootSwitchable
  class Configuration
    DEFAULT_PAGE_COPY = {
      title: "Switch root",
      subtitle: "Choose which accessible root Recording Studio should treat as current for this device and scope.",
      scope_heading: "Scopes",
      roots_heading: "Available roots",
      current_selection_label: "Current selection",
      device_label: "Device key",
      persistence_hint: "Selections are stored per actor, device, and scope.",
      selected_badge: "Selected",
      switch_action_label: "Switch root",
      empty_state_title: "No roots are available",
      empty_state_body: "This scope does not currently expose any accessible roots for the current actor."
    }.freeze

    attr_accessor :current_actor_resolver,
                  :default_scope_key_resolver,
                  :device_key_cookie_name,
                  :device_key_cookie_options,
                  :mounted_page_authorizer
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
      @mounted_page_authorizer = ->(actor:, **) { actor.present? }
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

    def page_copy=(value)
      @page_copy = DEFAULT_PAGE_COPY.merge(normalize_hash(value))
    end

    def page_copy_for(scope: nil)
      copy = @page_copy.dup
      return copy unless scope

      copy.merge(scope.page_copy)
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |key, value|
        case key.to_s
        when "device_key_cookie_name"
          self.device_key_cookie_name = value
        when "device_key_cookie_options"
          self.device_key_cookie_options = normalize_hash(value)
        when "page_copy"
          self.page_copy = value
        end
      end
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
  end
end
