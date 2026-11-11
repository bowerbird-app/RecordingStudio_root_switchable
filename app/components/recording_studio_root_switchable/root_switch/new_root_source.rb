# frozen_string_literal: true

module RecordingStudioRootSwitchable
  module RootSwitch
    # Builds the new-root row for one resolved scope.
    class NewRootSource
      def initialize(controller:, return_to:, new_root:, none_selected_label:, device_key:)
        @controller = controller
        @return_to = return_to
        @new_root = new_root
        @none_selected_label = none_selected_label
        @device_key = device_key
      end

      def options_for(resolution)
        arguments = hook_arguments(resolution)
        offer = resolved_offer(resolution, arguments)
        MenuRows::Options.new(
          none_selected_label: none_selected_label,
          new_root_path: option_path(offer, resolution, arguments),
          new_root_label: option_label(offer, resolution, arguments),
          new_root_icon: option_icon(offer, resolution, arguments),
          offer: offer
        )
      end

      private

      attr_reader :controller, :return_to, :new_root, :none_selected_label, :device_key

      def option_path(offer, resolution, arguments)
        return offer.href || offer.picker_path if offer

        resolved_path(resolution, arguments)
      end

      def option_label(offer, resolution, arguments)
        offer&.label || resolved_label(resolution, arguments)
      end

      def option_icon(offer, resolution, arguments)
        return offer.icon if offer

        resolved_icon(resolution, arguments)
      end

      def resolved_offer(resolution, arguments)
        return if skip_catalog?

        RecordingStudio::RootSwitchable::NewRootMenu.build(
          scope: resolution.scope,
          arguments: arguments,
          controller: controller
        )
      end

      def skip_catalog?
        return true if new_root&.path == false
        return false if new_root.nil?

        label_or_icon_override? || !new_root.path.nil?
      end

      def label_or_icon_override?
        !new_root.label.nil? || !new_root.icon.nil?
      end

      def resolved_path(resolution, arguments)
        return if new_root&.path == false
        return resolution.scope.new_root_path_for(**arguments) if new_root.nil? || new_root.path.nil?

        raw = call_override(new_root.path, arguments)
        RecordingStudioRootSwitchable::RedirectSanitizer.with_return_to(raw, arguments[:return_to])
      end

      def resolved_label(resolution, arguments)
        fallback = page_copy(resolution)[:new_root_action_label]
        return scope_label(resolution, arguments, fallback) if new_root.nil? || new_root.label.nil?

        call_override(new_root.label, arguments).presence || fallback
      end

      def scope_label(resolution, arguments, fallback)
        resolution.scope.new_root_label_for(**arguments, fallback: fallback)
      end

      def resolved_icon(resolution, arguments)
        fallback = page_copy(resolution)[:new_root_action_icon]
        icon = new_root&.icon
        return resolution.scope.new_root_icon_for(**arguments, fallback: fallback) if icon.nil?

        resolution.scope.new_root_icon_for(**arguments, fallback: fallback, override: call_override(icon, arguments))
      end

      def page_copy(resolution)
        RecordingStudioRootSwitchable.configuration.page_copy_for(scope: resolution.scope)
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
