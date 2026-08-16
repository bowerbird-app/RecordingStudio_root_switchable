# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    module RootId
      module_function

      def same?(left, right)
        return false if left.nil? || right.nil?

        left.to_s == right.to_s
      end

      def find_in(roots, root_recording_id)
        Array(roots).find { |root| same?(root.id, root_recording_id) }
      end
    end
  end
end
