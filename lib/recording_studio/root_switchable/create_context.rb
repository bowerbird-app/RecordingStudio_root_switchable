# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    # Passed to before_root_create. mode is :display or :gate.
    class CreateContext
      Request = Data.define(:controller, :return_to, :mode)

      attr_reader :actor, :scope_key, :root_type, :current_root_recording,
                  :controller, :return_to, :mode

      def initialize(actor:, scope_key:, root_type:, current_root_recording:, request:)
        @actor = actor
        @scope_key = scope_key
        @root_type = root_type
        @current_root_recording = current_root_recording
        @controller = request.controller
        @return_to = request.return_to
        @mode = request.mode
        freeze
      end

      def display?
        mode == :display
      end

      def gate?
        mode == :gate
      end
    end
  end
end
