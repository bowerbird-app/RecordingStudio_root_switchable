# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    # Runs before_root_create before a host new or create action.
    module GuardsRootCreation
      extend ActiveSupport::Concern

      class_methods do
        def guard_root_creation!(scope:, type:, only: nil)
          before_action(only: only) do
            recording_studio_guard_root_creation!(scope_key: scope, type_name: type)
          end
        end
      end

      def recording_studio_guard_root_creation!(scope_key:, type_name:)
        scope = creatable_scope(scope_key)
        return head(:not_found) unless scope

        outcome = CreateGate.call(
          scope: scope,
          type_name: type_name_for(type_name),
          arguments: creation_arguments(scope),
          fallback_location: creation_fallback(scope)
        )
        apply_creation_outcome(outcome)
      end

      private

      def creatable_scope(scope_key)
        scope = RecordingStudioRootSwitchable.configuration.scopes[scope_key.to_s]
        return unless scope
        return unless scope.supported?(controller: self, actor: creation_actor, device_key: creation_device_key)

        scope
      end

      def apply_creation_outcome(outcome)
        return if outcome.allow?
        return head(:not_found) if outcome.missing?

        redirect_to outcome.location, alert: outcome.reason
      end

      def creation_arguments(scope)
        {
          controller: self,
          actor: creation_actor,
          device_key: creation_device_key,
          scope: scope,
          current_root_recording: creation_current_root,
          return_to: creation_return_to
        }
      end

      def creation_actor
        RecordingStudio::RootSwitchable::Current.actor
      end

      def creation_device_key
        RecordingStudio::RootSwitchable::Current.device_key
      end

      def creation_current_root
        return unless respond_to?(:current_root_recording, true)

        current_root_recording
      end

      def creation_return_to
        RecordingStudioRootSwitchable::RedirectSanitizer.sanitize(params[:return_to])
      end

      def creation_fallback(scope)
        recording_studio_root_switchable.root_switch_path(scope: scope.key)
      rescue StandardError
        "/"
      end

      def type_name_for(type)
        type.is_a?(Class) ? type.name : type.to_s
      end
    end
  end
end
