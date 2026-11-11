# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    # One row inside the type picker.
    class NewRootChoice
      attr_reader :label, :icon, :description, :href, :disabled_reason

      def initialize(label:, icon:, description:, href:, disabled_reason:)
        @label = label
        @icon = icon
        @description = description
        @href = href
        @disabled_reason = disabled_reason
        freeze
      end

      def disabled?
        disabled_reason.present?
      end
    end

    # The switcher item. A modal id means several types. A blank href means disabled.
    class NewRootOffer
      attr_reader :label, :icon, :href, :picker_path, :modal_id, :choices, :disabled_reason, :picker_title

      def initialize(label:, **rest)
        @label = label
        @icon = rest[:icon]
        @href = rest[:href]
        @picker_path = rest[:picker_path]
        @modal_id = rest[:modal_id]
        @choices = rest.fetch(:choices) { [] }
        @disabled_reason = rest[:disabled_reason]
        @picker_title = rest[:picker_title]
        freeze
      end

      def modal?
        modal_id.present?
      end

      def link?
        href.present? && !modal? && disabled_reason.blank?
      end

      def disabled?
        disabled_reason.present? && !modal?
      end

      def visible?
        link? || modal? || disabled?
      end
    end
  end
end
