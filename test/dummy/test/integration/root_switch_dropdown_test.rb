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
    RecordingStudio::RootSwitchable::Selection.where(actor: @admin).delete_all

    get "/config",
        headers: {
          "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Safari/605.1.15"
        }

    assert_response :success
    assert_select "[data-controller='recording-studio-root-switchable--root-switch-dropdown']", count: 0

    assert_select "[data-controller='flat-pack--button-dropdown']" do
      assert_select "[data-flat-pack--button-dropdown-target='trigger']", text: /Studio Workspace/
      assert_select "button[role='menuitem']", text: /Client Alpha/
    end

    assert_select "form[action*='root_switch'] input[name='root_switch[root_recording_id]']", minimum: 1
    assert_select "form[action*='root_switch'] input[name='root_switch[return_to]'][value='/config']", minimum: 1
    assert_select "form[action*='root_switch'] input[name='_method'][value='patch']", minimum: 1
  end
end
