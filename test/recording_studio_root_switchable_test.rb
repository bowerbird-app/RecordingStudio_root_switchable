# frozen_string_literal: true

require "test_helper"
require "action_controller/railtie"
require File.join(
  Gem.loaded_specs.fetch("recording_studio").full_gem_path,
  "app/helpers/recording_studio/layout_helper"
)
require_relative "../app/controllers/recording_studio_root_switchable/application_controller"
require_relative "../app/controllers/recording_studio_root_switchable/root_switches_controller"

class RecordingStudioRootSwitchableTest < Minitest::Test
  def test_version_exists
    refute_nil RecordingStudioRootSwitchable::VERSION
  end

  def test_root_switch_controller_uses_recording_studio_layout
    assert_equal :recording_studio_resolved_layout,
                 RecordingStudioRootSwitchable::RootSwitchesController.send(:_layout)
  end

  def test_engine_exists
    assert_kind_of Class, RecordingStudioRootSwitchable::Engine
  end

  def test_public_current_helpers_are_exposed
    RecordingStudio::RootSwitchable::Current.scope_key = "roots"
    RecordingStudio::RootSwitchable::Current.root = :example_root

    assert_equal "roots", RecordingStudio::RootSwitchable.current_root_scope_key
    assert_equal :example_root, RecordingStudio::RootSwitchable::Current.root
  ensure
    RecordingStudio::RootSwitchable::Current.reset
  end

  def test_dummy_app_schema_includes_root_switchable_selection_table
    schema_path = File.expand_path("dummy/db/schema.rb", __dir__)
    schema_source = File.read(schema_path)

    assert_includes schema_source, 'create_table "recording_studio_root_switchable_selections"'
    assert_includes schema_source, 't.string "actor_id"'
    assert_includes schema_source, 't.datetime "last_used_at", null: false'
  end

  def test_dummy_app_documents_root_switch_demo_routes
    dummy_readme_path = File.expand_path("dummy/README.md", __dir__)
    dummy_readme_source = File.read(dummy_readme_path)

    assert_includes dummy_readme_source, "/recording_studio_root_switchable/v1/root_switch?scope=all_workspaces"
    assert_includes dummy_readme_source, "per-device persistence"
  end

  def test_dummy_app_includes_root_switchable_migration
    migration_files = Dir.glob(File.expand_path("dummy/db/migrate/*root_switchable*selection*.rb", __dir__))

    refute_empty migration_files
  end

  def test_dummy_app_initializer_leaves_layout_unset
    initializer_path = File.expand_path("dummy/config/initializers/recording_studio_root_switchable.rb", __dir__)
    initializer_source = File.read(initializer_path)

    refute_includes initializer_source, "config.layout ="
  end

  def test_dummy_accessible_initializer_registers_access_capability_for_recording_studio_v3
    initializer_path = File.expand_path("dummy/config/initializers/recording_studio_accessible.rb", __dir__)
    initializer_source = File.read(initializer_path)

    assert_includes initializer_source, "RecordingStudio.register_capability("
    assert_includes initializer_source, 'child_recordables: [ "RecordingStudio::Access" ]'
  end

  def test_gemspec_targets_recording_studio_6_1_and_accessible_0_18
    gemspec_path = File.expand_path("../recording_studio_root_switchable.gemspec", __dir__)
    gemspec_source = File.read(gemspec_path)

    assert_includes gemspec_source, 'spec.add_dependency "recording_studio", ">= 6.1.0"'
    assert_includes gemspec_source, 'spec.add_dependency "recording_studio_accessible", "~> 0.18"'
    assert_includes gemspec_source, 'spec.add_dependency "recording_studio_cache", "~> 0.5"'
    assert_includes gemspec_source, 'spec.add_dependency "recording_studio_metrics", ">= 0.3.0", "< 1.0"'
    assert_includes gemspec_source, 'spec.add_dependency "flat_pack", ">= 0.1.315"'
    assert_includes gemspec_source, 'spec.add_dependency "view_component", ">= 4.14", "< 5"'
  end

  def test_development_pins_flat_pack_0_1_329_and_recording_studio_6_3
    root = File.expand_path("..", __dir__)

    [File.join(root, "Gemfile"), File.join(root, "test/dummy/Gemfile")].each do |gemfile|
      source = File.read(gemfile)

      refute_includes source, "widen_recording_studio_requirement"
      assert_includes source, 'tag: "v0.1.329"'
      assert_includes source, 'tag: "v6.3.0"'
      assert_includes source, 'tag: "v0.23.1"'
      assert_includes source, 'tag: "v0.6.0"'
      assert_includes source, 'tag: "v0.7.0"'
      assert_includes source, 'tag: "v0.12.0"'
      assert_includes source, 'gem "view_component", "4.19.0"'
    end

    refute File.exist?(File.join(root, "test/support/widen_recording_studio_requirement.rb"))

    %w[Gemfile.lock test/dummy/Gemfile.lock].each do |relative|
      lock = File.read(File.join(root, relative))

      assert_includes lock, "flat_pack (0.1.329)", relative
      assert_includes lock, "recording_studio (6.3.0)", relative
      assert_includes lock, "recording_studio_accessible (0.23.1)", relative
      assert_includes lock, "recording_studio_cache (0.6.0)", relative
      assert_includes lock, "recording_studio_metrics (0.7.0)", relative
      assert_includes lock, "recording_studio_trashable (0.12.0)", relative
      assert_includes lock, "view_component (4.19.0)", relative
      assert_includes lock, "crass (1.0.8)", relative
    end
  end

  def test_dummy_layouts_load_flatpack_stylesheets_before_tailwind
    root = File.expand_path("dummy/app/views/layouts", __dir__)

    ["application.html.erb", "flat_pack_sidebar.html.erb"].each do |name|
      source = File.read(File.join(root, name))
      flat_pack = source.index('stylesheet_link_tag "flat_pack/variables"')
      tailwind = source.index('stylesheet_link_tag "tailwind"')

      refute_nil flat_pack, name
      refute_nil tailwind, name
      assert_operator flat_pack, :<, tailwind, name
      assert_operator source.index('stylesheet_link_tag "flat_pack/application"'), :<, tailwind, name
      assert_operator source.index('stylesheet_link_tag "flat_pack/rich_text"'), :<, tailwind, name
    end
  end

  def test_root_switch_view_uses_page_nav_and_list_based_selector_without_item_subtitles
    view_path = File.expand_path("../app/views/recording_studio_root_switchable/root_switches/show.html.erb", __dir__)
    view_source = File.read(view_path)

    assert_includes view_source, "flat_pack_page_nav("
    assert_includes view_source, "round: true"
    assert_includes view_source, "style: :default"
    assert_includes view_source, "anchor_href: @return_anchor_url"
    assert_includes view_source, 't("recording_studio.root_switchable.navigation.close", default: "Close")'
    refute_includes view_source, "anchor_label:"
    refute_includes view_source, "FlatPack::PageNav::Component"
    refute_includes view_source, "FlatPack::PageTitle::Component"
    refute_includes view_source, "FlatPack::Breadcrumb::Component"
    assert_includes view_source, 'class="flex w-full flex-col gap-6"'
    refute_includes view_source, "max-w-3xl"
    assert_includes view_source, "register_page_nav(@new_root_label, @new_root_path, role: :primary, icon: @new_root_icon)"
    rows_source = File.read(
      File.expand_path(
        "../app/components/recording_studio_root_switchable/root_switch/rows_component.html.erb",
        __dir__
      )
    )
    assert_includes rows_source, "FlatPack::Shared::IconComponent.new(name: menu_rows.new_root_icon.to_s, size: :sm)"
    assert_includes rows_source, "if menu_rows.new_root_icon.present?"
    refute_includes rows_source, 'aria-hidden="true">+</span>'
    assert_includes view_source, "content_for :title, @page_copy.fetch(:title)"
    assert_includes view_source, "content_for :subtitle, page_subtitle if page_subtitle"
    assert_includes view_source, "@page_copy.fetch(:subtitle).presence"
    assert_includes view_source, "@page_copy.fetch(:persistence_hint).presence"
    refute_includes view_source, "<p class=\"text-sm text-(--surface-muted-content-color)\"><%= @page_copy.fetch(:persistence_hint) %></p>"
    assert_includes view_source, "FlatPack::Card::Component"
    card_call = view_source[/FlatPack::Card::Component\.new\(.*?\) do/m]
    assert_includes card_call, "background: :default"
    assert_includes card_call, "border: :default"
    assert_includes card_call, "shadow: :none"
    refute_includes card_call, "style:"
    assert_includes view_source, "card.body do"
    assert_includes view_source, "FlatPack::List::Component"
    assert_includes view_source, "FlatPack::List::Item.new"
    assert_includes view_source, "hover: true"
    assert_includes view_source, "form_with url: root_switch_path(scope: @scope.key), method: :patch, local: true"
    assert_includes view_source, 'hidden_field_tag "root_switch[return_to]", @safe_return_to'
    assert_includes view_source, "FlatPack::Button::Component"
    assert_includes view_source, "text: @page_copy.fetch(:switch_action_label)"
    assert_includes view_source, "style: :default"
    assert_includes view_source, 'div class="font-semibold"'
    refute_includes view_source, "active: selected"
    refute_includes view_source, "divider: true"
    refute_includes view_source, "@scope.root_description_for"
    refute_includes view_source, "turbo_method: :patch"
    refute_includes view_source, "@supported_scopes.each"
  end

  def test_root_switch_view_leaves_flash_and_the_heading_to_the_layout
    view_path = File.expand_path("../app/views/recording_studio_root_switchable/root_switches/show.html.erb", __dir__)
    view_source = File.read(view_path)

    refute_includes view_source, "flash[:notice]"
    refute_includes view_source, "flash[:alert]"
    refute_includes view_source, "FlatPack::PageTitle::Component"
  end

  def test_root_switch_dropdown_does_not_ship_a_stimulus_controller
    refute File.exist?(
      File.expand_path(
        "../app/javascript/recording_studio_root_switchable/controllers/root_switch_dropdown_controller.js",
        __dir__
      )
    )
    refute File.exist?(
      File.expand_path("../app/views/recording_studio_root_switchable/_root_switch_dropdown.html.erb", __dir__)
    )
    refute File.exist?(File.expand_path("../config/importmap.rb", __dir__))

    component_source = File.read(
      File.expand_path(
        "../app/components/recording_studio_root_switchable/root_switch/dropdown_component.rb",
        __dir__
      )
    )
    assert_includes component_source, "def menu_row"
    assert_includes component_source, "ListComponent.new"
  end

  def test_root_switch_helper_uses_i18n_for_none_selected_label
    helper_path = File.expand_path(
      "../app/helpers/recording_studio_root_switchable/root_switch_helper.rb",
      __dir__
    )
    helper_source = File.read(helper_path)

    assert_includes helper_source, 't("recording_studio.root_switchable.dropdown.none_selected")'
    refute_includes helper_source, '"None selected"'
    assert_includes helper_source, "def recording_studio_new_root_path"
    assert_includes helper_source, "def recording_studio_root_switch_for"
    assert_includes helper_source, "def recording_studio_root_switch_list_for"
    assert_includes helper_source, "def render_recording_studio_root_switch_list"
    assert_includes helper_source, "new_root_icon: nil"
  end
end
