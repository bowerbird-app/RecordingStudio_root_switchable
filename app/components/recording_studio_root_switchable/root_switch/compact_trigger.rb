# frozen_string_literal: true

module RecordingStudioRootSwitchable
  module RootSwitch
    # Compact trigger initials and the allowed `compact:` values.
    class CompactTrigger
      MODES = [nil, :below_md, :always].freeze
      FALLBACK_ICON = "building-office-2"
      DEFAULT_BADGE_SIZE = :sm

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

      def self.normalize_badge_size!(value)
        size = value.nil? ? DEFAULT_BADGE_SIZE : coerce_size(value)
        FlatPack::Avatar::Component.new(size: size, show_tooltip: false)
        size
      rescue ArgumentError
        keys = FlatPack::Avatar::Component::SIZES.keys.map(&:inspect).join(", ")
        raise ArgumentError, "Invalid badge_size: #{value.inspect}. Must be one of: #{keys}"
      end

      def self.coerce_size(value)
        value.is_a?(String) ? value.to_sym : value
      end
      private_class_method :coerce_size
    end
  end
end
