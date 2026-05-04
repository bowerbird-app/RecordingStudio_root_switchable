# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    class Current < ActiveSupport::CurrentAttributes
      attribute :actor, :device_key, :root_recordable, :root_recording, :scope, :scope_key, :selection
    end
  end
end
