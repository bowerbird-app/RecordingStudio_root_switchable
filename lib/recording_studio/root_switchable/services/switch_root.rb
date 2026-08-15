# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    module Services
      class SwitchRoot < Base
        def initialize(root_recording_id:, scope_key:, controller: nil, actor: nil, device_key: nil)
          @controller = controller
          @actor = actor
          @device_key = device_key
          @root_recording_id = root_recording_id
          @scope_key = scope_key
        end

        def call
          scope = nil
          roots = []

          if @actor.blank? && !configuration.allow_anonymous_selections
            return failure_result(errors: ["An authenticated actor is required to switch roots."], scope: scope)
          end

          scope = scope_context.resolve_scope
          return failure_result(errors: ["Scope could not be resolved."], scope: scope) unless scope

          roots = scope_context.available_roots_for(scope)
          root_recording = RootId.find_in(roots, @root_recording_id)
          unless root_recording
            return failure_result(
              errors: ["Selected root is not available for this scope."],
              scope: scope,
              available_roots: roots
            )
          end

          selection = RecordingStudio::RootSwitchable::Selection.upsert_for(
            actor: @actor,
            device_key: @device_key,
            device_metadata: RecordingStudio::RootSwitchable::DeviceMetadata.capture(controller: @controller),
            root_recording: root_recording,
            scope_key: scope.key
          )

          assign_current(scope: scope, root_recording: root_recording, selection: selection)

          Result.new(
            available_roots: roots,
            root_recording: root_recording,
            scope: scope,
            selected_via: :persisted,
            selection: selection
          )
        rescue ActiveRecord::RecordInvalid => e
          failure_result(
            errors: Array(e.record.errors.full_messages.presence || e.message),
            scope: scope,
            available_roots: roots
          )
        end

        private

        def failure_result(errors:, scope:, available_roots: [])
          Result.new(
            available_roots: available_roots,
            errors: errors,
            root_recording: Current.root_recording,
            scope: scope,
            selected_via: :none,
            selection: Current.selection
          )
        end
      end
    end
  end
end
