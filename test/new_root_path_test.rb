# frozen_string_literal: true

require "test_helper"
require_relative "../app/components/recording_studio_root_switchable/root_switch/menu_rows"
require_relative "../app/components/recording_studio_root_switchable/root_switch/context"
require_relative "../app/helpers/recording_studio_root_switchable/root_switch_helper"

class NewRootPathTest < Minitest::Test
  Recordable = Struct.new(:name)
  Recording = Struct.new(:id, :recordable)
  Resolution = Struct.new(:scope, :available_roots, :root_recording, keyword_init: true)

  def setup
    @scope = RecordingStudio::RootSwitchable::ScopeDefinition.new(:workspaces)
    @actor = Object.new
  end

  def test_path_defaults_to_nil
    assert_nil @scope.new_root_path_for(actor: @actor, return_to: "/back")
  end

  def test_string_path_appends_a_safe_return_to
    @scope.new_root_path = "/workspaces/new"

    assert_equal "/workspaces/new?return_to=%2Fback", @scope.new_root_path_for(actor: @actor, return_to: "/back")
  end

  def test_callable_returns_a_path_when_the_actor_is_allowed
    @scope.new_root_path = lambda do |actor:, **|
      actor.equal?(@actor) ? "/workspaces/new" : nil
    end

    assert_equal "/workspaces/new", @scope.new_root_path_for(actor: @actor)
  end

  def test_callable_nil_or_false_hides_the_path
    @scope.new_root_path = ->(**) { false }
    assert_nil @scope.new_root_path_for(actor: @actor)

    @scope.new_root_path = ->(**) {}
    assert_nil @scope.new_root_path_for(actor: @actor)
  end

  def test_unsafe_paths_are_dropped
    ["javascript:alert(1)", "https://evil.example/phish", "//evil.example/phish"].each do |path|
      @scope.new_root_path = path

      assert_nil @scope.new_root_path_for(actor: @actor), path
    end
  end

  def test_hook_errors_hide_the_path
    @scope.new_root_path = ->(**) { raise "nope" }

    assert_nil @scope.new_root_path_for(actor: @actor)
  end

  def test_an_existing_return_to_is_kept
    @scope.new_root_path = "/workspaces/new?return_to=%2Fstay"

    assert_equal "/workspaces/new?return_to=%2Fstay", @scope.new_root_path_for(actor: @actor, return_to: "/other")
  end

  def test_label_uses_the_hook_then_page_copy_then_english
    assert_equal "New workspace", @scope.new_root_label_for

    @scope.new_root_label = "Create"
    assert_equal "Create", @scope.new_root_label_for

    @scope.new_root_label = ->(**) { "Add" }
    assert_equal "Add", @scope.new_root_label_for

    @scope.new_root_label = nil
    @scope.page_copy = { new_root_action_label: "From copy" }
    assert_equal "From copy", @scope.new_root_label_for(fallback: "Fallback")
  end

  def test_menu_stays_open_when_the_only_offer_is_a_new_root
    rows = build_menu(entries: [], selected: nil, new_root_path: "/workspaces/new", new_root_label: "New workspace")

    assert_equal "/workspaces/new", rows.new_root_path
    assert_equal "New workspace", rows.new_root_label
    assert_empty rows.switch_rows
  end

  def test_one_current_workspace_keeps_the_new_root_offer
    rows = build_menu(
      entries: [{ id: "studio", label: "Studio" }],
      selected: { id: "studio", label: "Studio" },
      new_root_path: "/workspaces/new"
    )

    assert_empty rows.switch_rows
    assert_equal "/workspaces/new", rows.new_root_path
    assert_equal "New workspace", rows.new_root_label
  end

  def test_unsafe_new_root_path_does_not_invent_a_menu
    assert_nil build_menu(entries: [], selected: nil, new_root_path: "javascript:alert(1)")
  end

  def test_false_override_hides_a_configured_path
    @scope.new_root_path = "/workspaces/new"
    rows = context_rows(new_root_path: false)

    assert_nil rows.new_root_path
  end

  def test_string_override_replaces_the_scope_path
    @scope.new_root_path = "/other"
    rows = context_rows(new_root_path: "/workspaces/new")

    assert_equal "/workspaces/new?return_to=%2Fhere", rows.new_root_path
    assert_equal "New workspace", rows.new_root_label
  end

  def test_helper_resolves_the_given_scope
    @scope.new_root_path = "/workspaces/new"
    host = Object.new
    host.extend(RecordingStudioRootSwitchable::RootSwitchHelper)
    controller = Object.new
    controller.define_singleton_method(:current_root_recording) { nil }
    controller.define_singleton_method(:current_root_device_key) { "device" }
    request = Struct.new(:fullpath).new("/placements")
    host.define_singleton_method(:controller) { controller }
    host.define_singleton_method(:request) { request }
    RecordingStudio::RootSwitchable::Current.actor = @actor

    assert_equal(
      "/workspaces/new?return_to=%2Ffrom-helper",
      host.recording_studio_new_root_path(scope: @scope, return_to: "/from-helper")
    )
  ensure
    RecordingStudio::RootSwitchable::Current.reset
  end

  private

  def build_menu(entries:, selected:, new_root_path:, new_root_label: nil)
    RecordingStudioRootSwitchable::RootSwitch::MenuRows.build(
      entries: entries,
      selected: selected,
      form_action: "/switch",
      return_to: "/here",
      options: RecordingStudioRootSwitchable::RootSwitch::MenuRows::Options.new(
        none_selected_label: "None selected",
        new_root_path: new_root_path,
        new_root_label: new_root_label
      )
    )
  end

  def context_rows(new_root_path:)
    recording = Recording.new("studio", Recordable.new("Studio"))
    resolution = Resolution.new(scope: @scope, available_roots: [recording], root_recording: recording)
    controller = Object.new
    controller.define_singleton_method(:current_root_resolution) { resolution }
    controller.define_singleton_method(:current_root_device_key) { "device" }

    RecordingStudioRootSwitchable::RootSwitch::Context.new(
      controller: controller,
      return_to: "/here",
      form_action_for: ->(scope) { "/switch?scope=#{scope.key}" },
      none_selected_label: "None selected",
      new_root: RecordingStudioRootSwitchable::RootSwitch::MenuRows::Override.from(new_root_path, nil)
    ).menu_rows
  end
end
