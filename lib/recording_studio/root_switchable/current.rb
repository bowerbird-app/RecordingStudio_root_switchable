# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    class Current < ActiveSupport::CurrentAttributes
      attribute :actor, :device_key, :root_recordable, :root_recording, :scope, :scope_key, :selection

      def root
        root_recording
      end

      def root=(value)
        self.root_recording = value
      end
    end
  end
end
