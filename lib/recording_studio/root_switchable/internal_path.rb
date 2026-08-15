# frozen_string_literal: true

require "cgi"
require "uri"

module RecordingStudio
  module RootSwitchable
    module InternalPath
      module_function

      # Accepts only same-origin relative paths. Rejects protocol-relative URLs,
      # absolute URLs, backslash tricks, and other open-redirect patterns.
      def sanitize(target)
        return if target.blank?

        candidate = target.to_s.strip
        return unless candidate.start_with?("/")
        return if unsafe_relative_path?(candidate)

        decoded = CGI.unescape(candidate)
        return if unsafe_relative_path?(decoded)

        parsed = URI.parse(candidate)
        return if parsed.scheme.present? || parsed.host.present?
        return if parsed.opaque.present?

        candidate
      rescue URI::InvalidURIError
        nil
      end

      def unsafe_relative_path?(value)
        value.start_with?("//") ||
          value.include?("\\") ||
          value.match?(%r{\A/\\}) ||
          value.match?(%r{\A/%2f}i)
      end
      private_class_method :unsafe_relative_path?
    end
  end
end
