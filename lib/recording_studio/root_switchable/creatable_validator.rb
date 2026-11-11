# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    # Rejects creatable types that the switcher could never select.
    class CreatableValidator
      def initialize(scope, explicit_entries, entries)
        @scope = scope
        @explicit_entries = explicit_entries
        @entries = entries
      end

      def validate!
        refuse_mixed_shorthand!
        entries.each { |entry| assert_allowed!(entry) }
        assert_unique!
      end

      private

      attr_reader :scope, :explicit_entries, :entries

      def refuse_mixed_shorthand!
        return if explicit_entries.empty? || scope.new_root_path.blank?

        raise ArgumentError, mixed_shorthand_message
      end

      def mixed_shorthand_message
        "scope #{scope.key} sets creatable_root and new_root_path. " \
          "new_root_path is the shorthand for a single creatable entry."
      end

      def assert_unique!
        duplicate = entries.map(&:type_name).tally.find { |_name, count| count > 1 }&.first
        return unless duplicate

        raise ArgumentError, "#{duplicate} is listed twice on scope #{scope.key}"
      end

      def assert_allowed!(entry)
        assert_listed!(entry)
        assert_not_shared!(entry)
      end

      def assert_listed!(entry)
        return if scope.switchable_root_types.include?(entry.type_name)

        raise ArgumentError, "#{entry.type_name} is not in switchable_root_types for scope #{scope.key}"
      end

      def assert_not_shared!(entry)
        return unless shared_type?(entry.type_name)

        raise ArgumentError, "#{entry.type_name} is a shared root and cannot be creatable on scope #{scope.key}"
      end

      def shared_type?(type_name)
        return false unless defined?(::RecordingStudio)
        return false unless ::RecordingStudio.respond_to?(:shared_root_type?)

        ::RecordingStudio.shared_root_type?(type_name)
      rescue StandardError
        false
      end
    end
  end
end
