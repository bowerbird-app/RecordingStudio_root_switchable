# frozen_string_literal: true

require "test_helper"

class RootSwitchDropdownComponentTest < ViewComponent::TestCase
  test "default trigger keeps the name, truncates it, and omits the compact badge" do
    render_inline(dropdown(compact: nil))
    trigger = trigger_element

    assert_equal "Studio Workspace", trigger["title"]
    assert_nil trigger["aria-label"]
    name = trigger.at_css("span[class*='max-w-[9rem]']")
    assert_equal "Studio Workspace", name.text.strip
    assert_includes name["class"].split, "truncate"
    refute_includes name["class"].split, "hidden"
    assert_nil trigger.at_css("span.md\\:hidden")
    assert_includes rendered_content, "Client Alpha"
  end

  test "below_md renders name and badge spans with aria-label" do
    render_inline(dropdown(compact: :below_md))
    trigger = trigger_element
    name = trigger.at_css("span[class*='max-w-[9rem]']")
    badge = trigger.at_css("span[class*='md:hidden']")

    assert_equal "Studio Workspace", trigger["aria-label"]
    assert_equal "Studio Workspace", trigger["title"]
    assert_equal "Studio Workspace", name.text.strip
    assert_includes name["class"].split, "hidden"
    refute_includes name["class"].split, "inline-block"
    assert_includes name["class"].split, "md:inline-block"
    assert_equal "SW", badge.text.strip
    assert_includes rendered_content, "Client Alpha"
  end

  test "always hides the name and shows the badge" do
    render_inline(dropdown(compact: :always))
    trigger = trigger_element
    name = trigger.at_css("span.hidden")
    badge = trigger.at_css("span.rounded-full")

    assert_equal "Studio Workspace", trigger["aria-label"]
    assert_equal "Studio Workspace", name.text.strip
    refute_includes name["class"].split, "md:inline-block"
    assert_equal "SW", badge.text.strip
    refute badge["class"].split.include?("md:hidden")
  end

  test "none selected compact trigger falls back to an icon" do
    rows = RecordingStudioRootSwitchable::RootSwitch::MenuRows.build(
      entries: [{id: "alpha", label: "Client Alpha"}],
      selected: nil,
      form_action: "/switch",
      return_to: "/placements",
      options: menu_options
    )

    render_inline(
      RecordingStudioRootSwitchable::RootSwitch::DropdownComponent.new(
        menu_rows: rows,
        compact: :always,
        style: :ghost,
        size: :sm
      )
    )
    trigger = trigger_element

    assert_equal "None selected", trigger["aria-label"]
    refute_equal "NS", trigger.at_css("span.rounded-full")&.text&.strip
    assert trigger.at_css("svg[data-flat-pack--icon-name-value='building-office-2']")
  end

  test "emoji name compact trigger falls back to an icon" do
    rows = RecordingStudioRootSwitchable::RootSwitch::MenuRows.build(
      entries: [{id: "spark", label: "🚀"}],
      selected: {id: "spark", label: "🚀"},
      form_action: "/switch",
      return_to: "/placements",
      options: menu_options
    )

    render_inline(
      RecordingStudioRootSwitchable::RootSwitch::DropdownComponent.new(
        menu_rows: rows,
        compact: :always,
        style: :ghost,
        size: :sm
      )
    )
    trigger = trigger_element

    assert_equal "🚀", trigger["aria-label"]
    assert trigger.at_css("svg[data-flat-pack--icon-name-value='building-office-2']")
  end

  test "invalid compact raises" do
    error = assert_raises(ArgumentError) { dropdown(compact: :phone) }

    assert_match(/Invalid compact: :phone/, error.message)
  end

  private

  def trigger_element
    Nokogiri::HTML5.fragment(rendered_content).at_css("[data-flat-pack--button-dropdown-target='trigger']")
  end

  def dropdown(compact:)
    RecordingStudioRootSwitchable::RootSwitch::DropdownComponent.new(
      menu_rows: selected_rows,
      compact: compact,
      style: :ghost,
      size: :sm
    )
  end

  def selected_rows
    RecordingStudioRootSwitchable::RootSwitch::MenuRows.build(
      entries: [
        {id: "studio", label: "Studio Workspace"},
        {id: "alpha", label: "Client Alpha"}
      ],
      selected: {id: "studio", label: "Studio Workspace"},
      form_action: "/switch",
      return_to: "/placements",
      options: menu_options
    )
  end

  def menu_options
    RecordingStudioRootSwitchable::RootSwitch::MenuRows::Options.new(
      none_selected_label: I18n.t("recording_studio.root_switchable.dropdown.none_selected"),
      new_root_path: nil,
      new_root_label: nil,
      new_root_icon: nil
    )
  end
end
