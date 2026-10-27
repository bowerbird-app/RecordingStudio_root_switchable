# frozen_string_literal: true

require "test_helper"
require "action_controller"
require "recording_studio/configuration"
require "recording_studio/controller_layout"

require File.join(
  Gem.loaded_specs.fetch("recording_studio").full_gem_path,
  "app/helpers/recording_studio/layout_helper"
)

class LayoutConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioRootSwitchable::Configuration.new
    @previous_root_switchable = RecordingStudioRootSwitchable.instance_variable_get(:@configuration)
    @previous_layout = RecordingStudio.configuration.layout
    RecordingStudioRootSwitchable.instance_variable_set(:@configuration, @configuration)
  end

  def teardown
    RecordingStudioRootSwitchable.instance_variable_set(:@configuration, @previous_root_switchable)
    RecordingStudio.configuration.layout = @previous_layout
  end

  def test_layout_defaults_to_nil
    assert_nil @configuration.layout
  end

  def test_nil_layout_falls_through_to_recording_studio_then_the_default_name
    RecordingStudio.configuration.layout = nil

    assert_equal "recording_studio/default_layout", probe.recording_studio_resolved_layout

    RecordingStudio.configuration.layout = "host_pages"
    assert_equal "host_pages", probe.recording_studio_resolved_layout
  end

  def test_string_layout_is_used_as_the_layout_name
    @configuration.layout = "root_switch_pages"

    assert_equal "root_switch_pages", probe.recording_studio_resolved_layout
  end

  def test_false_layout_renders_no_layout
    @configuration.layout = false

    assert_equal false, probe.recording_studio_resolved_layout
  end

  def test_keyword_callable_receives_the_controller
    @configuration.layout = ->(controller:) { controller.class.name }

    assert_equal "RootSwitchableLayoutProbeController", probe.recording_studio_resolved_layout
  end

  def test_invalid_layout_values_raise_argument_error
    assert_raises(ArgumentError) { @configuration.layout = "" }
    assert_raises(ArgumentError) { @configuration.layout = :application_layout }
    assert_raises(ArgumentError) { @configuration.layout = 1 }
    assert_raises(ArgumentError) { @configuration.layout = ->(_) { "pages" } }
    assert_raises(ArgumentError) { @configuration.layout = -> { "pages" } }
  end

  def test_controllers_do_not_hardcode_a_recording_studio_layout
    gem_root = File.expand_path("..", __dir__)
    dummy_root = File.expand_path("dummy", __dir__)

    assert_empty RecordingStudio::Layout.hardcoded_layout_paths(gem_root)
    assert_empty RecordingStudio::Layout.hardcoded_layout_paths(dummy_root)
  end

  private

  def probe
    RootSwitchableLayoutProbeController.new
  end
end

unless RecordingStudio.respond_to?(:configuration)
  def RecordingStudio.configuration
    @configuration ||= RecordingStudio::Configuration.new
  end
end

class RootSwitchableLayoutProbeController < ActionController::Base
  include RecordingStudio::ControllerLayout

  recording_studio_layout { RecordingStudioRootSwitchable.configuration.layout }
end
