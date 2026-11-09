# frozen_string_literal: true

module RecordingStudioRootSwitchable
  module RootSwitch
    # Compact trigger initials and the allowed `compact:` values.
    class CompactTrigger
      MODES = [nil, :below_md, :always].freeze
      FALLBACK_ICON = "building-office-2"
      DEFAULT_BADGE_SIZE = :sm

      # Applied on the dropdown wrapper so FlatPack's Tailwind merge cannot
      # drop padding/gap against later button size classes. String literals
      # so the dummy/host Tailwind scan emits them.
      ALWAYS_WRAPPER_CLASS = [
        "[&_button]:px-0",
        "[&_button]:py-0",
        "[&_button]:gap-0",
        "[&_button]:min-w-0",
        "[&_button]:w-fit",
        "[&_button]:rounded-full",
        "[&_button]:border-0"
      ].join(" ")

      BELOW_MD_WRAPPER_CLASS = [
        "max-md:[&_button]:px-0",
        "max-md:[&_button]:py-0",
        "max-md:[&_button]:gap-0",
        "max-md:[&_button]:min-w-0",
        "max-md:[&_button]:w-fit",
        "max-md:[&_button]:rounded-full",
        "max-md:[&_button]:border-0",
        "max-md:[&_[data-flat-pack--button-dropdown-target=chevron]]:hidden",
        "max-md:[&_button>span.shrink-0]:hidden"
      ].join(" ")

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
