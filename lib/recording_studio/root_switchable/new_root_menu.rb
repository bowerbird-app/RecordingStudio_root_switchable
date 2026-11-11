# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    # The switcher row for creating a root. One type links to the gate.
    # Several types open a modal and keep a no-JS picker page.
    class NewRootMenu
      Choice = NewRootChoice
      Offer = NewRootOffer

      def self.build(scope:, arguments:, controller:)
        new(scope, arguments, controller).build
      end

      def self.page_choices(scope:, arguments:, controller:)
        new(scope, arguments, controller).page_choices
      end

      def initialize(scope, arguments, controller)
        @scope = scope
        @arguments = arguments
        @controller = controller
      end

      def build
        return direct_offer if catalog.direct_legacy?
        return if choices.empty?
        return single_offer(choices.first) if choices.one?

        many_offer
      end

      def page_choices
        return [] if catalog.direct_legacy?

        choices
      end

      private

      attr_reader :scope, :arguments, :controller

      def catalog
        scope.creatable_catalog
      end

      def choices
        @choices ||= catalog.presented(arguments, mode: :display).map { |item| choice_for(item) }
      end

      def choice_for(item)
        Choice.new(
          label: item.label,
          icon: item.icon,
          description: item.description,
          href: item.disabled? ? nil : gate_path(item.type_name),
          disabled_reason: item.disabled_reason
        )
      end

      def direct_offer
        path = scope.new_root_path_for(**arguments)
        return if path.blank?

        offer(label: scope.new_root_label_for(**arguments), icon: scope.new_root_icon_for(**arguments), href: path)
      end

      def single_offer(choice)
        return disabled_offer(choice) if choice.disabled?

        offer(label: choice.label, icon: choice.icon, href: choice.href)
      end

      def disabled_offer(choice)
        offer(label: choice.label, icon: choice.icon, disabled_reason: choice.disabled_reason)
      end

      def many_offer
        offer(
          label: menu_label,
          icon: "plus",
          picker_path: picker_path,
          modal_id: "recording-studio-new-root-#{scope.key}",
          choices: choices,
          picker_title: picker_title
        )
      end

      def offer(**attrs)
        Offer.new(
          icon: nil, href: nil, picker_path: nil, modal_id: nil,
          choices: [], disabled_reason: nil, picker_title: nil,
          **attrs
        )
      end

      def picker_title
        RecordingStudioRootSwitchable.configuration.page_copy_for(scope: scope).fetch(:new_root_picker_title)
      end

      def menu_label
        I18n.t("recording_studio.root_switchable.dropdown.new_root_menu", default: "New…")
      end

      def gate_path(type_name)
        NewRootRoutes.gate(controller, scope_key: scope.key, type: type_name, return_to: arguments[:return_to])
      end

      def picker_path
        NewRootRoutes.picker(controller, scope_key: scope.key, return_to: arguments[:return_to])
      end
    end

    module NewRootRoutes
      module_function

      def gate(controller, scope_key:, type:, return_to:)
        invoke(controller, :new_root_path, route_params(scope_key, return_to).merge(type: type))
      end

      def picker(controller, scope_key:, return_to:)
        invoke(controller, :new_roots_path, route_params(scope_key, return_to))
      end

      def route_params(scope_key, return_to)
        params = { scope: scope_key }
        params[:return_to] = return_to if return_to.present?
        params
      end

      def invoke(controller, name, params)
        proxy = controller.recording_studio_root_switchable if controller.respond_to?(:recording_studio_root_switchable)
        target = proxy.respond_to?(name) ? proxy : controller
        target.public_send(name, **params)
      end
    end
  end
end
