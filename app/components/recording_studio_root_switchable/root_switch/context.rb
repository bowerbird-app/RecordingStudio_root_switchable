# frozen_string_literal: true

module RecordingStudioRootSwitchable
  module RootSwitch
    # Reads the request's resolved scope. Accessible roots come from that
    # resolution, which already ran ScopeContext and RecordingStudioAccessible.
    class Context
      def initialize(controller:, return_to:, form_action_for:, none_selected_label:, new_root: nil)
        @controller = controller
        @return_to = return_to
        @form_action_for = form_action_for
        @none_selected_label = none_selected_label
        @new_root = new_root
      end

      def menu_rows
        resolution = supported_resolution
        return if resolution.blank?

        MenuRows.build(
          entries: entries_for(resolution),
          selected: selected_for(resolution),
          form_action: form_action_for.call(resolution.scope),
          return_to: return_to,
          options: menu_options(resolution)
        )
      end

      private

      attr_reader :controller, :return_to, :form_action_for, :none_selected_label, :new_root

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

      def menu_options(resolution)
        MenuRows::Options.new(
          none_selected_label: none_selected_label,
          new_root_path: resolved_new_root_path(resolution),
          new_root_label: resolved_new_root_label(resolution),
          new_root_icon: resolved_new_root_icon(resolution)
        )
      end

      def resolved_new_root_path(resolution)
        return if new_root&.path == false

        arguments = hook_arguments(resolution)
        return resolution.scope.new_root_path_for(**arguments) if new_root.nil? || new_root.path.nil?

        raw = call_override(new_root.path, arguments)
        RecordingStudioRootSwitchable::RedirectSanitizer.with_return_to(raw, arguments[:return_to])
      end

      def resolved_new_root_label(resolution)
        arguments = hook_arguments(resolution)
        fallback = new_root_label_fallback(resolution)
        return scope_new_root_label(resolution, arguments, fallback) if new_root.nil? || new_root.label.nil?

        call_override(new_root.label, arguments).presence || fallback
      end

      def scope_new_root_label(resolution, arguments, fallback)
        resolution.scope.new_root_label_for(**arguments, fallback: fallback)
      end

      def resolved_new_root_icon(resolution)
        arguments = hook_arguments(resolution)
        fallback = new_root_icon_fallback(resolution)
        icon = new_root&.icon
        return resolution.scope.new_root_icon_for(**arguments, fallback: fallback) if icon.nil?

        resolution.scope.new_root_icon_for(**arguments, fallback: fallback, override: call_override(icon, arguments))
      end

      def new_root_icon_fallback(resolution)
        RecordingStudioRootSwitchable.configuration.page_copy_for(scope: resolution.scope)[:new_root_action_icon]
      end

      def new_root_label_fallback(resolution)
        RecordingStudioRootSwitchable.configuration.page_copy_for(scope: resolution.scope)[:new_root_action_label]
      end

      def hook_arguments(resolution)
        {
          controller: controller,
          actor: RecordingStudio::RootSwitchable::Current.actor,
          device_key: device_key,
          scope: resolution.scope,
          current_root_recording: resolution.root_recording,
          return_to: RecordingStudioRootSwitchable::RedirectSanitizer.sanitize(return_to)
        }
      end

      def call_override(value, arguments)
        return value unless value.respond_to?(:call)

        value.call(**arguments)
      rescue StandardError
        nil
      end
    end
  end
end
