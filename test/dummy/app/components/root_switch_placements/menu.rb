# frozen_string_literal: true

module RootSwitchPlacements
  # FlatPack dropdown slots accept a link or a bare button. The workspace list
  # is a collapse with its own forms, so the menu body is rendered HTML.
  class Menu < FlatPack::Button::Dropdown::Component
    def initialize(menu_html:, **)
      @rendered_menu = menu_html
      super(**)
    end

    def before_render
      menu_html(@rendered_menu)
      super
    end
  end
end
