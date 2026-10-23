# frozen_string_literal: true

module RecordingStudioRootSwitchable
  module RootSwitch
    # Reads the request's resolved scope. Accessible roots come from that
    # resolution, which already ran ScopeContext and RecordingStudioAccessible.
    class Context
      def initialize(controller:, return_to:, form_action_for:, none_selected_label:)
        @controller = controller
        @return_to = return_to
        @form_action_for = form_action_for
        @none_selected_label = none_selected_label
      end

      def menu_rows
        resolution = supported_resolution
        return if resolution.blank?

        MenuRows.build(
          entries: entries_for(resolution),
          selected: selected_for(resolution),
          form_action: form_action_for.call(resolution.scope),
          return_to: return_to,
          none_selected_label: none_selected_label
        )
      end

      private

      attr_reader :controller, :return_to, :form_action_for, :none_selected_label

      def supported_resolution
        return unless controller.respond_to?(:current_root_resolution, true)

        resolution = controller.current_root_resolution
        resolution if resolution.present? && resolution.scope.present?
      end

      def entries_for(resolution)
        Array(resolution.available_roots).map do |root_recording|
          { id: root_recording.id, label: label_for(resolution.scope, root_recording) }
        end
      end

      def selected_for(resolution)
        recording = resolution.root_recording
        return if recording.blank?

        { id: recording.id, label: label_for(resolution.scope, recording) }
      end

      def label_for(scope, root_recording)
        scope.root_label_for(
          controller: controller,
          actor: RecordingStudio::RootSwitchable::Current.actor,
          device_key: device_key,
          recording: root_recording
        )
      end

      def device_key
        return unless controller.respond_to?(:current_root_device_key, true)

        controller.current_root_device_key
      end
    end
  end
end
