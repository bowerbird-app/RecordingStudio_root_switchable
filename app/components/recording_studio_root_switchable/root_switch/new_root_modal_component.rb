# frozen_string_literal: true

module RecordingStudioRootSwitchable
  module RootSwitch
    class NewRootModalComponent < ViewComponent::Base
      def initialize(offer:)
        super()
        @offer = offer
      end

      def call
        render(FlatPack::Modal::Component.new(id: offer.modal_id, title: offer.picker_title, size: :md)) do |modal|
          modal.body { render(NewRootChoicesComponent.new(choices: offer.choices)) }
        end
      end

      private

      attr_reader :offer
    end
  end
end
