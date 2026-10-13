# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

# Proves a host nested `recording_studio.root_switchable.*` override in
# config/locales wins over gem English at boot. Uses page_copy.device_label
# (not shown on the default switch UI) plus a test-only probe route. Does not
# touch I18n.load_path.
class RootSwitchableBootOrderHostOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    Rails.application.load_seed unless User.exists?(email: "admin@admin.com")
    @admin = User.find_by!(email: "admin@admin.com")
    @original_load_path = I18n.load_path.dup
    sign_in(@admin)
  end

  teardown do
    assert_equal @original_load_path, I18n.load_path,
                 "tests must not leave I18n.load_path modified"
  end

  test "boot-loaded host override wins on rarely shown device_label" do
    host_locale = Rails.root.join(
      "config/locales/recording_studio_root_switchable_boot_override.en.yml"
    )
    assert File.exist?(host_locale), "expected host override file at #{host_locale}"

    assert_equal "HOST Device key",
                 I18n.t("recording_studio.root_switchable.page_copy.device_label", raise: true)
    refute_equal "Device key",
                 I18n.t("recording_studio.root_switchable.page_copy.device_label", raise: true)

    get "/recording_studio_root_switchable/v1/root_switch",
        params: { scope: "all_workspaces" }

    assert_response :success
    assert_includes response.body, "Switch"
    assert_includes response.body, "Current"
    refute_includes response.body, "HOST Device key"
    assert_equal @original_load_path, I18n.load_path
    assert_equal "HOST Device key",
                 I18n.t("recording_studio.root_switchable.page_copy.device_label", raise: true)

    get "/root_switchable_i18n_probe",
        headers: {
          "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Safari/605.1.15"
        }

    assert_response :success, -> { "probe status=#{response.status} body=#{response.body.to_s[0, 400]}" }
    assert_select "td", text: "HOST Device key"
    assert_select "td", text: "Probe"
  end
end
