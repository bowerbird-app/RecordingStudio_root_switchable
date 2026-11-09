# frozen_string_literal: true

require "test_helper"
require_relative "../app/components/recording_studio_root_switchable/root_switch/compact_trigger"
require_relative "../app/components/recording_studio_root_switchable/root_switch/menu_rows"

class RootSwitchCompactTriggerTest < Minitest::Test
  def test_default_compact_is_nil
    assert_nil RecordingStudioRootSwitchable::RootSwitch::CompactTrigger.normalize!(nil)
  end

  def test_below_md_and_always_are_accepted
    assert_equal :below_md, RecordingStudioRootSwitchable::RootSwitch::CompactTrigger.normalize!(:below_md)
    assert_equal :always, RecordingStudioRootSwitchable::RootSwitch::CompactTrigger.normalize!(:always)
    assert_equal :below_md, RecordingStudioRootSwitchable::RootSwitch::CompactTrigger.normalize!("below_md")
  end

  def test_default_badge_size_matches_dummy_account_avatar
    assert_equal :sm, RecordingStudioRootSwitchable::RootSwitch::CompactTrigger::DEFAULT_BADGE_SIZE
  end

  def test_invalid_compact_raises
    error = assert_raises(ArgumentError) do
      RecordingStudioRootSwitchable::RootSwitch::CompactTrigger.normalize!(:phone)
    end

    assert_match(/Invalid compact: :phone/, error.message)
    assert_match(/nil, :below_md, or :always/, error.message)
  end

  def test_initials_from_one_word
    assert_equal "ST", RecordingStudioRootSwitchable::RootSwitch::CompactTrigger.initials("Studio")
  end

  def test_initials_from_two_or_more_words
    assert_equal "CA", RecordingStudioRootSwitchable::RootSwitch::CompactTrigger.initials("Client Alpha")
    assert_equal "CA", RecordingStudioRootSwitchable::RootSwitch::CompactTrigger.initials("Cloud Agent Studio")
  end

  def test_emoji_and_blank_have_no_initials
    assert_nil RecordingStudioRootSwitchable::RootSwitch::CompactTrigger.initials("")
    assert_nil RecordingStudioRootSwitchable::RootSwitch::CompactTrigger.initials("   ")
    assert_nil RecordingStudioRootSwitchable::RootSwitch::CompactTrigger.initials("🚀")
    assert_nil RecordingStudioRootSwitchable::RootSwitch::CompactTrigger.initials("🔥✨")
  end

  def test_none_selected_rows_are_detected
    rows = RecordingStudioRootSwitchable::RootSwitch::MenuRows.build(
      entries: [{ id: "alpha", label: "Client Alpha" }],
      selected: nil,
      form_action: "/switch",
      return_to: "/placements",
      options: RecordingStudioRootSwitchable::RootSwitch::MenuRows::Options.new(
        none_selected_label: "None selected",
        new_root_path: nil,
        new_root_label: nil,
        new_root_icon: nil
      )
    )

    assert_predicate rows, :none_selected?
    assert_equal "None selected", rows.current_label
  end

  def test_selected_rows_are_not_none_selected
    rows = RecordingStudioRootSwitchable::RootSwitch::MenuRows.build(
      entries: [{ id: "studio", label: "Studio" }],
      selected: { id: "studio", label: "Studio" },
      form_action: "/switch",
      return_to: "/placements",
      options: RecordingStudioRootSwitchable::RootSwitch::MenuRows::Options.new(
        none_selected_label: "None selected",
        new_root_path: nil,
        new_root_label: nil,
        new_root_icon: nil
      )
    )

    refute_predicate rows, :none_selected?
  end
end
