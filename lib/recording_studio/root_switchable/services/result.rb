# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    module Services
      class Result
        attr_reader :available_roots, :errors, :root_recording, :scope, :selected_via, :selection

        def initialize(scope:, root_recording:, selection:, available_roots:, selected_via:, errors: [])
          @scope = scope
          @root_recording = root_recording
          @selection = selection
          @available_roots = available_roots
          @selected_via = selected_via
          @errors = Array(errors).compact
        end

        def success?
          errors.empty?
        end

        def root_recordable
          root_recording&.recordable
        end
      end
    end
  end
end
