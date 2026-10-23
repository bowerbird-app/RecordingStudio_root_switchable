# frozen_string_literal: true

module RootSwitchPlacements
  # FlatPack dropdown slots accept a link or a bare button. The workspace list
  # is a collapse with its own forms, so the menu body is rendered HTML.
  class Menu < FlatPack::Button::Dropdown::Component
    def initialize(menu_html:, **)
      @menu_html = menu_html
      super(**)
    end

    def call
      content_tag(:div, **wrapper_attributes) do
        safe_join([
          content_tag(:button, button_content, **trigger_attributes),
          content_tag(:div, @menu_html, **menu_attributes)
        ])
      end
    end

    private

    def trigger_attributes
      attributes = button_attributes
      attributes[:type] = "button"
      attributes[:disabled] = true if @disabled
      attributes
    end
  end
end
