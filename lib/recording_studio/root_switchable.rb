# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    class << self
      def table_name_prefix
        "recording_studio_root_switchable_"
      end

      def configuration
        RecordingStudioRootSwitchable.configuration
      end

      def current_root
        Current.root_recording
      end
      alias current_root_recording current_root

      def current_root_recordable
        Current.root_recordable
      end

      def current_root_scope_key
        Current.scope_key
      end

      def current_device_key
        Current.device_key
      end

      def resolve_current_root(...)
        Services::ResolveCurrentRoot.call(...)
      end

      def switch_root(...)
        Services::SwitchRoot.call(...)
      end
    end
  end
end
