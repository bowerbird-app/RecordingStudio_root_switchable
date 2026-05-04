# frozen_string_literal: true

require "test_helper"
require "action_controller/railtie"
require_relative "../app/controllers/recording_studio_root_switchable/application_controller"
require_relative "../app/controllers/recording_studio_root_switchable/root_switches_controller"

class RecordingStudioRootSwitchableTest < Minitest::Test
  def test_version_exists
    refute_nil RecordingStudioRootSwitchable::VERSION
  end

  def test_root_switch_controller_uses_runtime_layout_resolution
    assert_equal :resolved_layout, RecordingStudioRootSwitchable::RootSwitchesController.send(:_layout)
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

  def test_dummy_app_initializer_uses_gem_blank_layout_by_default
    initializer_path = File.expand_path("dummy/config/initializers/recording_studio_root_switchable.rb", __dir__)
    initializer_source = File.read(initializer_path)

    refute_includes initializer_source, "config.layout ="
  end

  def test_gem_ships_blank_layout_template
    layout_path = File.expand_path("../app/views/layouts/recording_studio_root_switchable/blank.html.erb", __dir__)
    layout_source = File.read(layout_path)

    assert_includes layout_source, "csrf_meta_tags"
    assert_includes layout_source, "csp_meta_tag"
    assert_includes layout_source, 'stylesheet_link_tag "application"'
    assert_includes layout_source, 'stylesheet_link_tag "flat_pack/variables"'
    assert_includes layout_source, 'stylesheet_link_tag "flat_pack/application"'
    assert_includes layout_source, 'stylesheet_link_tag "tailwind"'
    assert_includes layout_source, "javascript_importmap_tags"
    assert_includes layout_source, 'render "layouts/icon_sprite"'
    assert_includes layout_source, "yield"
  end

  def test_root_switch_view_uses_breadcrumb_and_list_based_selector_without_item_subtitles
    view_path = File.expand_path("../app/views/recording_studio_root_switchable/root_switches/show.html.erb", __dir__)
    view_source = File.read(view_path)

    assert_includes view_source, "FlatPack::Breadcrumb::Component"
    assert_includes view_source, "FlatPack::PageTitle::Component"
    assert_includes view_source, 'title: "Change #{@root_type_label}"'
    assert_includes view_source, "FlatPack::Card::Component"
    assert_includes view_source, "card.body do"
    assert_includes view_source, "FlatPack::List::Component"
    assert_includes view_source, "FlatPack::List::Item.new"
    assert_includes view_source, "hover: true"
    assert_includes view_source, "form_with url: root_switch_path(scope: @scope.key), method: :patch, local: true"
    assert_includes view_source, 'hidden_field_tag "root_switch[return_to]", params[:return_to]'
    assert_includes view_source, "FlatPack::Button::Component"
    assert_includes view_source, 'text: "Change"'
    assert_includes view_source, "style: :default"
    assert_includes view_source, 'div class="font-semibold"'
    refute_includes view_source, "active: selected"
    refute_includes view_source, "divider: true"
    refute_includes view_source, "@scope.root_description_for"
    refute_includes view_source, "text-(--surface-muted-content-color)"
    refute_includes view_source, "turbo_method: :patch"
    refute_includes view_source, "@supported_scopes.each"
  end

  def test_root_switch_view_renders_flash_before_breadcrumbs_and_title
    view_path = File.expand_path("../app/views/recording_studio_root_switchable/root_switches/show.html.erb", __dir__)
    view_source = File.read(view_path)

    notice_index = view_source.index("flash[:notice]")
    breadcrumb_index = view_source.index("FlatPack::Breadcrumb::Component")
    title_index = view_source.index("FlatPack::PageTitle::Component")

    refute_nil notice_index
    refute_nil breadcrumb_index
    refute_nil title_index
    assert_operator notice_index, :<, breadcrumb_index
    assert_operator notice_index, :<, title_index
  end
end
