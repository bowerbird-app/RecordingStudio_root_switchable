# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    module Services
      class ResolveCurrentRoot < Base
        def initialize(controller: nil, actor: nil, device_key: nil, scope_key: nil)
          @controller = controller
          @actor = actor
          @device_key = device_key
          @scope_key = scope_key
        end

        def call
          resolved_scope = scope_context.resolve_scope

          return empty_result unless resolved_scope

          roots = scope_context.available_roots_for(resolved_scope)
          selection = find_selection(resolved_scope)
          selected_via = :none
          root_recording = nil

          if selection && RootId.find_in(roots, selection.root_recording_id)
            root_recording = RootId.find_in(roots, selection.root_recording_id)
            touch_last_used_at!(selection)
            selected_via = :persisted
          elsif selection
            # Invalidate once when access/availability is lost; avoid touching on every request.
            selection.destroy
            selection = nil
          end

          if root_recording.blank?
            root_recording = scope_context.default_root_for(resolved_scope, roots)
            selected_via = root_recording.present? ? :default : :none
          end

          assign_current(scope: resolved_scope, root_recording: root_recording, selection: selection)

          Result.new(
            available_roots: roots,
            root_recording: root_recording,
            scope: resolved_scope,
            selected_via: selected_via,
            selection: selection
          )
        end

        private

        def empty_result
          assign_current(scope: nil, root_recording: nil, selection: nil)

          Result.new(
            available_roots: [],
            errors: ["No supported root scopes are configured."],
            root_recording: nil,
            scope: nil,
            selected_via: :none,
            selection: nil
          )
        end

        def find_selection(scope)
          return unless defined?(RecordingStudio::RootSwitchable::Selection)
          return if @actor.blank? && !configuration.allow_anonymous_selections

          RecordingStudio::RootSwitchable::Selection.lookup(
            actor: @actor,
            device_key: @device_key,
            scope_key: scope.key
          )
        end

        def touch_last_used_at!(selection)
          return unless selection.respond_to?(:update_columns)
          return unless selection.respond_to?(:last_used_at)

          interval = configuration.last_used_at_touch_interval
          last_used_at = selection.last_used_at
          return if last_used_at.present? && interval.present? && last_used_at > interval.ago

          selection.update_columns(last_used_at: Time.current)
        end
      end
    end
  end
end
