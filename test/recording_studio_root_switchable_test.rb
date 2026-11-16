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
    assert_equal "0.16.0", RecordingStudioRootSwitchable::VERSION
  end

  def test_root_switch_controller_uses_recording_studio_layout
    assert_equal :recording_studio_resolved_layout,
                 RecordingStudioRootSwitchable::RootSwitchesController.send(:_layout)

    controller_source = File.read(
      File.expand_path("../app/controllers/recording_studio_root_switchable/application_controller.rb", __dir__)
    )
    assert_includes controller_source, "recording_studio_layout { RecordingStudioRootSwitchable.configuration.layout }"
    refute_includes controller_source, 'layout "'
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

  def test_dummy_recording_studio_initializer_sets_authorize_write_for_core_7
    initializer_path = File.expand_path("dummy/config/initializers/recording_studio.rb", __dir__)
    initializer_source = File.read(initializer_path)

    assert_includes initializer_source, "config.authorize_write"
    assert_includes initializer_source, "RecordingStudioAccessible.authorized?"
    assert_includes initializer_source, "AccessCreationContext.allowed?"
    assert_includes initializer_source, "RecordingStudio.root_allowed?(recordable)"
    assert_includes initializer_source, "context[:recording].nil?"
    assert_includes initializer_source, "context[:parent_recording].nil?"
    refute_includes initializer_source, "allow_unauthorized_writes"
    refute_includes initializer_source, "recordable.actor == actor"
    refute_match(/authorize_write\s*=\s*->\(actor:, \*\*\) \{ actor\.is_a\?\(User\) && actor\.persisted\? \}/, initializer_source)
    refute_match(/authorize_write\s*=\s*->\(actor:, \*\*\) \{ actor\.present\? \}/, initializer_source)
  end

  def test_dummy_seeds_create_roots_and_bootstrap_owner_access
    seeds_path = File.expand_path("dummy/db/seeds.rb", __dir__)
    seeds_source = File.read(seeds_path)

    assert_includes seeds_source, "create_root_recording!(workspace, actor: admin)"
    assert_includes seeds_source, "create_root_recording!(team, actor: admin)"
    assert_includes seeds_source, "create_root_recording!(message_root, actor: admin)"
    refute_includes seeds_source, "root_recording_for"
    assert_includes seeds_source, "bootstrap_owner_access!"
    assert_includes seeds_source, "grant_access"
    refute_includes seeds_source, "previous_authorize_write"
    refute_includes seeds_source, "configuration.authorize_write ="
  end

  def test_root_recording_lookups_stay_find_only
    root = File.expand_path("dummy", __dir__)
    lookups = [
      "app/controllers/home_controller.rb",
      "config/initializers/recording_studio_root_switchable.rb",
      "test/integration/new_root_flow_test.rb",
      "test/integration/root_switch_demo_test.rb",
      "test/integration/root_switch_placements_test.rb",
      "test/models/root_selections_metrics_test.rb"
    ]

    lookups.each do |relative|
      source = File.read(File.join(root, relative))

      assert_includes source, "root_recording_for", relative
      refute_includes source, "create_root_recording!", relative
    end

    scope = File.read(File.expand_path("../lib/recording_studio/root_switchable/scope_definition.rb", __dir__))

    refute_includes scope, "RecordingStudio.root_recording_for"
    refute_includes scope, "create_root_recording!"
    assert_includes scope, "def find_existing_root_recording_for(recordable)"
  end

  def test_dummy_accessible_initializer_registers_access_capability_for_recording_studio_v3
    initializer_path = File.expand_path("dummy/config/initializers/recording_studio_accessible.rb", __dir__)
    initializer_source = File.read(initializer_path)

    assert_includes initializer_source, "RecordingStudio.register_capability("
    assert_includes initializer_source, 'child_recordables: [ "RecordingStudio::Access" ]'
  end

  def test_gemspec_requires_recording_studio_7_and_open_addon_ranges
    gemspec_path = File.expand_path("../recording_studio_root_switchable.gemspec", __dir__)
    gemspec_source = File.read(gemspec_path)

    assert_includes gemspec_source, 'spec.add_dependency "recording_studio", ">= 7.0", "< 8.0"'
    assert_includes gemspec_source, 'spec.add_dependency "recording_studio_accessible", ">= 0.44.0", "< 1.0"'
    assert_includes gemspec_source, 'spec.add_dependency "recording_studio_cache", ">= 0.5", "< 1.0"'
    assert_includes gemspec_source, 'spec.add_dependency "recording_studio_metrics", ">= 0.9.0", "< 1.0"'
    assert_includes gemspec_source, 'spec.add_dependency "flat_pack", ">= 0.1.341"'
    assert_includes gemspec_source, 'spec.add_dependency "view_component", ">= 4.14", "< 5"'
  end

  def test_development_pins_recording_studio_7_and_core_7_addons
    root = File.expand_path("..", __dir__)

    {
      File.join(root, "Gemfile") => {
        flat_pack: "v0.1.356",
        recording_studio: "v7.0.0",
        accessible: "v0.44.0",
        cache: "v0.6.3",
        trashable: "v0.17.0"
      },
      File.join(root, "test/dummy/Gemfile") => {
        flat_pack: "v0.1.377",
        recording_studio: "v7.3.0",
        accessible: "v0.45.1",
        cache: "v0.7.0",
        trashable: "v1.0.1"
      }
    }.each do |gemfile, pins|
      source = File.read(gemfile)

      refute_includes source, "widen_recording_studio_requirement"
      assert_includes source, %(tag: "#{pins[:flat_pack]}")
      assert_includes source, %(tag: "#{pins[:recording_studio]}")
      assert_includes source, %(tag: "#{pins[:accessible]}")
      assert_includes source, %(tag: "#{pins[:cache]}")
      assert_includes source, 'tag: "v0.9.0"'
      assert_includes source, %(tag: "#{pins[:trashable]}")
      assert_includes source, 'gem "view_component", "4.19.0"'
    end

    refute File.exist?(File.join(root, "test/support/widen_recording_studio_requirement.rb"))

    {
      "Gemfile.lock" => {
        flat_pack: "0.1.356",
        recording_studio: "7.0.0",
        accessible: "0.44.0",
        cache: "0.6.3",
        trashable: "0.17.0"
      },
      "test/dummy/Gemfile.lock" => {
        flat_pack: "0.1.377",
        recording_studio: "7.3.0",
        accessible: "0.45.1",
        cache: "0.7.0",
        trashable: "1.0.1"
      }
    }.each do |relative, pins|
      lock = File.read(File.join(root, relative))

      assert_includes lock, "flat_pack (#{pins[:flat_pack]})", relative
      assert_includes lock, "recording_studio (#{pins[:recording_studio]})", relative
      assert_includes lock, "recording_studio_accessible (#{pins[:accessible]})", relative
      assert_includes lock, "recording_studio_cache (#{pins[:cache]})", relative
      assert_includes lock, "recording_studio_metrics (0.9.0)", relative
      assert_includes lock, "recording_studio_trashable (#{pins[:trashable]})", relative
      assert_includes lock, "view_component (4.19.0)", relative
      assert_includes lock, "crass (1.0.8)", relative
      assert_includes lock, "recording_studio_root_switchable (0.16.0)", relative
      assert_includes lock, "rails (8.1.4.1)", relative
      assert_includes lock, "flat_pack (>= 0.1.341)", relative
      assert_includes lock, "recording_studio (>= 7.0, < 8.0)", relative
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
      gem_sheet = source.index('stylesheet_link_tag "recording_studio_root_switchable"')
      refute_nil gem_sheet, name
      assert_operator tailwind, :<, gem_sheet, name
    end
  end

  def test_root_switch_view_uses_page_nav_and_list_based_selector_without_item_subtitles
    view_path = File.expand_path("../app/views/recording_studio_root_switchable/root_switches/show.html.erb", __dir__)
    view_source = File.read(view_path)

    assert_includes view_source, "flat_pack_page_nav(round: true, style: :default) do |nav|"
    refute_includes view_source, "nav.with_back"
    assert_includes view_source, "if @return_anchor_url.present?"
    assert_includes view_source, "nav.with_close("
    assert_includes view_source, "href: @return_anchor_url"
    assert_includes view_source, "tooltip: t(\"recording_studio.root_switchable.navigation.close\", default: \"Close\")"
    refute_includes view_source, "anchor_href:"
    refute_includes view_source, "anchor_tooltip:"
    refute_includes view_source, "anchor_label:"
    refute_includes view_source, "back_label:"
    refute_includes view_source, "back_icon:"
    refute_includes view_source, "recording_studio_page_nav"
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
    assert_includes rows_source, "NewRootLabelComponent.new("
    label_source = File.read(
      File.expand_path(
        "../app/components/recording_studio_root_switchable/root_switch/new_root_label_component.rb",
        __dir__
      )
    )
    assert_includes label_source, "FlatPack::Shared::IconComponent.new(name: icon.to_s, size: :sm)"
    assert_includes label_source, "return if icon.blank?"
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
    assert_includes helper_source, "compact: nil"
    assert_includes helper_source, "compact_chrome: nil"
    assert_includes helper_source, "badge_size: nil"
    assert_includes helper_source, "def recording_studio_root_switch_list_for"
    assert_includes helper_source, "def render_recording_studio_root_switch_list"
    assert_includes helper_source, "new_root_icon: nil"
  end

  def test_dummy_bundler_audit_has_no_ignores
    config = File.read(File.expand_path("dummy/config/bundler-audit.yml", __dir__))

    refute_match(/^\s*-\s+\S+/, config)
    assert_match(/ignore:\s*\[\]/, config)
  end
end
