# frozen_string_literal: true

module RecordingStudioRootSwitchable
  module RootSwitchHelper
    def recording_studio_new_root_path(scope: nil, return_to: nil)
      resolved_scope = scope || recording_studio_root_switch_scope
      return if resolved_scope.blank?

      resolved_scope.new_root_path_for(
        **recording_studio_new_root_context(return_to: return_to),
        scope: resolved_scope
      )
    end

    def recording_studio_root_switch_for(return_to: nil, new_root_path: nil, new_root_label: nil, **system_arguments)
      menu_rows = recording_studio_root_switch_menu_rows(
        return_to: return_to,
        new_root_path: new_root_path,
        new_root_label: new_root_label
      )
      return if menu_rows.blank?

      RootSwitch::DropdownComponent.new(menu_rows: menu_rows, **system_arguments)
    end

    def recording_studio_root_switch_dropdown(
      return_to: nil,
      new_root_path: nil,
      new_root_label: nil,
      **system_arguments
    )
      component = recording_studio_root_switch_for(
        return_to: return_to,
        new_root_path: new_root_path,
        new_root_label: new_root_label,
        **system_arguments
      )
      render(component) if component
    end

    def recording_studio_root_switch_list_for(return_to: nil, new_root_path: nil, new_root_label: nil)
      menu_rows = recording_studio_root_switch_menu_rows(
        return_to: return_to,
        new_root_path: new_root_path,
        new_root_label: new_root_label
      )
      return if menu_rows.blank?

      RootSwitch::ListComponent.new(menu_rows: menu_rows)
    end

    def render_recording_studio_root_switch_list(return_to: nil, new_root_path: nil, new_root_label: nil)
      component = recording_studio_root_switch_list_for(
        return_to: return_to,
        new_root_path: new_root_path,
        new_root_label: new_root_label
      )
      render(component) if component
    end

    private

    def recording_studio_root_switch_menu_rows(return_to: nil, new_root_path: nil, new_root_label: nil)
      return unless recording_studio_root_switch_supported?

      RootSwitch::Context.new(
        controller: controller,
        return_to: return_to.presence || request&.fullpath,
        form_action_for: method(:recording_studio_root_switch_form_action),
        none_selected_label: t("recording_studio.root_switchable.dropdown.none_selected"),
        new_root: RootSwitch::MenuRows::Override.from(new_root_path, new_root_label)
      ).menu_rows
    end

    def recording_studio_root_switch_supported?
      controller.respond_to?(:current_root_resolution, true)
    end

    def recording_studio_root_switch_form_action(scope)
      recording_studio_root_switchable.root_switch_path(scope: scope.key)
    end

    def recording_studio_root_switch_scope
      return unless recording_studio_root_switch_supported?

      controller.current_root_resolution&.scope
    end

    def recording_studio_new_root_context(return_to: nil)
      safe_return = RecordingStudioRootSwitchable::RedirectSanitizer.sanitize(return_to.presence || request&.fullpath)
      current_root = controller.current_root_recording if controller.respond_to?(:current_root_recording)
      {
        controller: controller,
        actor: RecordingStudio::RootSwitchable::Current.actor,
        device_key: recording_studio_new_root_device_key,
        current_root_recording: current_root,
        return_to: safe_return
      }
    end

    def recording_studio_new_root_device_key
      return unless controller.respond_to?(:current_root_device_key, true)

      controller.current_root_device_key
    end
  end
end
