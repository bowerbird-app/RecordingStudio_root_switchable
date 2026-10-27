# frozen_string_literal: true

require "test_helper"
require_relative "../app/components/recording_studio_root_switchable/root_switch/menu_rows"

class RootSwitchMenuRowsTest < Minitest::Test
  def test_rows_list_the_current_workspace_then_the_others
    rows = build_rows

    assert_equal ["Studio", "Client Alpha", "Client Beta"], rows.rows.map(&:label)
    assert_equal ["Studio"], rows.rows.select(&:current?).map(&:label)
    assert_equal ["Client Alpha", "Client Beta"], rows.switch_rows.map(&:label)
    assert_equal "Studio", rows.current_label
  end

  def test_rows_only_include_the_accessible_entries_they_were_given
    rows = build_rows

    refute_includes rows.rows.map(&:label), "Hidden Workspace"
    refute_includes rows.switch_rows.map(&:root_recording_id), "hidden"
  end

  def test_none_selected_label_is_used_when_nothing_is_current
    rows = RecordingStudioRootSwitchable::RootSwitch::MenuRows.build(
      entries: [{ id: "alpha", label: "Client Alpha" }],
      selected: nil,
      form_action: "/switch",
      return_to: "/placements",
      options: menu_options
    )

    assert_equal "None selected", rows.current_label
    assert_equal ["Client Alpha"], rows.switch_rows.map(&:label)
    assert_empty rows.rows.select(&:current?)
  end

  def test_selected_workspace_outside_the_accessible_list_is_not_a_switch_row
    rows = RecordingStudioRootSwitchable::RootSwitch::MenuRows.build(
      entries: [{ id: "alpha", label: "Client Alpha" }],
      selected: { id: "hidden", label: "Hidden Workspace" },
      form_action: "/switch",
      return_to: "/placements",
      options: menu_options
    )

    assert_equal "Hidden Workspace", rows.current_label
    assert_equal ["Client Alpha"], rows.rows.map(&:label)
    assert_equal ["Client Alpha"], rows.switch_rows.map(&:label)
  end

  def test_unsafe_return_to_is_dropped
    rows = build_rows(return_to: "https://evil.example/phish")

    assert_nil rows.return_to
    assert_equal({ root_switch: { root_recording_id: "alpha" } }, rows.form_params_for(rows.switch_rows.first))
  end

  def test_safe_return_to_is_sent_with_the_switch_form
    rows = build_rows(return_to: "/placements")

    assert_equal "/placements", rows.return_to
    assert_equal(
      { root_switch: { root_recording_id: "alpha", return_to: "/placements" } },
      rows.form_params_for(rows.switch_rows.first)
    )
  end

  def test_blank_resolution_builds_nothing
    rows = RecordingStudioRootSwitchable::RootSwitch::MenuRows.build(
      entries: [],
      selected: nil,
      form_action: "/switch",
      return_to: "/placements",
      options: menu_options
    )

    assert_nil rows
  end

  private

  def build_rows(return_to: "/placements")
    RecordingStudioRootSwitchable::RootSwitch::MenuRows.build(
      entries: [
        { id: "alpha", label: "Client Alpha" },
        { id: "studio", label: "Studio" },
        { id: "beta", label: "Client Beta" }
      ],
      selected: { id: "studio", label: "Studio" },
      form_action: "/recording_studio_root_switchable/v1/root_switch?scope=all_roots",
      return_to: return_to,
      options: menu_options
    )
  end

  def menu_options(new_root_path: nil, new_root_label: nil)
    RecordingStudioRootSwitchable::RootSwitch::MenuRows::Options.new(
      none_selected_label: "None selected",
      new_root_path: new_root_path,
      new_root_label: new_root_label
    )
  end
end
