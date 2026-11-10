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
    wrap = trigger.at_css("span[class*='md:hidden']")
    badge = compact_avatar(trigger)

    assert_equal "Studio Workspace", trigger["aria-label"]
    assert_equal "Studio Workspace", trigger["title"]
    assert_equal "Studio Workspace", name.text.strip
    assert_includes name["class"].split, "hidden"
    refute_includes name["class"].split, "inline-block"
    assert_includes name["class"].split, "md:inline-block"
    assert_equal "SW", wrap.text.strip
    assert_includes wrap["class"].split, "md:hidden"
    assert_includes avatar_size_classes(badge), "h-8"
    assert_includes avatar_size_classes(badge), "w-8"
    classes = dropdown_wrapper["class"].to_s
    assert_includes classes, "rs-root-switch-compact--below-md"
    assert_includes classes, "rs-root-switch-compact--bare"
    refute_includes classes, "rs-root-switch-compact--button"
    refute_includes classes, "max-md:[&_button]:px-0"
    refute_includes classes, "max-md:[&_button]:gap-0"
    refute_includes classes, "max-md:[&_button]:min-w-0"
    refute_includes classes, "max-md:[&_[data-flat-pack--button-dropdown-target=chevron]]:hidden"
    refute_includes classes, "max-md:[&_button>span.shrink-0]:hidden"
    assert trigger.at_css("[data-flat-pack--button-dropdown-target='chevron']")
    assert_includes rendered_content, "Client Alpha"
  end

  test "always hides the name and shows the badge" do
    render_inline(dropdown(compact: :always))
    trigger = trigger_element
    name = trigger.at_css("span.hidden")
    badge = compact_avatar(trigger)

    assert_equal "Studio Workspace", trigger["aria-label"]
    assert_equal "Studio Workspace", name.text.strip
    refute_includes name["class"].split, "md:inline-block"
    assert_equal "SW", badge.text.strip
    refute_includes compact_avatar_wrap(trigger)["class"].split, "md:hidden"
    assert_includes avatar_size_classes(badge), "h-8"
    classes = dropdown_wrapper["class"].to_s
    assert_includes classes, "rs-root-switch-compact--always"
    assert_includes classes, "rs-root-switch-compact--bare"
    refute_includes classes, "[&_button]:px-0"
    refute_includes classes, "[&_button]:gap-0"
    refute_includes classes, "[&_button]:min-w-0"
    refute_includes classes, "max-md:[&_button]:px-0"
    assert_nil trigger.at_css("[data-flat-pack--button-dropdown-target='chevron']")
  end

  test "badge_size override uses FlatPack Avatar size classes" do
    render_inline(dropdown(compact: :always, badge_size: :md))
    badge = compact_avatar(trigger_element)

    assert_includes avatar_size_classes(badge), "h-10"
    assert_includes avatar_size_classes(badge), "w-10"
  end

  test "invalid badge_size raises through FlatPack Avatar" do
    error = assert_raises(ArgumentError) { dropdown(compact: :always, badge_size: :phone) }

    assert_match(/Invalid badge_size: :phone/, error.message)
  end

  test "default compact keeps the chevron" do
    render_inline(dropdown(compact: nil))
    trigger = trigger_element

    classes = dropdown_wrapper["class"].to_s
    assert trigger.at_css("[data-flat-pack--button-dropdown-target='chevron']")
    refute_includes classes, "rs-root-switch-compact--below-md"
    refute_includes classes, "rs-root-switch-compact--always"
    refute_includes classes, "max-md:[&_button]:px-0"
    refute_includes classes, "[&_button]:px-0"
    refute_includes classes, "max-md:[&_[data-flat-pack--button-dropdown-target=chevron]]:hidden"
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
    refute_equal "NS", compact_avatar(trigger)&.text&.strip
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

  test "button chrome keeps caller style classes and uses a static compact class" do
    render_inline(dropdown(compact: :below_md, compact_chrome: :button, size: :md, style: :default))
    trigger = trigger_element
    wrap = trigger.at_css("span[class*='md:hidden']")
    badge = compact_avatar(trigger)
    classes = dropdown_wrapper["class"].to_s

    assert_equal "Studio Workspace", trigger["aria-label"]
    assert_equal "Studio Workspace", trigger["title"]
    assert_equal "SW", wrap.text.strip
    assert_includes wrap["class"].split, "rs-root-switch-compact-badge"
    assert_includes avatar_size_classes(badge), "h-10"
    assert_includes avatar_size_classes(badge), "w-10"
    assert_includes classes, "rs-root-switch-compact--button"
    assert_includes classes, "rs-root-switch-compact--md"
    refute_includes classes, "rs-root-switch-compact--bare"
    refute_includes classes, "max-md:[&_button]:border-0"
    assert trigger.at_css("[data-flat-pack--button-dropdown-target='chevron']")
    assert_includes trigger["class"].to_s, "border"
  end

  test "button chrome derives badge size from size and badge_size wins" do
    render_inline(dropdown(compact: :always, compact_chrome: :button, size: :md, style: :default))

    assert_includes avatar_size_classes(compact_avatar(trigger_element)), "h-10"

    render_inline(
      dropdown(compact: :always, compact_chrome: :button, size: :md, style: :default, badge_size: :xs)
    )

    assert_includes avatar_size_classes(compact_avatar(trigger_element)), "h-6"
    refute_includes avatar_size_classes(compact_avatar(trigger_element)), "h-10"
  end

  test "bare chrome output stays the default compact badge wrap" do
    render_inline(dropdown(compact: :below_md, compact_chrome: :bare))
    wrap = trigger_element.at_css("span[class*='md:hidden']")

    refute_includes wrap["class"].split, "rs-root-switch-compact-badge"
    assert_includes avatar_size_classes(compact_avatar(trigger_element)), "h-8"
  end

  test "invalid compact_chrome raises" do
    error = assert_raises(ArgumentError) { dropdown(compact: :always, compact_chrome: :ghost) }

    assert_match(/Invalid compact_chrome: :ghost/, error.message)
  end

  private

  def trigger_element
    Nokogiri::HTML5.fragment(rendered_content).at_css("[data-flat-pack--button-dropdown-target='trigger']")
  end

  def dropdown_wrapper
    Nokogiri::HTML5.fragment(rendered_content).at_css(".fp-button-dropdown")
  end

  def dropdown(compact:, compact_chrome: nil, badge_size: nil, style: :ghost, size: :sm)
    RecordingStudioRootSwitchable::RootSwitch::DropdownComponent.new(
      menu_rows: selected_rows,
      compact: compact,
      compact_chrome: compact_chrome,
      badge_size: badge_size,
      style: style,
      size: size
    )
  end

  def avatar_size_classes(node)
    node["class"].to_s.split
  end

  def compact_avatar(root)
    root.at_css("span[class*='aspect-square']")
  end

  def compact_avatar_wrap(root)
    compact_avatar(root).parent
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
