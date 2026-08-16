# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class RootSwitchDropdownTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    Rails.application.load_seed unless User.exists?(email: "admin@admin.com")
    @admin = User.find_by!(email: "admin@admin.com")
  end

  test "top nav renders a root switch dropdown that posts back to the current page" do
    sign_in(@admin)

    get "/config",
        headers: {
          "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Safari/605.1.15"
        }

    assert_response :success

    assert_select "[data-controller='recording-studio-root-switchable--root-switch-dropdown']" do
      assert_select "[data-controller='flat-pack--button-dropdown']" do
        assert_select "button", text: /Studio Workspace/
        assert_select "[role='menuitem'][form^='root-switch-dropdown-all_roots-']", text: /Client Alpha/
        assert_select(
          "[role='menuitem'][data-action='click->recording-studio-root-switchable--root-switch-dropdown#select']",
          minimum: 1
        )
      end
    end

    assert_select "form.hidden[id^='root-switch-dropdown-all_roots-'][data-turbo='false']", count: 0
    assert_select "form.hidden[id^='root-switch-dropdown-all_roots-'] input[name='root_switch[root_recording_id]']",
                  minimum: 1
    assert_select "form.hidden[id^='root-switch-dropdown-all_roots-'] input[name='root_switch[return_to]'][value='/config']",
                  minimum: 1
  end
end
