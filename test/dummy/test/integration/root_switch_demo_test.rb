# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class RootSwitchDemoTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "root switch page renders for seeded admin" do
    Rails.application.load_seed unless User.exists?(email: "admin@admin.com")

    sign_in(User.find_by!(email: "admin@admin.com"))

    get "/recording_studio_root_switchable/v1/root_switch",
        params: { scope: "all_workspaces" },
        headers: {
          "HTTP_USER_AGENT" => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36"
        }

    assert_response :success
    assert_includes response.body, "Change workspace"
    assert_includes response.body, "Studio Workspace"
  end
end