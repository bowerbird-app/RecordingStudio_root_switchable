# frozen_string_literal: true

module RecordingStudioRootSwitchable
  module RootSwitch
    # Switch forms shared by the dropdown menu and the collapsed list.
    class RowsComponent < ViewComponent::Base
      ITEM_CLASSES = [
        "flex items-center gap-[var(--dropdown-item-gap)]",
        "w-full",
        "px-[var(--dropdown-item-padding-x)] py-[var(--dropdown-item-padding-y)]",
        "text-sm text-left",
        "rounded-[var(--dropdown-item-radius)]",
        "text-[var(--surface-content-color)]",
        "hover:bg-[var(--surface-muted-background-color)]",
        "cursor-pointer",
        "transition-colors duration-base",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring"
      ].join(" ").freeze

      def initialize(menu_rows:)
        super()
        @menu_rows = menu_rows
      end

      attr_reader :menu_rows

      def item_classes
        ITEM_CLASSES
      end
    end
  end
end
