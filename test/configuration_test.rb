# frozen_string_literal: true

require "test_helper"
require "i18n"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioRootSwitchable::Configuration.new
    @original_locale = I18n.locale
    @original_default_locale = I18n.default_locale
    @original_load_path = I18n.load_path.dup
    @original_backend = I18n.backend
    I18n.backend = I18n::Backend::Simple.new
    I18n.available_locales = %i[en fr es de]
    I18n.default_locale = :en
    I18n.locale = :en
    load_engine_page_copy_locales!
  end

  def teardown
    I18n.locale = @original_locale
    I18n.default_locale = @original_default_locale
    I18n.load_path = @original_load_path
    I18n.backend = @original_backend
    I18n.reload!
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

  def test_merge_rejects_invalid_page_copy_value_types
    error = assert_raises(RecordingStudioRootSwitchable::ConfigurationError) do
      @configuration.merge!(
        { page_copy: { switch_action_label: 123 } },
        source: "config/recording_studio_root_switchable.yml"
      )
    end

    assert_includes error.message, "expected page_copy.switch_action_label to be a String"
    refute_includes error.message, "nil,"
  end

  def test_merge_rejects_global_nil_for_each_required_page_copy_key
    required_keys = RecordingStudioRootSwitchable::Configuration::DEFAULT_PAGE_COPY.keys -
                    RecordingStudioRootSwitchable::Configuration::OPTIONAL_PAGE_COPY_KEYS

    required_keys.each do |key|
      configuration = RecordingStudioRootSwitchable::Configuration.new
      error = assert_raises(RecordingStudioRootSwitchable::ConfigurationError) do
        configuration.page_copy = { key => nil }
      end

      assert_includes error.message, "expected page_copy.#{key} to be a String"
      refute_includes error.message, "nil,"
    end
  end

  def test_merge_accepts_global_nil_for_optional_page_copy_keys_and_omits_at_render
    RecordingStudioRootSwitchable::Configuration::OPTIONAL_PAGE_COPY_KEYS.each do |key|
      @configuration.page_copy = { key => nil }

      copy = @configuration.page_copy_for

      assert_nil copy.fetch(key), "expected optional page_copy.#{key} nil to stay nil"
      assert_nil copy.fetch(key).presence, "expected optional page_copy.#{key} nil to omit at render"
    end
  end

  def test_merge_accepts_symbol_i18n_key_page_copy_values
    @configuration.merge!(page_copy: { title: :"my_app.root_switch.title" })

    assert_equal :"my_app.root_switch.title", @configuration.page_copy.fetch(:title)
  end

  def test_page_copy_for_resolves_plain_string_literally_in_every_locale
    @configuration.page_copy = { title: "Fixed title" }

    I18n.with_locale(:en) do
      assert_equal "Fixed title", @configuration.page_copy_for.fetch(:title)
    end
    I18n.with_locale(:fr) do
      assert_equal "Fixed title", @configuration.page_copy_for.fetch(:title)
    end
  end

  def test_page_copy_for_resolves_symbol_i18n_key_at_render_time
    I18n.backend.store_translations(:en, my_app: { root_switch: { title: "Host symbol title" } })
    @configuration.page_copy = { title: :"my_app.root_switch.title" }

    I18n.with_locale(:en) do
      assert_equal "Host symbol title", @configuration.page_copy_for.fetch(:title)
    end
  end

  def test_page_copy_for_resolves_i18n_prefixed_string_key_at_render_time
    I18n.backend.store_translations(:en, my_app: { root_switch: { badge: "Host string-key badge" } })
    @configuration.page_copy = { selected_badge: "i18n:my_app.root_switch.badge" }

    I18n.with_locale(:en) do
      assert_equal "Host string-key badge", @configuration.page_copy_for.fetch(:selected_badge)
    end
  end

  def test_page_copy_for_evaluates_zero_arity_callable_with_no_args
    @configuration.page_copy = { title: -> { "Zero arity" } }

    assert_equal "Zero arity", @configuration.page_copy_for.fetch(:title)
  end

  def test_page_copy_for_evaluates_positional_callable_with_key
    seen = nil
    @configuration.page_copy = {
      title: lambda { |key|
        seen = key
        "Positional #{key}"
      }
    }

    assert_equal "Positional title", @configuration.page_copy_for.fetch(:title)
    assert_equal :title, seen
  end

  def test_page_copy_for_evaluates_keyword_callable_with_declared_args
    seen = nil
    @configuration.page_copy = {
      title: lambda { |key:|
        seen = key
        "Keyword #{key}"
      }
    }

    assert_equal "Keyword title", @configuration.page_copy_for.fetch(:title)
    assert_equal :title, seen
  end

  def test_page_copy_for_evaluates_keyword_callable_with_key_and_locale
    calls = []
    @configuration.page_copy = {
      title: lambda { |key:, locale:, **|
        calls << [key, locale]
        "Callable #{locale}"
      }
    }

    I18n.with_locale(:en) { assert_equal "Callable en", @configuration.page_copy_for.fetch(:title) }
    I18n.with_locale(:fr) { assert_equal "Callable fr", @configuration.page_copy_for.fetch(:title) }

    assert_equal [%i[title en], %i[title fr]], calls
  end

  def test_page_copy_for_propagates_argument_error_raised_by_callable
    @configuration.page_copy = {
      title: lambda { |key:, **|
        raise ArgumentError, "callable failed for #{key}"
      }
    }

    error = assert_raises(ArgumentError) { @configuration.page_copy_for.fetch(:title) }
    assert_equal "callable failed for title", error.message
  end

  def test_page_copy_for_evaluates_callable_object_without_parameters_method
    callable = Object.new
    def callable.call
      "Plain call object"
    end
    refute_respond_to callable, :parameters

    @configuration.page_copy = { title: callable }

    assert_equal "Plain call object", @configuration.page_copy_for.fetch(:title)
  end

  def test_page_copy_for_treats_nil_scope_override_as_blank_like_main
    @configuration.scope(:clients) do |scope|
      scope.page_copy = { subtitle: nil, title: "Clients" }
    end
    scope = @configuration.scopes.fetch("clients")

    copy = @configuration.page_copy_for(scope: scope)

    assert_nil copy.fetch(:subtitle)
    assert_equal "Clients", copy.fetch(:title)
    assert_nil copy.fetch(:subtitle).presence
  end

  def test_scope_rejects_nil_for_required_page_copy_keys
    required_keys = RecordingStudioRootSwitchable::Configuration::DEFAULT_PAGE_COPY.keys -
                    RecordingStudioRootSwitchable::Configuration::OPTIONAL_PAGE_COPY_KEYS

    required_keys.each do |key|
      configuration = RecordingStudioRootSwitchable::Configuration.new
      error = assert_raises(RecordingStudioRootSwitchable::ConfigurationError) do
        configuration.scope(:clients) do |scope|
          scope.page_copy = { key => nil }
        end
      end

      assert_includes error.message, "expected page_copy.#{key} to be a String"
      refute_includes error.message, "nil,"
    end
  end

  def test_page_copy_for_missing_symbol_key_falls_back_to_gem_key_in_current_locale
    I18n.backend.store_translations(
      :fr,
      recording_studio: { root_switchable: { page_copy: { title: "Changer" } } }
    )
    @configuration.page_copy = { title: :"missing.host.key" }

    I18n.with_locale(:fr) do
      assert_equal "Changer", @configuration.page_copy_for.fetch(:title)
    end
  end

  def test_page_copy_for_missing_i18n_string_key_falls_back_to_gem_key_in_current_locale
    I18n.backend.store_translations(
      :fr,
      recording_studio: { root_switchable: { page_copy: { selected_badge: "Actuel" } } }
    )
    @configuration.page_copy = { selected_badge: "i18n:missing.host.badge" }

    I18n.with_locale(:fr) do
      assert_equal "Actuel", @configuration.page_copy_for.fetch(:selected_badge)
    end
  end

  def test_page_copy_for_bare_i18n_prefix_falls_back_to_gem_key
    @configuration.page_copy = { title: "i18n:" }

    I18n.with_locale(:en) do
      assert_equal "Switch", @configuration.page_copy_for.fetch(:title)
    end
  end

  def test_page_copy_for_uses_hash_entry_for_current_locale
    @configuration.page_copy = { title: { en: "Switch EN", fr: "Changer" } }

    I18n.with_locale(:fr) do
      assert_equal "Changer", @configuration.page_copy_for.fetch(:title)
    end
  end

  def test_page_copy_for_hash_falls_back_to_default_locale
    original_default = I18n.default_locale
    I18n.default_locale = :en
    @configuration.page_copy = { title: { en: "Default locale title" } }

    I18n.with_locale(:fr) do
      assert_equal "Default locale title", @configuration.page_copy_for.fetch(:title)
    end
  ensure
    I18n.default_locale = original_default
  end

  def test_page_copy_for_hash_falls_back_to_gem_key
    I18n.backend.store_translations(
      :es,
      recording_studio: { root_switchable: { page_copy: { title: "Cambiar" } } }
    )
    @configuration.page_copy = { title: { de: "Wechseln" } }

    I18n.with_locale(:es) do
      assert_equal "Cambiar", @configuration.page_copy_for.fetch(:title)
    end
  end

  def test_page_copy_for_without_config_uses_gem_english
    I18n.with_locale(:en) do
      copy = @configuration.page_copy_for

      assert_equal "Switch", copy.fetch(:title)
      assert_equal "Current", copy.fetch(:selected_badge)
      assert_equal "Nothing to switch", copy.fetch(:empty_state_title)
      assert_equal "There are no options available right now.", copy.fetch(:empty_state_body)
    end
  end

  def test_page_copy_for_follows_locale_without_memoizing_boot_defaults
    I18n.backend.store_translations(
      :fr,
      recording_studio: { root_switchable: { page_copy: { title: "Changer", selected_badge: "Actuel" } } }
    )

    en_copy = I18n.with_locale(:en) { @configuration.page_copy_for }
    fr_copy = I18n.with_locale(:fr) { @configuration.page_copy_for }
    en_again = I18n.with_locale(:en) { @configuration.page_copy_for }

    assert_equal "Switch", en_copy.fetch(:title)
    assert_equal "Changer", fr_copy.fetch(:title)
    assert_equal "Actuel", fr_copy.fetch(:selected_badge)
    assert_equal "Switch", en_again.fetch(:title)
    assert_equal "Current", en_again.fetch(:selected_badge)
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

  private

  def load_engine_page_copy_locales!
    path = File.expand_path("../config/locales/en.yml", __dir__)
    I18n.load_path |= [path]
    I18n.backend.load_translations
  end
end
