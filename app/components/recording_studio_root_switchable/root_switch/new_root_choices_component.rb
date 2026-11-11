# frozen_string_literal: true

module RecordingStudioRootSwitchable
  module RootSwitch
    class NewRootChoicesComponent < ViewComponent::Base
      def initialize(choices:)
        super()
        @choices = choices
      end

      def call
        render(FlatPack::List::Component.new(class: "w-full")) do
          safe_join(choices.map { |choice| item_for(choice) })
        end
      end

      private

      attr_reader :choices

      def item_for(choice)
        render(FlatPack::List::Item.new(hover: !choice.disabled?)) do
          choice.disabled? ? disabled_choice(choice) : linked_choice(choice)
        end
      end

      def linked_choice(choice)
        link_to(choice.href, class: "flex w-full items-start gap-3") do
          choice_body(choice)
        end
      end

      def disabled_choice(choice)
        content_tag(
          :div,
          choice_body(choice),
          class: "flex w-full items-start gap-3 opacity-60",
          aria: { disabled: true }
        )
      end

      def choice_body(choice)
        safe_join([choice_icon(choice), choice_copy(choice)].compact)
      end

      def choice_icon(choice)
        return if choice.icon.blank?

        render(FlatPack::Shared::IconComponent.new(name: choice.icon.to_s, size: :sm))
      end

      def choice_copy(choice)
        content_tag(:div) do
          safe_join([
            content_tag(:div, choice.label, class: "font-semibold"),
            description_node(choice),
            reason_node(choice)
          ].compact)
        end
      end

      def description_node(choice)
        return if choice.description.blank?

        content_tag(:p, choice.description, class: "text-sm text-(--surface-muted-content-color)")
      end

      def reason_node(choice)
        return if choice.disabled_reason.blank?

        content_tag(:p, choice.disabled_reason, class: "text-sm text-(--surface-muted-content-color)")
      end
    end
  end
end
