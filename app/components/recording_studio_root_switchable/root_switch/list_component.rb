# frozen_string_literal: true

module RecordingStudioRootSwitchable
  module RootSwitch
    # Workspace rows inside a host dropdown, collapsed to the current workspace.
    class ListComponent < ViewComponent::Base
      def initialize(menu_rows:)
        super()
        @menu_rows = menu_rows
      end

      attr_reader :menu_rows
    end
  end
end
