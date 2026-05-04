# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    module Services
      class SwitchRoot
        class << self
          def call(...)
            new(...).call
          end
        end

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

          scope = configuration.resolve_scope(
            key: @scope_key,
            controller: @controller,
            actor: @actor,
            device_key: @device_key
          )
          return failure_result(errors: ["Scope could not be resolved."], scope: scope) unless scope

          roots = available_roots_for(scope)
          root_recording = roots.find { |root| root.id.to_s == @root_recording_id.to_s }
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
            root_recording: root_recording,
            scope_key: scope.key
          )

          Current.scope = scope
          Current.scope_key = scope.key
          Current.selection = selection
          Current.root_recording = root_recording
          Current.root_recordable = root_recording.recordable

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

        def configuration
          RecordingStudioRootSwitchable.configuration
        end

        def available_roots_for(scope)
          scope.available_roots_for(controller: @controller, actor: @actor, device_key: @device_key)
               .select do |root_recording|
            scope.valid?(controller: @controller, actor: @actor, device_key: @device_key, recording: root_recording) &&
              scope.allowed?(controller: @controller, actor: @actor, device_key: @device_key, recording: root_recording)
          end
        end

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
