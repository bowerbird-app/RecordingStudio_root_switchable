# frozen_string_literal: true

require "test_helper"

class HomeNavigationTest < Minitest::Test
  def test_sidebar_includes_switch_log_link
    sidebar = read_dummy_file("app/views/layouts/flat_pack/_sidebar.html.erb")

    assert_includes sidebar, "label: \"Switch log\""
    assert_includes sidebar, "href: \"/switch_log\""
    assert_includes sidebar, "icon: :server_stack"
  end

  def test_sidebar_includes_config_link
    sidebar = read_dummy_file("app/views/layouts/flat_pack/_sidebar.html.erb")

    assert_includes sidebar, "label: \"Config\""
    assert_includes sidebar, "href: \"/config\""
    assert_includes sidebar, "icon: :cog_6_tooth"
  end

  def test_sidebar_includes_gem_views_link
    sidebar = read_dummy_file("app/views/layouts/flat_pack/_sidebar.html.erb")

    assert_includes sidebar, "label: \"Gem views\""
    assert_includes sidebar, "href: \"/gem_views\""
  end

  def test_sidebar_includes_methods_link
    sidebar = read_dummy_file("app/views/layouts/flat_pack/_sidebar.html.erb")

    assert_includes sidebar, "label: \"Method\""
    assert_includes sidebar, "href: \"/method\""
    assert_includes sidebar, "icon: :book_open"
  end

  def test_top_nav_uses_root_switch_dropdown_before_avatar
    top_nav = read_dummy_file("app/views/layouts/flat_pack/_top_nav.html.erb")

    assert_includes top_nav, "recording_studio_root_switch_dropdown(style: :ghost, size: :md)"
    refute_includes top_nav, "FlatPack::Chip::Component.new"

    dropdown_index = top_nav.index("recording_studio_root_switch_dropdown")
    avatar_index = top_nav.index("FlatPack::Avatar::Component.new")

    refute_nil dropdown_index
    refute_nil avatar_index
    assert_operator dropdown_index, :<, avatar_index
  end

  def test_setup_page_no_longer_contains_configuration_example
    setup_view = read_dummy_file("app/views/home/setup.html.erb")

    refute_includes setup_view, "RecordingStudioRootSwitchable.configure do |config|"
    assert_includes setup_view, "bin/rails generate recording_studio_root_switchable:install"
  end

  def test_config_page_contains_documented_configuration_example
    config_view = read_dummy_file("app/views/home/config.html.erb")

    assert_includes config_view, "title: \"Config\""
    assert_includes config_view, "RecordingStudioRootSwitchable.configure do |config|"
    assert_includes config_view, "current_actor_resolver tells the gem which actor to use for root lookup"
    assert_includes config_view, "config.layout = :application_layout"
    assert_includes config_view, "default_root chooses the initial selection when the device has no saved root yet"
  end

  def test_dummy_app_registers_config_page_route_and_action
    routes = read_dummy_file("config/routes.rb")
    controller = read_dummy_file("app/controllers/home_controller.rb")

    assert_includes routes, "get \"config\", to: \"home#configuration\""
    assert_includes controller, "def configuration"
  end

  def test_dummy_app_registers_switch_log_page_route_and_action
    routes = read_dummy_file("config/routes.rb")
    controller = read_dummy_file("app/controllers/home_controller.rb")
    view = read_dummy_file("app/views/home/switch_log.html.erb")

    assert_includes routes, "get \"switch_log\", to: \"home#switch_log\""
    assert_includes routes, "get \"persistence\", to: redirect(\"/switch_log\")"
    assert_includes controller, "def switch_log"
    assert_includes controller, "@saved_sessions = RecordingStudio::RootSwitchable::Selection"
    assert_includes controller, "def saved_session_device_context"
    assert_includes controller, "def saved_session_device_key"
    assert_includes view, "title: \"Switch log\""
    assert_includes view, "Workspace name"
    assert_includes view, "Device"
    assert_includes view, "Device key"
    assert_includes view, "Timestamp"
    assert_includes view, "saved_session_device_context(selection)"
    assert_includes view, "saved_session_device_key(selection)"
    assert_includes view, "@saved_sessions.each do |selection|"
  end

  def test_persistence_redirect_points_to_switch_log_page
    routes = read_dummy_file("config/routes.rb")
    view = read_dummy_file("app/views/home/switch_log.html.erb")

    assert_includes routes, "get \"persistence\", to: redirect(\"/switch_log\")"
    assert_includes view, "title: \"Switch log\""
    assert_includes view, "No saved workspace sessions have been recorded yet."
  end

  def test_methods_page_uses_flatpack_sections_and_code_blocks
    routes = read_dummy_file("config/routes.rb")
    controller = read_dummy_file("app/controllers/home_controller.rb")
    view = read_dummy_file("app/views/home/methods.html.erb")

    assert_includes routes, "get \"method\", to: \"home#method_docs\""
    assert_includes controller, "def method_docs"
    assert_includes controller, "def documented_methods"
    assert_includes controller, "code: <<~'CODE'"
    assert_includes controller, 'Rails.logger.info("Active root scope: #{scope_key}")'
    assert_includes view, "title: \"Method\""
    assert_includes view, "FlatPack::SectionTitle::Component.new"
    assert_includes view, "anchor_link: true"
    assert_includes view, "FlatPack::CodeBlock::Component.new"
    assert_includes view, "method.fetch(:signature)"
    assert_includes view, "method.fetch(:code)"
  end

  def test_home_index_shows_switchability_table_with_available_and_unavailable_states
    view = read_dummy_file("app/views/home/index.html.erb")
    controller = read_dummy_file("app/controllers/home_controller.rb")
    initializer = read_dummy_file("config/initializers/recording_studio_root_switchable.rb")

    assert_includes view, "title: \"Accessible root switchability\""
    assert_includes view, "switchable_root_types for all_roots"
    assert_includes view, "<table class=\"min-w-full divide-y divide-(--table-border-color)\">"
    assert_includes view, "Root name"
    assert_includes view, "Root type"
    assert_includes view, "Switchable"
    assert_includes view, "Details"
    assert_includes view, "✅"
    assert_includes view, "❌"
    assert_includes view, "row.fetch(:reason)"

    assert_includes controller, "@accessible_root_switchability_rows = accessible_root_switchability_rows"
    assert_includes controller, "Included in switchable_root_types"
    assert_includes controller, "is excluded by switchable_root_types"

    assert_includes initializer, "config.scope :all_roots do |scope|"
    assert_includes initializer, "scope.switchable_root_types = [ \"Workspace\", \"Page\" ]"
    assert_includes initializer, "excluded by switchable_root_types"
    refute_includes initializer, "scope.page_copy"
  end

  def test_gem_views_page_lists_engine_templates
    routes = read_dummy_file("config/routes.rb")
    controller = read_dummy_file("app/controllers/home_controller.rb")
    view = read_dummy_file("app/views/home/gem_views.html.erb")
    detail_view = read_dummy_file("app/views/home/gem_view.html.erb")

    assert_includes routes, "get \"gem_views\", to: \"home#gem_views\""
    assert_includes routes, "get \"gem_views/*view_path\", to: \"home#gem_view\", as: :gem_view"
    assert_includes controller, "def gem_views"
    assert_includes controller, "def gem_view"
    assert_includes controller, "GEM_VIEWS_ROOT = RecordingStudioRootSwitchable::Engine.root.join(\"app/views\").freeze"
    assert_includes controller, "href: gem_view_path(relative_path)"
    assert_includes view, "title: \"Gem views\""
    assert_includes view, "FlatPack::List::Component.new"
    assert_includes view, "FlatPack::List::Item.new(href: view.fetch(:href), hover: true)"
    assert_includes detail_view, "FlatPack::CodeBlock::Component.new"
    assert_includes detail_view, "back_href: \"/gem_views\""
  end

  private

  def read_dummy_file(relative_path)
    File.read(File.expand_path("dummy/#{relative_path}", __dir__))
  end
end
