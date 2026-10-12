# frozen_string_literal: true

require "test_helper"
require "i18n"
require "yaml"

class LocalesTest < Minitest::Test
  EXPECTED_KEYS = {
    "layout.title" => "Recording Studio",
    "layout.application_name" => "Recording Studio",
    "navigation.close" => "Close",
    "dropdown.none_selected" => "None selected",
    "page_copy.title" => "Switch",
    "page_copy.subtitle" => "",
    "page_copy.scope_heading" => "Scopes",
    "page_copy.roots_heading" => "Available",
    "page_copy.current_selection_label" => "Current selection",
    "page_copy.device_label" => "Device key",
    "page_copy.persistence_hint" => "",
    "page_copy.selected_badge" => "Current",
    "page_copy.switch_action_label" => "Switch",
    "page_copy.empty_state_title" => "Nothing to switch",
    "page_copy.empty_state_body" => "There are no options available right now."
  }.freeze

  def setup
    @original_load_path = I18n.load_path.dup
    @original_backend = I18n.backend
    I18n.backend = I18n::Backend::Simple.new
    load_engine_locales!
  end

  def teardown
    I18n.load_path = @original_load_path
    I18n.backend = @original_backend
    I18n.reload!
  end

  def test_engine_ships_only_english_locale_files
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  def test_rails_engine_exposes_english_locale_path
    locale_path = File.expand_path(File.join(engine_locales_dir, "en.yml"))
    existent = RecordingStudioRootSwitchable::Engine.paths["config/locales"].existent.map do |path|
      File.expand_path(path)
    end

    assert_includes existent, locale_path
  end

  def test_english_root_switchable_keys_resolve_without_missing_translations
    I18n.with_locale(:en) do
      EXPECTED_KEYS.each do |key, english|
        full_key = "recording_studio.root_switchable.#{key}"
        translation = I18n.t(full_key, default: nil)

        assert_equal english, translation, "#{full_key} should resolve to #{english.inspect}"
        assert_equal english, I18n.t(full_key, raise: true)
      end
    end
  end

  def test_en_yml_nests_keys_under_recording_studio_root_switchable
    tree = locale_tree(File.join(engine_locales_dir, "en.yml"), "en")
           .fetch("recording_studio")
           .fetch("root_switchable")

    assert_equal "Recording Studio", tree.fetch("layout").fetch("title")
    assert_equal "Recording Studio", tree.fetch("layout").fetch("application_name")
    assert_equal "Close", tree.fetch("navigation").fetch("close")
    assert_equal "None selected", tree.fetch("dropdown").fetch("none_selected")
    assert_equal "Switch", tree.fetch("page_copy").fetch("title")
    assert_equal "Current", tree.fetch("page_copy").fetch("selected_badge")
    assert_equal "Nothing to switch", tree.fetch("page_copy").fetch("empty_state_title")
  end

  def test_no_legacy_top_level_locale_namespace_is_shipped
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    refute_includes files, "recording_studio_root_switchable.en.yml"
    tree = locale_tree(File.join(engine_locales_dir, "en.yml"), "en")
    refute tree.key?("recording_studio_root_switchable")
  end

  def test_lib_does_not_set_i18n_load_path
    Dir[File.expand_path("../lib/**/*.rb", __dir__)].each do |path|
      source = File.read(path)

      refute_includes source, "i18n.load_path", "#{path} must not set i18n.load_path"
      refute_includes source, "I18n.load_path", "#{path} must not set I18n.load_path"
    end
  end

  def test_gemspec_and_dummy_gemfile_do_not_depend_on_internationalization
    gemspec = File.read(File.expand_path("../recording_studio_root_switchable.gemspec", __dir__))
    dummy_gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))

    refute_includes gemspec, "recording_studio_internationalization"
    refute_includes gemspec, "RecordingStudio_Internationalization"
    refute_includes dummy_gemfile, "recording_studio_internationalization"
    refute_includes dummy_gemfile, "RecordingStudio_Internationalization"
  end

  private

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def locale_tree(path, locale)
    YAML.safe_load_file(path, aliases: true).fetch(locale)
  end

  def load_engine_locales!
    paths = Dir[File.join(engine_locales_dir, "*.yml")].map { |path| File.expand_path(path) }
    I18n.load_path |= paths
    I18n.backend.load_translations
  end
end
