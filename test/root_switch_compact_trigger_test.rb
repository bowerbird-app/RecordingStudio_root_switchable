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

  def test_default_compact_chrome_is_bare
    assert_equal :bare, RecordingStudioRootSwitchable::RootSwitch::CompactTrigger.normalize_chrome!(nil)
  end

  def test_bare_and_button_chrome_are_accepted
    assert_equal :bare, RecordingStudioRootSwitchable::RootSwitch::CompactTrigger.normalize_chrome!(:bare)
    assert_equal :button, RecordingStudioRootSwitchable::RootSwitch::CompactTrigger.normalize_chrome!(:button)
    assert_equal :button, RecordingStudioRootSwitchable::RootSwitch::CompactTrigger.normalize_chrome!("button")
  end

  def test_invalid_compact_chrome_raises
    error = assert_raises(ArgumentError) do
      RecordingStudioRootSwitchable::RootSwitch::CompactTrigger.normalize_chrome!(:ghost)
    end

    assert_match(/Invalid compact_chrome: :ghost/, error.message)
    assert_match(/:bare or :button/, error.message)
  end

  def test_default_badge_size_matches_dummy_account_avatar
    assert_equal :sm, RecordingStudioRootSwitchable::RootSwitch::CompactTrigger::DEFAULT_BADGE_SIZE
  end

  def test_bare_chrome_keeps_default_badge_size
    size = RecordingStudioRootSwitchable::RootSwitch::CompactTrigger.resolve_badge_size!(
      badge_size: nil,
      compact_chrome: :bare,
      button_size: :md
    )

    assert_equal :sm, size
  end

  def test_compact_wrapper_classes_are_static
    always = RecordingStudioRootSwitchable::RootSwitch::CompactTrigger.wrapper_class(
      compact: :always,
      chrome: :bare,
      size: :sm
    )
    below = RecordingStudioRootSwitchable::RootSwitch::CompactTrigger.wrapper_class(
      compact: :below_md,
      chrome: :bare,
      size: :sm
    )
    button = RecordingStudioRootSwitchable::RootSwitch::CompactTrigger.wrapper_class(
      compact: :below_md,
      chrome: :button,
      size: :md
    )

    assert_includes always, "rs-root-switch-compact--bare"
    assert_includes always, "rs-root-switch-compact--always"
    refute_includes always, "[&_button]:px-0"
    assert_includes below, "rs-root-switch-compact--below-md"
    refute_includes below, "max-md:[&_button]:px-0"
    assert_includes button, "rs-root-switch-compact--button"
    assert_includes button, "rs-root-switch-compact--md"
    refute_includes button, "rs-root-switch-compact--bare"
  end

  def test_compact_stylesheet_owns_bare_and_button_rules
    css = File.read(
      File.expand_path(
        "../app/assets/stylesheets/recording_studio_root_switchable.css",
        __dir__
      )
    )

    refute_includes css, "max-md:["
    assert_includes css, ".rs-root-switch-compact--bare.rs-root-switch-compact--always .fp-button-dropdown__trigger"
    assert_includes css, "border-width: 0"
    assert_includes css, "padding: 0"
    assert_includes css, ".rs-root-switch-compact--button.rs-root-switch-compact--always .fp-button-dropdown__trigger"
    assert_includes css, "padding: var(--rs-root-switch-compact-pad)"
    assert_includes css, "width: var(--rs-root-switch-compact-box)"
    assert_includes css, "@media (width < 48rem)"
    assert_includes css, ".rs-root-switch-compact--button.rs-root-switch-compact--below-md .fp-button-dropdown__trigger"
    assert_includes css, ".rs-root-switch-compact--always .rs-root-switch-compact-name"
    assert_includes css, ".rs-root-switch-compact--below-md .rs-root-switch-compact-name"
    assert_includes css, ".fp-button-dropdown__trigger > span.min-w-0"
    assert_includes css, "flex: 0 0 auto"
    assert_includes css, "overflow: visible"
    assert_includes css, "width: var(--rs-root-switch-compact-icon) !important"
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
