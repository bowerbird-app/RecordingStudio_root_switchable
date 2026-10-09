# frozen_string_literal: true

require_relative "api/access"
require "recording_studio_metrics"

module RecordingStudioRootSwitchable
  module Metrics
    RESOURCE = :root_selections
    API = :operations
    EXPOSE = { api: [API] }.freeze
    LAST_USED = "Rows are last-used per actor+device+scope (upserted), not switch counts. " \
                "user_agent and actor identities are never exposed."
    WINDOW_NOTE = "Distinct actor/device counts use custom calculators; " \
                  "breakdowns apply the 30-day last_used_at window via per-metric scope."

    module_function

    def register!
      RecordingStudioMetrics.register(
        RESOURCE,
        model: RecordingStudio::RootSwitchable::Selection,
        blast_radius: :site,
        api_authorize: ->(context) { RecordingStudioRootSwitchable::Api::Access.can_view?(context) }
      ) do
        RecordingStudioRootSwitchable::Metrics.define_metrics(self)
      end
    end

    def define_metrics(dsl)
      define_active_actors(dsl)
      define_active_devices(dsl)
      define_breakdowns(dsl)
    end

    def define_active_actors(dsl)
      define_active_actor_window(dsl, :active_actors_7d, 7.days)
      define_active_actor_window(dsl, :active_actors_30d, 30.days)
    end

    def define_active_actor_window(dsl, name, window)
      days = (window / 1.day).to_i
      dsl.custom name,
                 result_type: :scalar,
                 title: "Active actors (#{days}d last-used)",
                 description: "#{LAST_USED} Distinct actor_id with last_used_at in the last " \
                              "#{days} days. #{WINDOW_NOTE}",
                 expose: EXPOSE,
                 &distinct_actor_calculator(window)
    end

    def define_active_devices(dsl)
      dsl.custom :active_devices_30d,
                 result_type: :scalar,
                 title: "Active devices (30d last-used)",
                 description: "#{LAST_USED} Distinct device_key with last_used_at in the last 30 days. #{WINDOW_NOTE}",
                 expose: EXPOSE,
                 &distinct_device_calculator(30.days)
    end

    def define_breakdowns(dsl)
      define_breakdown(dsl, :by_device_type, :device_type)
      define_breakdown(dsl, :by_platform, :device_platform)
      define_breakdown(dsl, :by_browser, :device_browser)
    end

    def define_breakdown(dsl, name, field)
      dsl.breakdown name,
                    field: field,
                    title: "#{name.to_s.humanize} (30d last-used)",
                    description: "#{LAST_USED} Last-used selection rows in the last 30 days grouped by #{field}.",
                    expose: EXPOSE,
                    scope: last_used_scope(30.days)
    end

    def last_used_scope(window)
      ->(relation) { used_since(relation, window) }
    end

    def distinct_actor_calculator(window)
      lambda do |relation, _context|
        used_since(relation, window).where.not(actor_id: nil).distinct.count(:actor_id)
      end
    end

    def distinct_device_calculator(window)
      lambda do |relation, _context|
        used_since(relation, window).distinct.count(:device_key)
      end
    end

    def used_since(relation, window)
      relation.where(last_used_at: window.ago..)
    end
  end
end
