# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioRootSwitchable::Configuration.new
  end

  def test_starts_without_scopes_until_the_host_app_registers_them
    assert_empty @configuration.scopes
  end

  def test_default_page_copy_uses_current_badge_label
    assert_equal "Current", @configuration.page_copy.fetch(:selected_badge)
  end

  def test_default_page_copy_keeps_switch_ui_minimal
    copy = @configuration.page_copy

    assert_equal "Switch", copy.fetch(:title)
    assert_equal "", copy.fetch(:subtitle)
    assert_equal "", copy.fetch(:persistence_hint)
    assert_equal "Switch", copy.fetch(:switch_action_label)
    assert_equal "Nothing to switch", copy.fetch(:empty_state_title)
    refute_match(/\broot\b/i, copy.fetch(:title))
    refute_match(/\broot\b/i, copy.fetch(:switch_action_label))
    refute_match(/\broot\b/i, copy.fetch(:empty_state_title))
    refute_match(/\broot\b/i, copy.fetch(:empty_state_body))
  end

  def test_layout_defaults_to_nil_for_gem_blank_layout
    assert_nil @configuration.layout
  end

  def test_scope_registration_preserves_configuration_hooks
    @configuration.scope(:clients) do |scope|
      scope.label = ->(**) { "Client roots" }
      scope.description = "Customer-facing workspaces"
      scope.page_copy = { title: "Client root switcher" }
    end

    scope = @configuration.scopes.fetch("clients")

    assert_equal "Client roots", scope.label_for
    assert_equal "Customer-facing workspaces", scope.description_for
    assert_equal "Client root switcher", @configuration.page_copy_for(scope: scope).fetch(:title)
  end

  def test_resolve_scope_uses_default_scope_key_resolver
    @configuration.scope(:clients)
    @configuration.default_scope_key_resolver = ->(scopes:, **) { scopes.last.key }

    scope = @configuration.resolve_scope(key: nil, controller: nil, actor: Object.new, device_key: "device-1")

    assert_equal "clients", scope.key
  end

  def test_merge_supports_page_copy_cookie_options_and_layout
    @configuration.merge!(
      page_copy: { switch_action_label: "Activate root" },
      device_key_cookie_options: { same_site: :strict },
      layout: "application",
      after_switch_redirect: "/dashboard"
    )

    assert_equal "Activate root", @configuration.page_copy.fetch(:switch_action_label)
    assert_equal :strict, @configuration.device_key_cookie_options.fetch(:same_site)
    assert @configuration.device_key_cookie_options.fetch(:httponly)
    assert @configuration.device_key_cookie_options.fetch(:expires)
    assert_equal "application", @configuration.layout
    assert_equal "/dashboard", @configuration.after_switch_redirect
  end

  def test_merge_preserves_default_device_cookie_options_when_partial_options_are_supplied
    @configuration.merge!(device_key_cookie_options: { secure: true })

    assert @configuration.device_key_cookie_options.fetch(:secure)
    assert @configuration.device_key_cookie_options.fetch(:httponly)
    assert_equal :lax, @configuration.device_key_cookie_options.fetch(:same_site)
    assert @configuration.device_key_cookie_options.fetch(:expires)
  end

  def test_merge_rejects_disabling_httponly_on_device_key_cookie
    error = assert_raises(RecordingStudioRootSwitchable::ConfigurationError) do
      @configuration.merge!(device_key_cookie_options: { httponly: false })
    end

    assert_includes error.message, "httponly cannot be disabled"
  end

  def test_resolved_device_key_cookie_options_force_httponly
    @configuration.device_key_cookie_options = @configuration.device_key_cookie_options.merge(httponly: false)

    assert @configuration.resolved_device_key_cookie_options.fetch(:httponly)
  end

  def test_defaults_disable_anonymous_selections_and_raw_user_agent
    refute @configuration.allow_anonymous_selections
    refute @configuration.store_raw_user_agent
  end

  def test_merge_preserves_false_boolean_flags
    @configuration.allow_anonymous_selections = true
    @configuration.store_raw_user_agent = true

    @configuration.merge!(
      allow_anonymous_selections: false,
      store_raw_user_agent: false
    )

    refute @configuration.allow_anonymous_selections
    refute @configuration.store_raw_user_agent
  end

  def test_merge_rejects_unknown_top_level_keys
    error = assert_raises(RecordingStudioRootSwitchable::ConfigurationError) do
      @configuration.merge!({ unknown_option: true }, source: "config.x.recording_studio_root_switchable")
    end

    assert_includes error.message, "unsupported configuration key(s): unknown_option"
    assert_equal "config.x.recording_studio_root_switchable", error.source
  end

  def test_merge_rejects_non_hash_page_copy
    error = assert_raises(RecordingStudioRootSwitchable::ConfigurationError) do
      @configuration.merge!({ page_copy: "invalid" }, source: "config.x.recording_studio_root_switchable")
    end

    assert_includes error.message, "expected a hash-like value"
    assert_equal :page_copy, error.config_key
  end

  def test_merge_rejects_unknown_page_copy_keys
    error = assert_raises(RecordingStudioRootSwitchable::ConfigurationError) do
      @configuration.merge!(
        { page_copy: { unsupported_label: "Nope" } },
        source: "config/recording_studio_root_switchable.yml"
      )
    end

    assert_includes error.message, "unsupported page_copy key(s): unsupported_label"
  end

  def test_merge_rejects_non_string_page_copy_values
    error = assert_raises(RecordingStudioRootSwitchable::ConfigurationError) do
      @configuration.merge!(
        { page_copy: { switch_action_label: :activate } },
        source: "config/recording_studio_root_switchable.yml"
      )
    end

    assert_includes error.message, "expected page_copy.switch_action_label to be a String"
  end

  def test_merge_rejects_invalid_after_switch_redirect_type
    error = assert_raises(RecordingStudioRootSwitchable::ConfigurationError) do
      @configuration.merge!(
        { after_switch_redirect: 123 },
        source: "config.x.recording_studio_root_switchable"
      )
    end

    assert_includes error.message, "expected a String, callable, or nil"
  end

  def test_merge_rejects_invalid_layout_type
    error = assert_raises(RecordingStudioRootSwitchable::ConfigurationError) do
      @configuration.merge!(
        { layout: 123 },
        source: "config.x.recording_studio_root_switchable"
      )
    end

    assert_includes error.message, "expected a String, Symbol, callable, or nil"
    assert_equal :layout, error.config_key
  end

  def test_after_switch_redirect_calls_configured_proc_with_context
    redirect_proc = lambda do |scope:, return_to:, **|
      return_to.presence || "/#{scope.key}"
    end
    @configuration.after_switch_redirect = redirect_proc
    scope = Struct.new(:key).new("clients")

    redirect = @configuration.after_switch_redirect_for(
      controller: Object.new,
      actor: Object.new,
      device_key: "device-1",
      scope: scope,
      root_recording: Object.new,
      return_to: "/projects"
    )

    assert_equal "/projects", redirect
  end

  def test_layout_for_calls_configured_proc_with_context
    layout_proc = lambda do |scope:, **|
      scope.key == "clients" ? "application" : "admin"
    end
    @configuration.layout = layout_proc
    scope = Struct.new(:key).new("clients")

    layout = @configuration.layout_for(
      controller: Object.new,
      actor: Object.new,
      device_key: "device-1",
      scope: scope,
      current_root_recording: Object.new
    )

    assert_equal "application", layout
  end
end
