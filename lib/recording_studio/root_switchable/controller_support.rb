# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    module ControllerSupport
      extend ActiveSupport::Concern

      included do
        before_action :resolve_recording_studio_root_switchable_current

        helper_method :current_root,
                      :current_root_device_key,
                      :current_root_device_key_preview,
                      :current_root_recordable,
                      :current_root_recording,
                      :current_root_scope_key
      end

      class_methods do
        # Skip the automatic per-request root resolution for specific actions.
        # Example: skip_recording_studio_root_resolution only: %i[health]
        def skip_recording_studio_root_resolution(**options)
          skip_before_action :resolve_recording_studio_root_switchable_current, **options
        end
      end

      def current_root
        RecordingStudio::RootSwitchable.current_root
      end

      def current_root_recording
        RecordingStudio::RootSwitchable.current_root_recording
      end

      def current_root_recordable
        RecordingStudio::RootSwitchable.current_root_recordable
      end

      def current_root_scope_key
        RecordingStudio::RootSwitchable.current_root_scope_key
      end

      def current_root_device_key
        RecordingStudio::RootSwitchable.current_device_key
      end

      def current_root_device_key_preview
        DeviceKeyPreview.format(current_root_device_key)
      end

      def recording_studio_switch_to_root!(root_recording, scope:)
        scope_key = scope.respond_to?(:key) ? scope.key : scope.to_s
        return recording_studio_switch_rate_limited(scope_key) unless recording_studio_switch_allowed?

        RecordingStudio::RootSwitchable.switch_root(
          controller: self,
          actor: RecordingStudio::RootSwitchable::Current.actor,
          device_key: RecordingStudio::RootSwitchable::Current.device_key,
          root_recording_id: root_recording&.id,
          scope_key: scope_key
        )
      end

      def current_root_resolution
        @current_root_resolution ||= RecordingStudio::RootSwitchable::Services::ResolveCurrentRoot.call(
          controller: self,
          actor: RecordingStudio::RootSwitchable::Current.actor,
          device_key: RecordingStudio::RootSwitchable::Current.device_key,
          scope_key: recording_studio_root_switchable_scope_key
        )
      end

      private

      def recording_studio_switch_allowed?
        RecordingStudioRootSwitchable::SwitchRateLimiter.allowed?(
          actor: RecordingStudio::RootSwitchable::Current.actor,
          device_key: RecordingStudio::RootSwitchable::Current.device_key
        )
      end

      def recording_studio_switch_rate_limited(scope_key)
        Services::Result.new(
          available_roots: [],
          errors: ["Too many switches. Wait a minute and try again."],
          root_recording: Current.root_recording,
          scope: RecordingStudioRootSwitchable.configuration.scopes[scope_key],
          selected_via: :none,
          selection: Current.selection
        )
      end

      def resolve_recording_studio_root_switchable_current
        RecordingStudio::RootSwitchable::Current.actor =
          RecordingStudioRootSwitchable.configuration.current_actor_for(controller: self)
        RecordingStudio::RootSwitchable::Current.device_key = fetch_recording_studio_device_key

        @current_root_resolution = RecordingStudio::RootSwitchable::Services::ResolveCurrentRoot.call(
          controller: self,
          actor: RecordingStudio::RootSwitchable::Current.actor,
          device_key: RecordingStudio::RootSwitchable::Current.device_key,
          scope_key: recording_studio_root_switchable_scope_key
        )
      end

      def fetch_recording_studio_device_key
        RecordingStudio::RootSwitchable::DeviceKey.fetch(controller: self)
      rescue RecordingStudio::RootSwitchable::DeviceKey::Unavailable
        nil
      end

      def recording_studio_root_switchable_scope_key
        params[:scope].presence || params[:scope_key].presence
      end
    end
  end
end
