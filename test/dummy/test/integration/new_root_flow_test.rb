# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class NewRootFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    Rails.application.load_seed unless User.exists?(email: "admin@admin.com")
    @admin = User.find_by!(email: "admin@admin.com")
    sign_in(@admin)
  end

  test "a single creatable type links straight to the gate" do
    get "/", params: { scope: "all_workspaces" }

    assert_response :success
    assert_select "a[role='menuitem'][href*='/v1/new_root'][href*='type=Workspace']", text: /New workspace/
    assert_select "[data-modal-id='recording-studio-new-root-all_workspaces']", count: 0
  end

  test "several creatable types render a modal trigger and the disabled reason" do
    get "/", params: { scope: "studio" }

    assert_response :success
    assert_select "button[data-modal-id='recording-studio-new-root-studio']", text: /New…/
    assert_includes response.body, "New workspace"
    assert_includes response.body, "New team"
    assert_includes response.body, "Teams are full on this plan."
    assert_select "noscript a[href*='/v1/new_roots'][href*='scope=studio']", text: /New…/
  end

  test "the no-js picker page lists the same types" do
    get "/recording_studio_root_switchable/v1/new_roots", params: { scope: "studio" }

    assert_response :success
    assert_select "title", text: "Start something new"
    assert_includes response.body, "Pick one. The form comes next."
    assert_select "a[href*='/v1/new_root'][href*='type=Workspace']", text: /New workspace/
    assert_includes response.body, "Teams are full on this plan."
    assert_select "nav.flat-pack-page-nav", minimum: 1
  end

  test "an allowed gate redirects to the host form" do
    get "/recording_studio_root_switchable/v1/new_root",
        params: { scope: "all_workspaces", type: "Workspace", return_to: "/placements" }

    assert_redirected_to "/workspaces/new?return_to=%2Fplacements"
  end

  test "a refused gate redirects to the upgrade page with the reason" do
    get "/recording_studio_root_switchable/v1/new_root",
        params: { scope: "studio", type: "Team", return_to: "/placements" }

    assert_redirected_to "/upgrade"
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Teams are full on this plan."
  end

  test "an undeclared type is not found" do
    get "/recording_studio_root_switchable/v1/new_root",
        params: { scope: "all_workspaces", type: "Page" }

    assert_response :not_found
  end

  test "a shared root type cannot be declared creatable" do
    scope = RecordingStudio::RootSwitchable::ScopeDefinition.new(:shared)
    scope.switchable_root_types = ["MessageRoot"]
    scope.creatable_root("MessageRoot", path: "/messages/new")

    error = assert_raises(ArgumentError) { scope.validate_creatable_roots! }

    assert_includes error.message, "shared root"
  end

  test "a hidden type disappears from the picker and the gate is not found" do
    scope = RecordingStudioRootSwitchable.configuration.scopes.fetch("studio")
    original = scope.before_root_create
    scope.before_root_create { |ctx| ctx.root_type == "Team" ? :hide : nil }

    get "/recording_studio_root_switchable/v1/new_roots", params: { scope: "studio" }

    assert_response :success
    refute_includes response.body, "New team"

    get "/recording_studio_root_switchable/v1/new_root", params: { scope: "studio", type: "Team" }

    assert_response :not_found
  ensure
    scope.creatable_catalog.before_hook = original if scope
  end

  test "the host new and create actions run the same guard" do
    get "/workspaces/new", params: { return_to: "/placements" }

    assert_response :success
    assert_select "h1", text: "New workspace"

    post "/workspaces", params: { return_to: "/placements" }

    assert_redirected_to "/placements"

    get "/teams/new"

    assert_redirected_to "/upgrade"
    assert_equal "Teams are full on this plan. Upgrade to add another.", flash[:alert]

    post "/teams"

    assert_redirected_to "/upgrade"
  end

  test "the guard allows the host form when the hook allows" do
    scope = RecordingStudioRootSwitchable.configuration.scopes.fetch("studio")
    original = scope.before_root_create
    scope.before_root_create { nil }

    get "/teams/new"

    assert_response :success
    assert_select "h1", text: "New team"
  ensure
    scope.creatable_catalog.before_hook = original if scope
  end

  test "switch to root keeps access checks, shared roots, and the rate limit" do
    client = root_recording_for("Client Beta")
    hidden = root_recording_for("Hidden Workspace")
    studio = root_recording_for("Studio Workspace")
    message = RecordingStudio.root_recording_for(MessageRoot.find_by!(name: "Studio Messages"))

    with_probe_route do
      allowed = probe_switch(client, "all_workspaces")

      assert allowed["success"]
      assert_equal client.id, allowed["root_id"]

      shared = probe_switch(message, "all_roots")

      refute shared["success"]
      assert_equal shared["before_id"], shared["root_id"]
      refute_equal message.id, shared["root_id"]

      sign_in(User.find_by!(email: "viewer@admin.com"))
      denied = probe_switch(hidden, "all_workspaces")

      refute denied["success"]
      assert_equal denied["before_id"], denied["root_id"]
      refute_equal hidden.id, denied["root_id"]

      sign_in(@admin)
      blocked = rate_limited_switch(studio)

      refute blocked["success"]
      assert_includes blocked["errors"].join, "Too many switches"
      assert_equal blocked["before_id"], blocked["root_id"]
    end
  end

  private

  def root_recording_for(name)
    RecordingStudio.root_recording_for(Workspace.find_by!(name: name))
  end

  def rate_limited_switch(recording)
    original_cache = Rails.cache
    original_limit = RecordingStudioRootSwitchable.configuration.switch_rate_limit.dup
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    RecordingStudioRootSwitchable.configuration.switch_rate_limit = { limit: 0, period: 1.minute }
    probe_switch(recording, "all_workspaces")
  ensure
    Rails.cache = original_cache
    RecordingStudioRootSwitchable.configuration.switch_rate_limit = original_limit
  end

  def probe_switch(recording, scope)
    post "/probe_switch", params: { root_recording_id: recording.id, scope: scope }, as: :json

    JSON.parse(response.body)
  end

  def with_probe_route
    routes = Rails.application.routes
    previous = routes.disable_clear_and_finalize
    routes.disable_clear_and_finalize = true
    routes.draw { post "probe_switch", to: "switch_probes#create" }
    yield
  ensure
    Rails.application.reload_routes!
    Rails.application.routes.disable_clear_and_finalize = previous
  end
end

class SwitchProbesController < ApplicationController
  def create
    recording = RecordingStudio::Recording.find(params[:root_recording_id])
    before_id = RecordingStudio::RootSwitchable.current_root_recording&.id
    result = recording_studio_switch_to_root!(recording, scope: params[:scope])
    render json: {
      success: result.success?,
      errors: result.errors,
      before_id: before_id,
      root_id: RecordingStudio::RootSwitchable.current_root_recording&.id
    }
  end
end
