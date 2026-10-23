# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class RootSwitchPlacementsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  BROWSER = {
    "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Safari/605.1.15"
  }.freeze

  setup do
    Rails.application.load_seed unless User.exists?(email: "admin@admin.com")
    @admin = User.find_by!(email: "admin@admin.com")
    @viewer = User.find_by!(email: "viewer@admin.com")
  end

  test "placements page renders the dropdown, host menu, and collapsing button group" do
    sign_in(@admin)
    clear_selections(@admin)

    get "/placements", headers: BROWSER

    assert_response :success
    assert_select "[data-controller='recording-studio-root-switchable--root-switch-dropdown']", count: 0

    assert_select "#root-switch-standalone" do
      assert_select "[data-flat-pack--button-dropdown-target='trigger']", text: /Studio Workspace/
      assert_select ".fp-menu-collapse", count: 0
      assert_switch_form "Client Alpha"
      assert_switch_form "Client Beta"
      assert_select "button[role='menuitem']", text: "Studio Workspace", count: 0
    end

    assert_select "#root-switch-host-menu" do
      assert_select "[role='menuitem']", text: "Rename"
      assert_select "[role='menuitem']", text: "Duplicate"
      assert_select ".fp-menu-collapse__label", text: "Studio Workspace"
      assert_switch_form "Client Alpha"
      assert_select "button[role='menuitem']", text: "Studio Workspace", count: 0
    end

    assert_select "#root-switch-button-group .fp-button-group-menu__row" do
      assert_select "[data-flat-pack--button-dropdown-target='trigger']", text: /Studio Workspace/
      assert_select "button", text: "Invite"
      assert_select ".fp-menu-collapse", count: 0
    end

    assert_select "#root-switch-button-group .fp-button-group-menu__panel" do
      assert_select ".fp-menu-collapse__label", text: "Studio Workspace"
      assert_switch_form "Client Alpha"
      assert_switch_form "Client Beta"
      assert_select ".fp-button-dropdown", count: 0
    end

    assert_select "body", text: /Hidden Workspace/, count: 0
    assert_select "body", text: /Operations Team/, count: 0
    assert_select "body", text: /Studio Messages/, count: 0
    assert_select "input[name='root_switch[return_to]'][value='/placements']", minimum: 1
    assert_select "input[name='_method'][value='patch']", minimum: 1
  end

  test "viewer only sees workspaces they can access" do
    sign_in(@viewer)
    clear_selections(@viewer)

    get "/placements", headers: BROWSER

    assert_response :success
    assert_select "#root-switch-standalone button[role='menuitem']", text: "Client Alpha"
    assert_select "#root-switch-standalone button[role='menuitem']", text: "Client Beta", count: 0
    assert_select "body", text: /Hidden Workspace/, count: 0
    assert_select "body", text: /Client Beta/, count: 0
  end

  test "submitting a placement switch updates the current workspace" do
    sign_in(@admin)
    clear_selections(@admin)
    alpha = root_recording_for("Client Alpha")

    patch "/recording_studio_root_switchable/v1/root_switch",
          params: {
            scope: "all_roots",
            root_switch: { root_recording_id: alpha.id, return_to: "/placements" }
          },
          headers: BROWSER

    assert_redirected_to "/placements"

    follow_redirect!
    assert_select "#root-switch-standalone [data-flat-pack--button-dropdown-target='trigger']", text: /Client Alpha/
    assert_select "#root-switch-host-menu .fp-menu-collapse__label", text: "Client Alpha"
    assert_select "#root-switch-button-group .fp-menu-collapse__label", text: "Client Alpha"
    assert_select "#root-switch-standalone button[role='menuitem']", text: "Studio Workspace"
    assert_select "#root-switch-standalone button[role='menuitem']", text: "Client Alpha", count: 0
  end

  private

  def clear_selections(actor)
    RecordingStudio::RootSwitchable::Selection.where(actor: actor).delete_all
  end

  def assert_switch_form(label)
    assert_select "button[role='menuitem']", text: label
    recording = root_recording_for(label)
    assert_select "input[name='root_switch[root_recording_id]'][value='#{recording.id}']"
  end

  def root_recording_for(name)
    RecordingStudio.root_recording_for(Workspace.find_by!(name: name))
  end
end
