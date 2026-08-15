# frozen_string_literal: true

require "test_helper"
require "action_controller/railtie"
require_relative "../app/controllers/recording_studio_root_switchable/application_controller"
require_relative "../app/controllers/recording_studio_root_switchable/root_switches_controller"

class RootSwitchesControllerTest < Minitest::Test
  Scope = Struct.new(:key)
  Result = Struct.new(:root_recording)

  def setup
    @original_configuration = RecordingStudioRootSwitchable.instance_variable_get(:@configuration)
    RecordingStudioRootSwitchable.reset_configuration!
    @controller = RecordingStudioRootSwitchable::RootSwitchesController.new
    @controller.define_singleton_method(:root_switch_path) do |scope:|
      "/recording_studio_root_switchable/v1/root_switch?scope=#{scope}"
    end
    @scope = Scope.new("all_workspaces")
    @result = Result.new(Object.new)
    @controller.instance_variable_set(:@scope, @scope)
    RecordingStudio::RootSwitchable::Current.actor = Object.new
    RecordingStudio::RootSwitchable::Current.device_key = "device-1"
  end

  def teardown
    RecordingStudio::RootSwitchable::Current.reset
    RecordingStudioRootSwitchable.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_after_switch_redirect_location_defaults_to_root_switch_page
    @controller.stub(:root_switch_params, ActionController::Parameters.new) do
      assert_equal "/recording_studio_root_switchable/v1/root_switch?scope=all_workspaces",
                   @controller.send(:after_switch_redirect_location, @result)
    end
  end

  def test_after_switch_redirect_location_uses_valid_return_to_from_configured_proc
    RecordingStudioRootSwitchable.configuration.after_switch_redirect = lambda do |return_to:, **|
      return_to
    end

    @controller.stub(:root_switch_params, ActionController::Parameters.new(return_to: "/projects/current")) do
      assert_equal "/projects/current", @controller.send(:after_switch_redirect_location, @result)
    end
  end

  def test_after_switch_redirect_location_rejects_external_redirects
    RecordingStudioRootSwitchable.configuration.after_switch_redirect = lambda do |return_to:, **|
      return_to
    end

    @controller.stub(:root_switch_params, ActionController::Parameters.new(return_to: "https://example.com/phish")) do
      assert_equal "/recording_studio_root_switchable/v1/root_switch?scope=all_workspaces",
                   @controller.send(:after_switch_redirect_location, @result)
    end
  end

  def test_after_switch_redirect_location_rejects_protocol_relative_redirects
    RecordingStudioRootSwitchable.configuration.after_switch_redirect = lambda do |return_to:, **|
      return_to
    end

    @controller.stub(:root_switch_params, ActionController::Parameters.new(return_to: "//example.com/phish")) do
      assert_equal "/recording_studio_root_switchable/v1/root_switch?scope=all_workspaces",
                   @controller.send(:after_switch_redirect_location, @result)
    end
  end

  def test_after_switch_redirect_location_rejects_malformed_redirects
    RecordingStudioRootSwitchable.configuration.after_switch_redirect = lambda do |return_to:, **|
      return_to
    end

    @controller.stub(:root_switch_params, ActionController::Parameters.new(return_to: "/bad[uri")) do
      assert_equal "/recording_studio_root_switchable/v1/root_switch?scope=all_workspaces",
                   @controller.send(:after_switch_redirect_location, @result)
    end
  end

  def test_after_switch_redirect_location_rejects_backslash_open_redirect_tricks
    RecordingStudioRootSwitchable.configuration.after_switch_redirect = lambda do |return_to:, **|
      return_to
    end

    @controller.stub(:root_switch_params, ActionController::Parameters.new(return_to: "/\\example.com")) do
      assert_equal "/recording_studio_root_switchable/v1/root_switch?scope=all_workspaces",
                   @controller.send(:after_switch_redirect_location, @result)
    end
  end

  def test_after_switch_redirect_sanitizes_return_to_before_host_callback
    observed_return_to = :unset
    RecordingStudioRootSwitchable.configuration.after_switch_redirect = lambda do |return_to:, **|
      observed_return_to = return_to
      return_to
    end

    @controller.stub(:root_switch_params, ActionController::Parameters.new(return_to: "https://example.com/phish")) do
      @controller.send(:after_switch_redirect_location, @result)
    end

    assert_nil observed_return_to
  end

  def test_return_anchor_url_prefers_safe_return_to_param
    @controller.stub(:params, ActionController::Parameters.new(return_to: "/projects/current")) do
      assert_equal "/projects/current", @controller.send(:return_anchor_url)
    end
  end

  def test_return_anchor_url_prefers_safe_nested_return_to_param
    params = ActionController::Parameters.new(root_switch: { return_to: "/projects/current" }, return_to: "/fallback")

    @controller.stub(:params, params) do
      assert_equal "/projects/current", @controller.send(:return_anchor_url)
    end
  end

  def test_return_anchor_url_rejects_unsafe_return_to_param
    @controller.stub(:params, ActionController::Parameters.new(return_to: "https://example.com/phish")) do
      assert_equal "/recording_studio_root_switchable/v1/root_switch?scope=all_workspaces",
                   @controller.send(:return_anchor_url)
    end
  end

  def test_root_switch_params_treats_malformed_scalar_payload_as_empty_params
    @controller.stub(:params, ActionController::Parameters.new(root_switch: "bad")) do
      assert_empty @controller.send(:root_switch_params)
    end
  end

  def test_prepare_page_places_selected_root_first_in_available_roots
    root_class = Struct.new(:id)
    first_root = root_class.new(1)
    selected_root = root_class.new(2)
    third_root = root_class.new(3)
    result = Struct.new(:root_recording, :available_roots).new(selected_root, [first_root, third_root, selected_root])

    @controller.stub(:page_copy, {}) do
      @controller.stub(:safe_return_to_param, nil) do
        @controller.stub(:return_anchor_url, "/") do
          @controller.send(:prepare_page, result: result)
        end
      end
    end

    assert_equal [selected_root, first_root, third_root], @controller.instance_variable_get(:@available_roots)
  end

  def test_after_switch_redirect_location_supports_nominated_path_string
    RecordingStudioRootSwitchable.configuration.after_switch_redirect = "/workspace_home"

    @controller.stub(:root_switch_params, ActionController::Parameters.new) do
      assert_equal "/workspace_home", @controller.send(:after_switch_redirect_location, @result)
    end
  end

  def test_resolved_layout_defaults_to_gem_blank_layout
    assert_equal "recording_studio_root_switchable/blank", @controller.send(:resolved_layout)
  end

  def test_resolved_layout_uses_configured_string_layout
    RecordingStudioRootSwitchable.configuration.layout = "application"

    assert_equal "application", @controller.send(:resolved_layout)
  end

  def test_resolved_layout_calls_configured_symbol_layout_method
    RecordingStudioRootSwitchable.configuration.layout = :application_layout
    @controller.define_singleton_method(:application_layout) { "flat_pack_sidebar" }

    assert_equal "flat_pack_sidebar", @controller.send(:resolved_layout)
  end

  def test_resolved_layout_calls_configured_proc
    RecordingStudioRootSwitchable.configuration.layout = lambda do |scope:, **|
      scope.key == "all_workspaces" ? "application" : "admin"
    end

    assert_equal "application", @controller.send(:resolved_layout)
  end

  def test_resolved_layout_falls_back_to_gem_blank_layout_when_layout_method_errors
    RecordingStudioRootSwitchable.configuration.layout = :application_layout
    @controller.define_singleton_method(:application_layout) { raise "boom" }

    assert_equal "recording_studio_root_switchable/blank", @controller.send(:resolved_layout)
  end
end
