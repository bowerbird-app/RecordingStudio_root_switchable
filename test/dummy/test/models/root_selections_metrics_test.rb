# frozen_string_literal: true

require "test_helper"

class RootSelectionsMetricsTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_seed unless User.exists?(email: "admin@admin.com")
    @actor = User.find_by!(email: "admin@admin.com")
    @other = User.find_by!(email: "viewer@admin.com")
    @root = RecordingStudio.root_recording_for(Workspace.find_by!(name: "Studio Workspace"))
    @now = Time.utc(2026, 10, 9, 12)
    RecordingStudioMetrics.registry.reset!
    RecordingStudioRootSwitchable::Metrics.register!
  end

  teardown do
    RecordingStudio::RootSwitchable::Selection.delete_all
    RecordingStudioMetrics.registry.reset!
  end

  test "registers last-used selection metrics on the operations API" do
    identifiers = RecordingStudioMetrics.for_resource(:root_selections).map(&:identifier)

    assert_includes identifiers, "root_selections.active_actors_7d"
    assert_includes identifiers, "root_selections.active_actors_30d"
    assert_includes identifiers, "root_selections.active_devices_30d"
    assert_includes identifiers, "root_selections.by_device_type"
    assert_includes identifiers, "root_selections.by_platform"
    assert_includes identifiers, "root_selections.by_browser"

    RecordingStudioMetrics.for_resource(:root_selections).each do |definition|
      assert_equal [:operations], definition.exposed_apis
      assert_equal :site, definition.blast_radius
    end
  end

  test "active actors and devices honor last_used_at windows and distinct keys" do
    travel_to(@now) do
      seed_selection(actor: @actor, device_key: "phone", scope_key: "all_roots",
                     last_used_at: 2.days.ago, device_type: "mobile",
                     device_platform: "iOS", device_browser: "Safari")
      seed_selection(actor: @actor, device_key: "laptop", scope_key: "all_roots",
                     last_used_at: 2.days.ago, device_type: "desktop",
                     device_platform: "macOS", device_browser: "Chrome")
      seed_selection(actor: @actor, device_key: "laptop", scope_key: "client_workspaces",
                     last_used_at: 2.days.ago, device_type: "desktop",
                     device_platform: "macOS", device_browser: "Chrome")
      seed_selection(actor: @other, device_key: "tablet", scope_key: "all_roots",
                     last_used_at: 10.days.ago, device_type: "tablet",
                     device_platform: "Android", device_browser: "Chrome")
      seed_selection(actor: @other, device_key: "old", scope_key: "all_roots",
                     last_used_at: 40.days.ago, device_type: "desktop",
                     device_platform: "Windows", device_browser: "Edge")

      assert_equal 1, execute("root_selections.active_actors_7d").value
      assert_equal 2, execute("root_selections.active_actors_30d").value
      assert_equal 3, execute("root_selections.active_devices_30d").value

      types = execute("root_selections.by_device_type").data.to_h { |row| [row[:key].to_s, row[:value]] }
      platforms = execute("root_selections.by_platform").data.to_h { |row| [row[:key].to_s, row[:value]] }
      browsers = execute("root_selections.by_browser").data.to_h { |row| [row[:key].to_s, row[:value]] }

      assert_equal 2, types["desktop"]
      assert_equal 1, types["mobile"]
      assert_equal 1, types["tablet"]
      refute types.key?("Windows")
      assert_equal 2, platforms["macOS"]
      assert_equal 1, platforms["iOS"]
      assert_equal 1, platforms["Android"]
      refute platforms.key?("Windows")
      assert_equal 3, browsers["Chrome"]
      assert_equal 1, browsers["Safari"]
      refute browsers.key?("Edge")
    end
  end

  test "execute handler allows staff and denies everyone else" do
    travel_to(@now) do
      seed_selection(actor: @actor, device_key: "phone", scope_key: "all_roots",
                     last_used_at: 1.day.ago, device_type: "mobile",
                     device_platform: "iOS", device_browser: "Safari")

      error = assert_raises(RecordingStudioMetrics::Errors::AuthorizationError) do
        RecordingStudioMetrics::Api::ExecuteHandler.call(build_api_context(@other))
      end
      assert_match(/not authorized/i, error.message)

      RecordingStudioRootSwitchable::Api::Access.stub(:can_view?, true) do
        payload = RecordingStudioMetrics::Api::ExecuteHandler.call(build_api_context(@actor))
        assert_equal "root_selections.active_actors_7d", payload[:metric]
        assert_equal 1, payload[:value]
      end
    end
  end

  test "discovery hides metrics from denied callers" do
    denied = RecordingStudioMetrics::Api::DiscoveryHandler.call(build_api_context(@actor))
    denied_ids = denied.fetch(:metrics).map { |row| row[:identifier] }
    refute_includes denied_ids, "root_selections.active_actors_7d"

    RecordingStudioRootSwitchable::Api::Access.stub(:can_view?, true) do
      allowed = RecordingStudioMetrics::Api::DiscoveryHandler.call(build_api_context(@actor))
      allowed_ids = allowed.fetch(:metrics).map { |row| row[:identifier] }
      assert_includes allowed_ids, "root_selections.active_actors_7d"
    end
  end

  private

  def execute(identifier)
    RecordingStudioMetrics.execute(
      identifier,
      context: RecordingStudioMetrics::Context.new(
        actor: @actor,
        scope: :site,
        site_authorized: true,
        timezone: "UTC"
      )
    )
  end

  def seed_selection(actor:, device_key:, scope_key:, last_used_at:, device_type:, device_platform:, device_browser:)
    RecordingStudio::RootSwitchable::Selection.create!(
      actor: actor,
      device_key: device_key,
      scope_key: scope_key,
      root_recording: @root,
      last_used_at: last_used_at,
      device_type: device_type,
      device_platform: device_platform,
      device_browser: device_browser
    )
  end

  def build_api_context(actor)
    grant = Struct.new(:actor).new(actor)
    params = {
      resource: "root_selections",
      name: "active_actors_7d",
      interval: nil,
      start: nil,
      start_at: nil,
      end: nil,
      end_at: nil,
      timezone: "UTC",
      filters: {}
    }
    context = Object.new
    context.define_singleton_method(:access_grant) { grant }
    context.define_singleton_method(:api_client) { actor }
    context.define_singleton_method(:access_recording) { nil }
    context.define_singleton_method(:root_recording) { nil }
    context.define_singleton_method(:api_key) { :operations }
    context.define_singleton_method(:params) { params }
    context
  end
end
