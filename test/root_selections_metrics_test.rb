# frozen_string_literal: true

require "test_helper"
require "active_support/testing/time_helpers"

class RootSelectionsMetricsTest < Minitest::Test
  include ActiveSupport::Testing::TimeHelpers

  def setup
    @now = Time.utc(2026, 10, 9, 12)
    @actor = Object.new
    RecordingStudioMetrics.registry.reset!
    RecordingStudioRootSwitchable::Metrics.register!
  end

  def teardown
    RecordingStudioMetrics.registry.reset!
  end

  def test_active_actors_and_devices_honor_last_used_windows
    travel_to_now do
      relation = SeededSelections.new(seeded_rows)

      assert_equal 1, calculate(:active_actors_7d, relation)
      assert_equal 2, calculate(:active_actors_30d, relation)
      assert_equal 3, calculate(:active_devices_30d, relation)

      with_seeded_relation(relation) do
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
  end

  def test_execute_uses_seeded_last_used_values
    travel_to_now do
      relation = SeededSelections.new(seeded_rows)
      with_seeded_relation(relation) do
        assert_equal 1, execute("root_selections.active_actors_7d").value
        assert_equal 2, execute("root_selections.active_actors_30d").value
        assert_equal 3, execute("root_selections.active_devices_30d").value
      end
    end
  end

  def test_execute_handler_allows_staff_and_denies_everyone_else
    travel_to_now do
      relation = SeededSelections.new(seeded_rows)

      error = assert_raises(RecordingStudioMetrics::Errors::AuthorizationError) do
        RecordingStudioMetrics::Api::ExecuteHandler.call(build_api_context(@actor))
      end
      assert_match(/not authorized/i, error.message)

      RecordingStudioRootSwitchable::Api::Access.stub(:can_view?, true) do
        with_seeded_relation(relation) do
          payload = RecordingStudioMetrics::Api::ExecuteHandler.call(build_api_context(@actor))
          assert_equal "root_selections.active_actors_7d", payload[:metric]
          assert_equal 1, payload[:value]
        end
      end
    end
  end

  def test_discovery_hides_metrics_from_denied_callers
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

  def travel_to_now(&)
    travel_to(@now, &)
  end

  def seeded_rows
    [
      { actor_id: "a1", device_key: "phone", last_used_at: 2.days.ago,
        device_type: "mobile", device_platform: "iOS", device_browser: "Safari" },
      { actor_id: "a1", device_key: "laptop", last_used_at: 2.days.ago,
        device_type: "desktop", device_platform: "macOS", device_browser: "Chrome" },
      { actor_id: "a1", device_key: "laptop", last_used_at: 2.days.ago,
        device_type: "desktop", device_platform: "macOS", device_browser: "Chrome" },
      { actor_id: "a2", device_key: "tablet", last_used_at: 10.days.ago,
        device_type: "tablet", device_platform: "Android", device_browser: "Chrome" },
      { actor_id: "a2", device_key: "old", last_used_at: 40.days.ago,
        device_type: "desktop", device_platform: "Windows", device_browser: "Edge" }
    ]
  end

  def calculate(name, relation)
    calculator =
      case name
      when :active_actors_7d then RecordingStudioRootSwitchable::Metrics.distinct_actor_calculator(7.days)
      when :active_actors_30d then RecordingStudioRootSwitchable::Metrics.distinct_actor_calculator(30.days)
      when :active_devices_30d then RecordingStudioRootSwitchable::Metrics.distinct_device_calculator(30.days)
      end
    calculator.call(relation, nil)
  end

  def with_seeded_relation(relation, &)
    RecordingStudioMetrics::Authorization.stub(
      :base_relation,
      lambda do |definition, _context|
        scope = definition.scope
        scope ? scope.call(relation) : relation
      end,
      &
    )
  end

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

  class SeededSelections
    def initialize(rows)
      @rows = rows
    end

    def where(clause = nil)
      return WhereChain.new(@rows) if clause.nil?

      range = clause[:last_used_at]
      self.class.new(@rows.select { |row| range.cover?(row.fetch(:last_used_at)) })
    end

    def distinct
      Distinct.new(@rows)
    end

    def group(field)
      Grouped.new(@rows, field)
    end

    class WhereChain
      def initialize(rows)
        @rows = rows
      end

      def not(**)
        SeededSelections.new(@rows.reject { |row| row[:actor_id].nil? })
      end
    end

    class Distinct
      def initialize(rows)
        @rows = rows
      end

      def count(field)
        @rows.map { |row| row[field] }.uniq.size
      end
    end

    class Grouped
      def initialize(rows, field)
        @rows = rows
        @field = field
      end

      def distinct
        self
      end

      def count
        @rows.group_by { |row| row[@field] }.transform_values(&:size)
      end
    end
  end
end
