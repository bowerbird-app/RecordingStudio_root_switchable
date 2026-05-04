# frozen_string_literal: true

require "test_helper"

class HomeNavigationTest < Minitest::Test
  def test_sidebar_includes_switch_log_link
    sidebar = File.read(File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html", __dir__) + ".erb")

    assert_includes sidebar, 'label: "Switch log"'
    assert_includes sidebar, 'href: "/switch_log"'
    assert_includes sidebar, 'icon: :server_stack'
  end

  def test_sidebar_includes_config_link
    sidebar = File.read(File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html", __dir__) + ".erb")

    assert_includes sidebar, 'label: "Config"'
    assert_includes sidebar, 'href: "/config"'
    assert_includes sidebar, 'icon: :cog_6_tooth'
  end

  def test_sidebar_includes_gem_views_link
    sidebar = File.read(File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html", __dir__) + ".erb")

    assert_includes sidebar, 'label: "Gem views"'
    assert_includes sidebar, 'href: "/gem_views"'
  end

  def test_sidebar_includes_methods_link
    sidebar = File.read(File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html", __dir__) + ".erb")

    assert_includes sidebar, 'label: "Method"'
    assert_includes sidebar, 'href: "/method"'
    assert_includes sidebar, 'icon: :book_open'
  end

  def test_top_nav_includes_current_root_chip_before_avatar
    top_nav = File.read(File.expand_path("dummy/app/views/layouts/flat_pack/_top_nav.html", __dir__) + ".erb")

    assert_includes top_nav, 'FlatPack::Chip::Component.new'
    assert_includes top_nav, 'text: current_root_recordable&.name || "None selected"'
    assert_includes top_nav, 'size: :md'
    assert_includes top_nav, 'type: :link'
    assert_includes top_nav, 'href: recording_studio_root_switchable.root_switch_path(scope: current_root_scope_key)'

    chip_index = top_nav.index('FlatPack::Chip::Component.new')
    avatar_index = top_nav.index('FlatPack::Avatar::Component.new')

    refute_nil chip_index
    refute_nil avatar_index
    assert_operator chip_index, :<, avatar_index
  end

  def test_setup_page_no_longer_contains_configuration_example
    setup_view = File.read(File.expand_path("dummy/app/views/home/setup.html", __dir__) + ".erb")

    refute_includes setup_view, "RecordingStudioRootSwitchable.configure do |config|"
    assert_includes setup_view, "bin/rails generate recording_studio_root_switchable:install"
  end

  def test_config_page_contains_documented_configuration_example
    config_view = File.read(File.expand_path("dummy/app/views/home/config.html", __dir__) + ".erb")

    assert_includes config_view, 'title: "Config"'
    assert_includes config_view, "RecordingStudioRootSwitchable.configure do |config|"
    assert_includes config_view, "current_actor_resolver tells the gem which actor to use for root lookup"
    assert_includes config_view, "config.layout = :application_layout"
    assert_includes config_view, "default_root chooses the initial selection when the device has no saved root yet"
  end

  def test_dummy_app_registers_config_page_route_and_action
    routes = File.read(File.expand_path("dummy/config/routes.rb", __dir__))
    controller = File.read(File.expand_path("dummy/app/controllers/home_controller.rb", __dir__))

    assert_includes routes, 'get "config", to: "home#configuration"'
    assert_includes controller, "def configuration"
  end

  def test_dummy_app_registers_switch_log_page_route_and_action
    routes = File.read(File.expand_path("dummy/config/routes.rb", __dir__))
    controller = File.read(File.expand_path("dummy/app/controllers/home_controller.rb", __dir__))
    view = File.read(File.expand_path("dummy/app/views/home/switch_log.html", __dir__) + ".erb")

    assert_includes routes, 'get "switch_log", to: "home#switch_log"'
    assert_includes routes, 'get "persistence", to: redirect("/switch_log")'
    assert_includes controller, "def switch_log"
    assert_includes controller, "@saved_sessions = RecordingStudio::RootSwitchable::Selection"
    assert_includes controller, "def saved_session_device_context"
    assert_includes controller, "def saved_session_device_key"
    assert_includes view, 'title: "Switch log"'
    assert_includes view, "Workspace name"
    assert_includes view, "Device"
    assert_includes view, "Device key"
    assert_includes view, "Timestamp"
    assert_includes view, "saved_session_device_context(selection)"
    assert_includes view, "saved_session_device_key(selection)"
    assert_includes view, "@saved_sessions.each do |selection|"
  end

  def test_persistence_redirect_points_to_switch_log_page
    routes = File.read(File.expand_path("dummy/config/routes.rb", __dir__))
    view = File.read(File.expand_path("dummy/app/views/home/switch_log.html", __dir__) + ".erb")

    assert_includes routes, 'get "persistence", to: redirect("/switch_log")'
    assert_includes view, 'title: "Switch log"'
    assert_includes view, "No saved workspace sessions have been recorded yet."
  end

  def test_methods_page_uses_flatpack_sections_and_code_blocks
    routes = File.read(File.expand_path("dummy/config/routes.rb", __dir__))
    controller = File.read(File.expand_path("dummy/app/controllers/home_controller.rb", __dir__))
    view = File.read(File.expand_path("dummy/app/views/home/methods.html", __dir__) + ".erb")

    assert_includes routes, 'get "method", to: "home#method_docs"'
    assert_includes controller, "def method_docs"
    assert_includes controller, "def documented_methods"
    assert_includes controller, "code: <<~'CODE'"
    assert_includes controller, 'Rails.logger.info("Active root scope: #{scope_key}")'
    assert_includes view, 'title: "Method"'
    assert_includes view, 'FlatPack::SectionTitle::Component.new'
    assert_includes view, 'anchor_link: true'
    assert_includes view, 'FlatPack::CodeBlock::Component.new'
    assert_includes view, 'method.fetch(:signature)'
    assert_includes view, 'method.fetch(:code)'
  end

  def test_gem_views_page_lists_engine_templates
    routes = File.read(File.expand_path("dummy/config/routes.rb", __dir__))
    controller = File.read(File.expand_path("dummy/app/controllers/home_controller.rb", __dir__))
    view = File.read(File.expand_path("dummy/app/views/home/gem_views.html", __dir__) + ".erb")
    detail_view = File.read(File.expand_path("dummy/app/views/home/gem_view.html", __dir__) + ".erb")

    assert_includes routes, 'get "gem_views", to: "home#gem_views"'
    assert_includes routes, 'get "gem_views/*view_path", to: "home#gem_view", as: :gem_view'
    assert_includes controller, "def gem_views"
    assert_includes controller, "def gem_view"
    assert_includes controller, 'GEM_VIEWS_ROOT = RecordingStudioRootSwitchable::Engine.root.join("app/views").freeze'
    assert_includes controller, 'href: gem_view_path(relative_path)'
    assert_includes view, 'title: "Gem views"'
    assert_includes view, 'FlatPack::List::Component.new'
    assert_includes view, 'FlatPack::List::Item.new(href: view.fetch(:href), hover: true)'
    assert_includes detail_view, 'FlatPack::CodeBlock::Component.new'
    assert_includes detail_view, 'back_href: "/gem_views"'
  end
end