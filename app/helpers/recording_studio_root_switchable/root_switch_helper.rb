# frozen_string_literal: true

module RecordingStudioRootSwitchable
  module RootSwitchHelper
    def recording_studio_root_switch_for(return_to: nil, **system_arguments)
      menu_rows = recording_studio_root_switch_menu_rows(return_to: return_to)
      return if menu_rows.blank?

      RootSwitch::DropdownComponent.new(menu_rows: menu_rows, **system_arguments)
    end

    def recording_studio_root_switch_dropdown(return_to: nil, **system_arguments)
      component = recording_studio_root_switch_for(return_to: return_to, **system_arguments)
      render(component) if component
    end

    def recording_studio_root_switch_list_for(return_to: nil)
      menu_rows = recording_studio_root_switch_menu_rows(return_to: return_to)
      return if menu_rows.blank?

      RootSwitch::ListComponent.new(menu_rows: menu_rows)
    end

    def render_recording_studio_root_switch_list(return_to: nil)
      component = recording_studio_root_switch_list_for(return_to: return_to)
      render(component) if component
    end

    private

    def recording_studio_root_switch_menu_rows(return_to: nil)
      return unless recording_studio_root_switch_supported?

      RootSwitch::Context.new(
        controller: controller,
        return_to: return_to.presence || request&.fullpath,
        form_action_for: method(:recording_studio_root_switch_form_action),
        none_selected_label: t("recording_studio.root_switchable.dropdown.none_selected")
      ).menu_rows
    end

    def recording_studio_root_switch_supported?
      controller.respond_to?(:current_root_resolution, true)
    end

    def recording_studio_root_switch_form_action(scope)
      recording_studio_root_switchable.root_switch_path(scope: scope.key)
    end
  end
end
