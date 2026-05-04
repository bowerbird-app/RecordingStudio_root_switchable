# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioRootSwitchable::Configuration.new
  end

  def test_starts_without_scopes_until_the_host_app_registers_them
    assert_empty @configuration.scopes
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

  def test_merge_supports_page_copy_and_cookie_options
    @configuration.merge!(
      page_copy: { switch_action_label: "Activate root" },
      device_key_cookie_options: { same_site: :strict }
    )

    assert_equal "Activate root", @configuration.page_copy.fetch(:switch_action_label)
    assert_equal :strict, @configuration.device_key_cookie_options.fetch(:same_site)
  end
end
