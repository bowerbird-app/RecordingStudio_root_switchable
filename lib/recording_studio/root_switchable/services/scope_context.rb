# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    module Services
      class ScopeContext
        def initialize(configuration:, controller:, actor:, device_key:, scope_key:)
          @configuration = configuration
          @controller = controller
          @actor = actor
          @device_key = device_key
          @scope_key = scope_key
        end

        def resolve_scope
          @configuration.resolve_scope(
            key: @scope_key,
            controller: @controller,
            actor: @actor,
            device_key: @device_key
          )
        end

        def available_roots_for(scope)
          scope.available_roots_for(**scope_arguments)
               .select do |root_recording|
            scope.valid?(**scope_arguments, recording: root_recording) &&
              scope.allowed?(**scope_arguments, recording: root_recording)
          end
        end

        def default_root_for(scope, roots)
          default_root = scope.default_root_for(**scope_arguments, roots: roots)
          return default_root if default_root.present? && roots.any? { |root| root.id == default_root.id }

          roots.first
        end

        private

        def scope_arguments
          {
            controller: @controller,
            actor: @actor,
            device_key: @device_key
          }
        end
      end
    end
  end
end
