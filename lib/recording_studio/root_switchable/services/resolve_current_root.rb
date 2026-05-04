# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    module Services
      class ResolveCurrentRoot
        class << self
          def call(...)
            new(...).call
          end
        end

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

          if selection && roots.any? { |root| root.id == selection.root_recording_id }
            root_recording = roots.find { |root| root.id == selection.root_recording_id }
            selection.update_columns(last_used_at: Time.current) if selection.respond_to?(:update_columns)
            selected_via = :persisted
          elsif selection
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

        def configuration
          RecordingStudioRootSwitchable.configuration
        end

        def scope_context
          @scope_context ||= ScopeContext.new(
            configuration: configuration,
            controller: @controller,
            actor: @actor,
            device_key: @device_key,
            scope_key: @scope_key
          )
        end

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

          RecordingStudio::RootSwitchable::Selection.lookup(
            actor: @actor,
            device_key: @device_key,
            scope_key: scope.key
          )
        end

        def assign_current(scope:, root_recording:, selection:)
          Current.scope = scope
          Current.scope_key = scope&.key
          Current.selection = selection
          Current.root_recording = root_recording
          Current.root_recordable = root_recording&.recordable
        end
      end
    end
  end
end
