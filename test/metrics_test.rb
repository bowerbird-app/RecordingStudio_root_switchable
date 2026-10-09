# frozen_string_literal: true

require "test_helper"

class MetricsTest < Minitest::Test
  def test_access_can_view_is_false_without_actor_or_admin_root
    context = Object.new
    def context.access_grant
      nil
    end

    refute RecordingStudioRootSwitchable::Api::Access.can_view?(context)
  end

  def test_access_can_view_is_false_when_accessible_is_not_loaded
    actor = Object.new
    recording = Object.new
    grant = Struct.new(:actor).new(actor)
    context = Object.new
    context.define_singleton_method(:access_grant) { grant }

    RecordingStudioRootSwitchable::Api::Access.stub(:admin_root_recording, recording) do
      refute RecordingStudioRootSwitchable::Api::Access.can_view?(context)
    end
  end

  def test_access_can_view_uses_admin_root_view
    context = Object.new

    RecordingStudioRootSwitchable::Api::Access.stub(:authorized_on_admin_root?, true) do
      assert RecordingStudioRootSwitchable::Api::Access.can_view?(context)
    end
  end

  def test_register_defines_last_used_selection_metrics
    RecordingStudioMetrics.registry.reset!
    RecordingStudioRootSwitchable::Metrics.register!

    identifiers = RecordingStudioMetrics.for_resource(:root_selections).map(&:identifier)
    assert_equal expected_identifiers, identifiers.sort

    RecordingStudioMetrics.for_resource(:root_selections).each do |definition|
      assert_equal [:operations], definition.exposed_apis
      assert_equal :site, definition.blast_radius
      refute_equal :user_agent, definition.field
    end

    %w[root_selections.by_device_type root_selections.by_platform root_selections.by_browser].each do |id|
      assert_equal :breakdown, RecordingStudioMetrics.find(id).metric_type
    end
  ensure
    RecordingStudioMetrics.registry.reset!
  end

  private

  def expected_identifiers
    %w[
      root_selections.active_actors_30d
      root_selections.active_actors_7d
      root_selections.active_devices_30d
      root_selections.by_browser
      root_selections.by_device_type
      root_selections.by_platform
    ]
  end
end
