# frozen_string_literal: true

require "test_helper"

class RenameVerificationTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_key_root_switchable_files_exist
    assert File.exist?(File.join(ROOT, "recording_studio_root_switchable.gemspec"))
    assert File.exist?(File.join(ROOT, "lib/recording_studio_root_switchable.rb"))
    assert File.exist?(File.join(ROOT, "lib/recording_studio_root_switchable/version.rb"))
    assert File.exist?(File.join(ROOT, "app/controllers/recording_studio_root_switchable/root_switches_controller.rb"))
    assert File.exist?(File.join(ROOT, "app/views/recording_studio_root_switchable/root_switches/show.html.erb"))
  end

  def test_routes_reference_root_switchable_engine
    routes = File.read(File.join(ROOT, "config/routes.rb"))

    assert_includes routes, "RecordingStudioRootSwitchable::Engine.routes.draw"
    assert_includes routes, "resource :root_switch"
  end

  def test_no_stale_template_references_outside_archived_docs
    files = Dir.glob(File.join(ROOT, "**/*.{rb,erb,md,gemspec}"))
    files.reject! { |path| path.include?("/docs/gem_template/") }
    files.reject! { |path| path.include?("/coverage/") }
    files.reject! { |path| path.include?("/test/dummy/coverage/") }
    files.reject! { |path| path.end_with?("/test/rename_verification_test.rb") }

    stale_files = files.select do |path|
      next false unless File.file?(path)

      contents = File.read(path).gsub("docs/gem_template", "")
      contents = contents.gsub("gem_template", "")
      contents.include?("GemTemplate") || contents.include?("gem_template")
    end

    assert stale_files.empty?, "Found stale template references in:\n#{stale_files.join("\n")}"
  end
end
