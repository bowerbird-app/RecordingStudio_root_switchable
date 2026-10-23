# frozen_string_literal: true

require "test_helper"
require_relative "../app/components/recording_studio_root_switchable/root_switch/menu_rows"
require_relative "../app/components/recording_studio_root_switchable/root_switch/context"

class RootSwitchContextTest < Minitest::Test
  Root = Struct.new(:id)
  Resolution = Struct.new(:scope, :root_recording, :available_roots)
  Scope = Struct.new(:key) do
    def root_label_for(recording:, **)
      {
        "studio" => "Studio Workspace",
        "alpha" => "Client Alpha",
        "hidden" => "Hidden Workspace"
      }.fetch(recording.id)
    end
  end

  def test_rows_come_from_the_resolution_available_roots
    hidden = Root.new("hidden")
    studio = Root.new("studio")
    alpha = Root.new("alpha")
    scope = Scope.new("all_roots")
    resolution = Resolution.new(scope, studio, [studio, alpha])
    controller = Struct.new(:current_root_resolution, :current_root_device_key).new(resolution, "device-1")
    seen_scopes = []

    rows = RecordingStudioRootSwitchable::RootSwitch::Context.new(
      controller: controller,
      return_to: "//evil.example",
      form_action_for: lambda { |resolved_scope|
        seen_scopes << resolved_scope
        "/switch?scope=#{resolved_scope.key}"
      },
      none_selected_label: "None selected"
    ).menu_rows

    assert_equal ["all_roots"], seen_scopes.map(&:key)
    assert_equal ["Studio Workspace", "Client Alpha"], rows.rows.map(&:label)
    assert_equal ["Client Alpha"], rows.switch_rows.map(&:label)
    assert_equal "/switch?scope=all_roots", rows.form_action
    assert_nil rows.return_to
    refute_includes rows.rows.map(&:label), "Hidden Workspace"
    refute_equal hidden.id, rows.switch_rows.first.root_recording_id
  end

  def test_missing_resolution_builds_nothing
    controller = Object.new

    rows = RecordingStudioRootSwitchable::RootSwitch::Context.new(
      controller: controller,
      return_to: "/placements",
      form_action_for: ->(_) { "/switch" },
      none_selected_label: "None selected"
    ).menu_rows

    assert_nil rows
  end
end
