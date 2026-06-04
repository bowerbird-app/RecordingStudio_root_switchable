# frozen_string_literal: true

module RecordingStudioRootSwitchable
  # rubocop:disable Metrics/ModuleLength
  module RootSwitchDropdownHelper
    def recording_studio_root_switch_dropdown(return_to: nil, trigger_attributes: {}, **system_arguments)
      root_switch_dropdown = recording_studio_root_switch_dropdown_data(return_to: return_to)
      return if root_switch_dropdown.blank?

      render("recording_studio_root_switchable/root_switch_dropdown",
             **recording_studio_root_switch_dropdown_render_arguments(
               root_switch_dropdown: root_switch_dropdown,
               trigger_attributes: trigger_attributes,
               system_arguments: system_arguments
             ))
    end

    private

    def recording_studio_root_switch_dropdown_data(return_to: nil)
      dropdown_state = recording_studio_root_switch_dropdown_state
      return if dropdown_state.blank?

      recording_studio_root_switch_dropdown_payload(**dropdown_state, return_to: return_to)
    end

    def recording_studio_root_switch_dropdown_render_arguments(
      root_switch_dropdown:,
      trigger_attributes:,
      system_arguments:
    )
      arguments = system_arguments.dup

      {
        root_switch_dropdown: root_switch_dropdown,
        style: arguments.delete(:style) || :default,
        size: arguments.delete(:size) || :md,
        position: arguments.delete(:position) || :bottom_right,
        max_height: arguments.delete(:max_height) || "384px",
        trigger_attributes: trigger_attributes,
        system_arguments: arguments
      }
    end

    def recording_studio_root_switch_dropdown_supported_resolution
      resolution = recording_studio_root_switch_dropdown_resolution if respond_to?(:recording_studio_root_switchable)
      resolution if resolution.present? && resolution.scope.present?
    end

    def recording_studio_root_switch_dropdown_state
      resolution = recording_studio_root_switch_dropdown_supported_resolution
      return if resolution.blank?

      roots = Array(resolution.available_roots)
      selected = resolution.root_recording
      return if selected.blank? && roots.empty?

      { resolution: resolution, roots: roots, selected: selected }
    end

    def recording_studio_root_switch_dropdown_payload(
      resolution:,
      roots:,
      return_to:,
      selected:
    )
      scope = resolution.scope
      items = recording_studio_root_switch_dropdown_items_for(roots: roots, scope: scope, selected: selected)

      {
        current_label: recording_studio_root_switch_dropdown_label(scope: scope, root_recording: selected),
        form_action: recording_studio_root_switch_dropdown_form_action(scope),
        items: items,
        return_to: recording_studio_root_switch_dropdown_return_to(return_to)
      }
    end

    def recording_studio_root_switch_dropdown_items_for(roots:, scope:, selected:)
      roots.filter_map do |root_recording|
        next if selected&.id == root_recording.id

        recording_studio_root_switch_dropdown_item(
          root_recording: root_recording,
          scope: scope,
          scope_key: scope.key
        )
      end
    end

    def recording_studio_root_switch_dropdown_item(root_recording:, scope:, scope_key:)
      form_id = recording_studio_root_switch_dropdown_form_id(
        scope_key: scope_key,
        root_recording_id: root_recording.id
      )
      label = recording_studio_root_switch_dropdown_label(scope: scope, root_recording: root_recording)

      {
        form_id: form_id,
        label: label,
        root_recording_id: root_recording.id
      }
    end

    def recording_studio_root_switch_dropdown_return_to(return_to)
      return_to.presence || request&.fullpath
    end

    def recording_studio_root_switch_dropdown_form_action(scope)
      recording_studio_root_switchable.root_switch_path(scope: scope.key)
    end

    def recording_studio_root_switch_dropdown_resolution
      controller.send(:current_root_resolution) if controller.respond_to?(:current_root_resolution, true)
    end

    def recording_studio_root_switch_dropdown_label(scope:, root_recording:)
      return "None selected" if root_recording.blank?

      scope.root_label_for(
        controller: controller,
        actor: RecordingStudio::RootSwitchable::Current.actor,
        device_key: current_root_device_key,
        recording: root_recording
      )
    end

    def recording_studio_root_switch_dropdown_form_id(scope_key:, root_recording_id:)
      ["root-switch-dropdown", scope_key, root_recording_id].join("-")
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
