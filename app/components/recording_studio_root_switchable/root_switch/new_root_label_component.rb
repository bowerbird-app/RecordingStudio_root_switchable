# frozen_string_literal: true

module RecordingStudioRootSwitchable
  module RootSwitch
    class NewRootLabelComponent < ViewComponent::Base
      def initialize(label:, icon:)
        super()
        @label = label
        @icon = icon
      end

      def call
        safe_join([icon_node, content_tag(:span, label, class: "flex-1")].compact)
      end

      private

      attr_reader :label, :icon

      def icon_node
        return if icon.blank?

        render(FlatPack::Shared::IconComponent.new(name: icon.to_s, size: :sm))
      end
    end
  end
end
