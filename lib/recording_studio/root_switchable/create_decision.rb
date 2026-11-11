# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    # What a before_root_create hook returns. nil from the hook means allow.
    class CreateDecision
      attr_reader :redirect_to, :reason

      def self.allow
        new(:allow)
      end

      def self.hide
        new(:hide)
      end

      def self.refuse(redirect_to:, reason: nil)
        new(:refuse, redirect_to: redirect_to, reason: reason)
      end

      def initialize(outcome, redirect_to: nil, reason: nil)
        @outcome = outcome
        @redirect_to = redirect_to
        @reason = reason
        freeze
      end

      def allow?
        @outcome == :allow
      end

      def hide?
        @outcome == :hide
      end

      def refuse?
        @outcome == :refuse
      end
    end
  end
end
