# frozen_string_literal: true

require "test_helper"
require "i18n"

class RootSwitchDropdownHelperTest < Minitest::Test
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

  def test_none_selected_copy_is_literal_english
    I18n.with_locale(:en) do
      assert_equal "None selected", I18n.t("recording_studio.root_switchable.dropdown.none_selected")
    end
  end
end
