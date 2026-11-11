# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    # Decides a create request. The gem redirects. It does not write a recording.
    class CreateGate
      Outcome = Data.define(:name, :location, :reason) do
        def allow?
          name == :allow
        end

        def refuse?
          name == :refuse
        end

        def missing?
          name == :missing
        end
      end

      def self.call(scope:, type_name:, arguments:, fallback_location:)
        new(scope, type_name, arguments, fallback_location).call
      end

      def initialize(scope, type_name, arguments, fallback_location)
        @scope = scope
        @type_name = type_name
        @arguments = arguments
        @fallback_location = fallback_location
      end

      def call
        presented = catalog.present_type(type_name, arguments, mode: :gate)
        return missing unless presented
        return refusal(presented) if presented.disabled?

        Outcome.new(name: :allow, location: presented.path, reason: nil)
      end

      private

      attr_reader :scope, :type_name, :arguments, :fallback_location

      def catalog
        scope.creatable_catalog
      end

      def missing
        Outcome.new(name: :missing, location: nil, reason: nil)
      end

      def refusal(presented)
        Outcome.new(
          name: :refuse,
          location: safe_location(presented.decision.redirect_to),
          reason: presented.disabled_reason
        )
      end

      def safe_location(redirect_to)
        sanitize(redirect_to) || sanitize(arguments[:return_to]) || fallback_location
      end

      def sanitize(target)
        RecordingStudioRootSwitchable::RedirectSanitizer.sanitize(target)
      end
    end
  end
end
