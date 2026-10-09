# frozen_string_literal: true

require "test_helper"
require "i18n"
require_relative "../app/helpers/recording_studio_root_switchable/root_switch_dropdown_helper"

class RootSwitchDropdownHelperTest < Minitest::Test
  include RecordingStudioRootSwitchable::RootSwitchDropdownHelper

  def setup
    @original_load_path = I18n.load_path.dup
    @original_backend = I18n.backend
    I18n.backend = I18n::Backend::Simple.new
    locale_path = File.expand_path("../config/locales/en.yml", __dir__)
    I18n.load_path |= [locale_path]
    I18n.backend.load_translations
  end

  def teardown
    I18n.load_path = @original_load_path
    I18n.backend = @original_backend
    I18n.reload!
  end

  def t(key, **)
    I18n.t(key, **)
  end

  def test_dropdown_label_uses_literal_english_none_selected_when_root_blank
    I18n.with_locale(:en) do
      label = recording_studio_root_switch_dropdown_label(scope: Object.new, root_recording: nil)

      assert_equal "None selected", label
    end
  end

  def test_dropdown_label_uses_scope_label_when_root_present
    scope = Object.new
    recording = Object.new
    def scope.root_label_for(**)
      "Studio Workspace"
    end

    define_singleton_method(:current_root_device_key) { "device-1" }
    define_singleton_method(:controller) { self }

    I18n.with_locale(:en) do
      label = recording_studio_root_switch_dropdown_label(scope: scope, root_recording: recording)

      assert_equal "Studio Workspace", label
    end
  end
end
