# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    module Services
      module CurrentAssignment
        module_function

        def apply(scope:, root_recording:, selection:)
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
