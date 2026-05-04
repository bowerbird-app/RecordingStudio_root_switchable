# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    module ControllerSupport
      extend ActiveSupport::Concern

      included do
        before_action :resolve_recording_studio_root_switchable_current

        helper_method :current_root,
                      :current_root_device_key,
                      :current_root_recordable,
                      :current_root_recording,
                      :current_root_scope_key
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

      def current_root_resolution
        @current_root_resolution ||= RecordingStudio::RootSwitchable::Services::ResolveCurrentRoot.call(
          controller: self,
          actor: RecordingStudio::RootSwitchable::Current.actor,
          device_key: RecordingStudio::RootSwitchable::Current.device_key,
          scope_key: recording_studio_root_switchable_scope_key
        )
      end

      private

      def resolve_recording_studio_root_switchable_current
        RecordingStudio::RootSwitchable::Current.actor =
          RecordingStudioRootSwitchable.configuration.current_actor_for(controller: self)
        RecordingStudio::RootSwitchable::Current.device_key =
          RecordingStudio::RootSwitchable::DeviceKey.fetch(controller: self)

        @current_root_resolution = RecordingStudio::RootSwitchable::Services::ResolveCurrentRoot.call(
          controller: self,
          actor: RecordingStudio::RootSwitchable::Current.actor,
          device_key: RecordingStudio::RootSwitchable::Current.device_key,
          scope_key: recording_studio_root_switchable_scope_key
        )
      end

      def recording_studio_root_switchable_scope_key
        params[:scope].presence || params[:scope_key].presence
      end
    end
  end
end
