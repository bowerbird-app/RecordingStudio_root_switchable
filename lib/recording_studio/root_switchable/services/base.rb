# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    module Services
      class Base
        class << self
          def call(...)
            new(...).call
          end
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

        def assign_current(scope:, root_recording:, selection:)
          CurrentAssignment.apply(
            scope: scope,
            root_recording: root_recording,
            selection: selection
          )
        end
      end
    end
  end
end
