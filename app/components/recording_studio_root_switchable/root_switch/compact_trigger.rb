# frozen_string_literal: true

module RecordingStudioRootSwitchable
  module RootSwitch
    class CompactTrigger
      MODES = [nil, :below_md, :always].freeze
      CHROMES = %i[bare button].freeze
      DEFAULT_CHROME = :bare
      FALLBACK_ICON = "building-office-2"
      DEFAULT_BADGE_SIZE = :sm
      DEFAULT_BUTTON_SIZE = :md
      WRAPPER_ROOT_CLASS = "rs-root-switch-compact"

      def self.normalize!(value)
        return nil if value.nil?

        mode = coerce_symbol(value)
        return mode if MODES.include?(mode)

        raise ArgumentError,
              "Invalid compact: #{value.inspect}. Must be nil, :below_md, or :always."
      end

      def self.normalize_chrome!(value)
        chrome = value.nil? ? DEFAULT_CHROME : coerce_symbol(value)
        return chrome if CHROMES.include?(chrome)

        raise ArgumentError,
              "Invalid compact_chrome: #{value.inspect}. Must be :bare or :button."
      end

      def self.resolve_badge_size!(badge_size:, compact_chrome:, button_size:)
        return normalize_badge_size!(badge_size) unless badge_size.nil?
        return normalize_badge_size!(resolved_button_size(button_size)) if compact_chrome == :button

        DEFAULT_BADGE_SIZE
      end

      def self.resolved_button_size(value)
        value.nil? ? DEFAULT_BUTTON_SIZE : coerce_symbol(value)
      end

      def self.wrapper_class(compact:, chrome:, size:)
        return if compact.nil?

        [
          WRAPPER_ROOT_CLASS,
          "#{WRAPPER_ROOT_CLASS}--#{compact.to_s.tr('_', '-')}",
          "#{WRAPPER_ROOT_CLASS}--#{chrome}",
          "#{WRAPPER_ROOT_CLASS}--#{resolved_button_size(size)}"
        ].join(" ")
      end

      def self.initials(name)
        words = name.to_s.scan(/[[:alpha:][:digit:]]+/)
        return if words.empty?
        return words.first.chars.first(2).join.upcase if words.one?

        words.first(2).map { |word| word[0] }.join.upcase
      end

      def self.normalize_badge_size!(value)
        size = value.nil? ? DEFAULT_BADGE_SIZE : coerce_symbol(value)
        FlatPack::Avatar::Component.new(size: size, show_tooltip: false)
        size
      rescue ArgumentError
        keys = FlatPack::Avatar::Component::SIZES.keys.map(&:inspect).join(", ")
        raise ArgumentError, "Invalid badge_size: #{value.inspect}. Must be one of: #{keys}"
      end

      def self.coerce_symbol(value)
        value.is_a?(String) ? value.to_sym : value
      end
      private_class_method :coerce_symbol
    end
  end
end
