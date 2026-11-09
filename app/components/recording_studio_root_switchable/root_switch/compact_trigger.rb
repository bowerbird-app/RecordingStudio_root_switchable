# frozen_string_literal: true

module RecordingStudioRootSwitchable
  module RootSwitch
    # Compact trigger initials and the allowed `compact:` values.
    class CompactTrigger
      MODES = [nil, :below_md, :always].freeze
      FALLBACK_ICON = "building-office-2"

      def self.normalize!(value)
        return nil if value.nil?

        mode = value.is_a?(String) ? value.to_sym : value
        return mode if MODES.include?(mode)

        raise ArgumentError,
              "Invalid compact: #{value.inspect}. Must be nil, :below_md, or :always."
      end

      def self.initials(name)
        words = name.to_s.scan(/[[:alpha:][:digit:]]+/)
        return if words.empty?
        return words.first.chars.first(2).join.upcase if words.one?

        words.first(2).map { |word| word[0] }.join.upcase
      end
    end
  end
end
