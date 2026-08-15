# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class RootSwitchDemoTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    Rails.application.load_seed unless User.exists?(email: "admin@admin.com")
    @admin = User.find_by!(email: "admin@admin.com")
  end

  test "root switch page renders for seeded admin" do
    sign_in(@admin)

    get "/recording_studio_root_switchable/v1/root_switch",
        params: { scope: "all_workspaces" },
        headers: {
          "HTTP_USER_AGENT" => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36"
        }

    assert_response :success
    assert_includes response.body, "Switch"
    assert_includes response.body, "Studio Workspace"
    assert_includes response.body, "Client Alpha"
    assert_operator response.body.index("Studio Workspace"), :<, response.body.index("Client Alpha")
  end

  test "dummy app sidebar layout defaults to the rounded FlatPack theme" do
    sign_in(@admin)

    get "/"

    assert_response :success
    assert_match(/<html[^>]*data-theme="rounded"/, response.body)
    assert_includes response.body, "Switch"
    refute_includes response.body, "Change"
    refute_includes response.body, "Pages in the current root"
    refute_includes response.body, "Each workspace root now has its own seeded pages so switching roots changes the content shown here."
  end

  test "root switch update persists the selected accessible root" do
    sign_in(@admin)
    selected_root = root_recording_for("Client Alpha")
    existing_selection_ids = RecordingStudio::RootSwitchable::Selection.ids

    assert_difference -> { RecordingStudio::RootSwitchable::Selection.count }, 1 do
      patch "/recording_studio_root_switchable/v1/root_switch",
            params: {
              scope: "all_workspaces",
              root_switch: {
                root_recording_id: selected_root.id,
                return_to: "/"
              }
            },
            headers: {
              "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Safari/605.1.15"
            }
    end

    assert_redirected_to "/"
    selection = RecordingStudio::RootSwitchable::Selection
                .where(actor: @admin, scope_key: "all_workspaces")
                .where.not(id: existing_selection_ids)
                .first!
    assert_equal selected_root, selection.root_recording
    assert_predicate selection.device_key, :present?
    assert_equal "Safari", selection.device_browser
    assert_nil selection.user_agent
  end

  test "root switch update rejects non-root recordings" do
    sign_in(@admin)
    page_recording = root_recording_for("Studio Workspace").recordings_query(type: Page).first

    assert_no_difference -> { RecordingStudio::RootSwitchable::Selection.count } do
      patch "/recording_studio_root_switchable/v1/root_switch",
            params: {
              scope: "all_workspaces",
              root_switch: {
                root_recording_id: page_recording.id
              }
            }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Selected root is not available for this scope."
  end

  test "matching the seeded admin email does not authorize access management without bootstrap flag" do
    authorizer = RecordingStudioAccessible.configuration.access_management_authorizer

    refute authorizer.call(actor: @admin)
  end

  private

  def root_recording_for(workspace_name)
    RecordingStudio.root_recording_for(Workspace.find_by!(name: workspace_name))
  end
end
