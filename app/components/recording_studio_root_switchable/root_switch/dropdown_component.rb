# frozen_string_literal: true

module RecordingStudioRootSwitchable
  module RootSwitch
    # FlatPack dropdown labelled with the current workspace.
    # The phone row for a collapsing button group is the same collapse hosts
    # drop into their own menu.
    class DropdownComponent < FlatPack::Button::Dropdown::Component
      def initialize(menu_rows:, **system_arguments)
        @menu_rows = menu_rows
        system_arguments.delete(:text)
        system_arguments.delete(:disabled)
        super(
          text: menu_rows.current_label,
          disabled: menu_rows.switch_rows.empty?,
          **system_arguments
        )
      end

      attr_reader :menu_rows

      def menu_row
        render(ListComponent.new(menu_rows: menu_rows))
      end
    end
  end
end
