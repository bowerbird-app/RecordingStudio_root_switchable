# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    # Creatable types for one scope. Legacy new_root_path is one entry when
    # the scope lists exactly one switchable type.
    class CreatableCatalog
      attr_accessor :before_hook

      def initialize(scope)
        @scope = scope
        @entries = []
      end

      def add(type, label:, icon:, path:, description:)
        @entries << CreatableRoot.new(
          type_name: type_name(type),
          label: label,
          icon: icon,
          path: path,
          description: description,
          legacy: false
        )
      end

      def entries
        return @entries if @entries.any?

        legacy_entry ? [legacy_entry] : []
      end

      def direct_legacy?
        @entries.empty? && scope.new_root_path.present? && scope.switchable_root_types.size != 1
      end

      def validate!
        CreatableValidator.new(scope, @entries, entries).validate!
      end

      def presented(arguments, mode:)
        entries.filter_map { |entry| present(entry, arguments, mode) }
      end

      def present_type(type_name, arguments, mode:)
        entry = entries.find { |candidate| candidate.type_name == type_name.to_s }
        return unless entry

        present(entry, arguments, mode)
      end

      private

      attr_reader :scope

      def present(entry, arguments, mode)
        CreatablePresenter.new(scope, hook_for).present(entry, arguments, mode)
      end

      def hook_for
        before_hook || RecordingStudioRootSwitchable.configuration.before_root_create
      end

      def legacy_entry
        return unless scope.new_root_path.present? && scope.switchable_root_types.size == 1

        CreatableRoot.new(
          type_name: scope.switchable_root_types.first,
          label: nil,
          icon: nil,
          path: nil,
          description: nil,
          legacy: true
        )
      end

      def type_name(type)
        name = type.is_a?(Class) ? type.name : type.to_s
        name = name.strip
        raise ArgumentError, "creatable_root type is blank on scope #{scope.key}" if name.blank?

        name
      end
    end
  end
end
