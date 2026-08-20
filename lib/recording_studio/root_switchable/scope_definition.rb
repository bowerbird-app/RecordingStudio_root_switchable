# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    class ScopeDefinition
      ASSIGNABLE_ATTRIBUTES = %i[
        access_check
        available_roots
        default_root
        description
        label
        page_copy
        root_description
        root_label
        supported_if
        switchable_root_types
        validity_check
      ].freeze

      attr_accessor :access_check,
                    :available_roots,
                    :default_root,
                    :description,
                    :label,
                    :page_copy,
                    :root_description,
                    :root_label,
                    :supported_if,
                    :validity_check
      attr_reader :key, :switchable_root_types

      def initialize(key)
        @key = key.to_s
        @label = @key.humanize
        @description = nil
        @page_copy = {}
        @supported_if = ->(**) { true }
        @available_roots = method(:default_available_roots)
        @switchable_root_types = []
        @default_root = ->(roots:, **) { roots.first }
        @access_check = method(:default_access_allowed?)
        @validity_check = method(:default_valid_root?)
        @root_label = method(:default_root_label)
        @root_description = method(:default_root_description)
      end

      def assign!(options)
        options.each do |name, value|
          attribute = name.to_sym
          raise ArgumentError, "unsupported scope option: #{attribute}" unless ASSIGNABLE_ATTRIBUTES.include?(attribute)

          if attribute == :page_copy
            @page_copy = @page_copy.merge(normalize_hash(value))
          else
            public_send("#{attribute}=", value)
          end
        end
      end

      def supported?(**)
        !!resolve_callable(supported_if, **)
      rescue StandardError => e
        log_hook_failure("supported_if", e)
        false
      end

      def label_for(**)
        resolve_callable(label, **)
      end

      def description_for(**)
        resolve_callable(description, **)
      end

      def available_roots_for(**)
        Array(resolve_callable(available_roots, **))
          .filter_map { |candidate| normalize_root_recording(candidate) }
          .select { |recording| switchable_root_type?(recording) }
          .reject { |recording| shared_root_recording?(recording) }
          .uniq(&:id)
          .tap { |roots| preload_recordables!(roots) }
      end

      def default_root_for(**)
        recording = normalize_root_recording(resolve_callable(default_root, **))
        return if recording.blank?
        return unless switchable_root_type?(recording)
        return if shared_root_recording?(recording)

        recording
      end

      def switchable_root_types=(types)
        @switchable_root_types = normalize_switchable_root_types(types)
      end

      def allowed?(**)
        !!resolve_callable(access_check, **)
      rescue StandardError => e
        log_hook_failure("access_check", e)
        false
      end

      def valid?(**)
        !!resolve_callable(validity_check, **)
      rescue StandardError => e
        log_hook_failure("validity_check", e)
        false
      end

      def root_label_for(**)
        resolve_callable(root_label, **)
      end

      def root_description_for(**)
        resolve_callable(root_description, **)
      end

      private

      def resolve_callable(value, **)
        return value unless value.respond_to?(:call)

        value.call(**)
      end

      def normalize_root_recording(candidate)
        return candidate if recording_candidate?(candidate)
        return if candidate.blank? || !defined?(::RecordingStudio::Recording)
        return unless root_allowed?(candidate)

        find_existing_root_recording_for(candidate)
      rescue StandardError => e
        raise unless RecordingStudio::RootSwitchable.root_api_error?(e)

        nil
      end

      def find_existing_root_recording_for(recordable)
        relation = ::RecordingStudio::Recording.unscoped.where(recordable: recordable)

        if relation.respond_to?(:klass) && relation.klass.column_names.include?("parent_recording_id")
          relation = relation.where(parent_recording_id: nil)
        end

        each_recording(relation) do |recording|
          return recording if default_valid_root?(recording: recording)
        end

        nil
      end

      def each_recording(relation, &)
        if relation.respond_to?(:find_each)
          relation.find_each(&)
        else
          Array(relation).each(&)
        end
      end

      def preload_recordables!(roots)
        return if roots.empty?
        return unless defined?(ActiveRecord::Associations::Preloader)
        return unless roots.all? { |root| root.is_a?(ActiveRecord::Base) }
        return unless roots.first.class.reflect_on_association(:recordable)

        ActiveRecord::Associations::Preloader.new(records: roots, associations: [:recordable]).call
      rescue StandardError
        roots
      end

      def default_available_roots(actor:, **)
        return [] unless recording_studio_accessible_supports_root_queries?
        return [] if actor.blank?

        Array(::RecordingStudioAccessible.root_recordings_for(actor: actor, minimum_role: :view))
      end

      def default_access_allowed?(actor:, recording:, **)
        return false unless recording_studio_accessible_supports_authorization?

        actor.present? && ::RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :view)
      end

      def default_valid_root?(recording:, **)
        return false unless defined?(::RecordingStudio) && ::RecordingStudio.respond_to?(:root_recording?)
        return false if shared_root_recording?(recording)

        ::RecordingStudio.root_recording?(recording)
      rescue StandardError => e
        raise unless RecordingStudio::RootSwitchable.root_api_error?(e)

        false
      end

      def recording_candidate?(candidate)
        return false if candidate.blank?
        return true if defined?(::RecordingStudio::Recording) && candidate.is_a?(::RecordingStudio::Recording)

        candidate.respond_to?(:id) && candidate.respond_to?(:recordable)
      end

      def switchable_root_type?(recording)
        return true if switchable_root_types.empty?

        switchable_root_types.include?(recordable_type_for(recording))
      end

      # Shared roots are domain forests, not owned buckets. They must never appear
      # in the switcher, even when listed in switchable_root_types or returned by
      # a custom available_roots / default_root hook.
      def shared_root_recording?(recording)
        return false unless defined?(::RecordingStudio)
        return false unless ::RecordingStudio.respond_to?(:shared_root?)

        ::RecordingStudio.shared_root?(recording)
      rescue StandardError => e
        raise unless RecordingStudio::RootSwitchable.root_api_error?(e)

        false
      end

      def recordable_type_for(recording)
        recordable_type = recording.recordable_type if recording.respond_to?(:recordable_type)

        recordable_type.presence || recording.recordable&.class&.name
      end

      def normalize_switchable_root_types(types)
        Array(types).flatten.filter_map do |type|
          case type
          when Class
            type.name.presence
          else
            type.to_s.presence
          end
        end
      end

      def root_allowed?(recordable)
        return false unless defined?(::RecordingStudio) && ::RecordingStudio.respond_to?(:root_allowed?)

        ::RecordingStudio.root_allowed?(recordable)
      end

      def default_root_label(recording:, **)
        recordable = recording&.recordable
        return "Unknown root" unless recordable
        return recordable.recordable_name if recordable.respond_to?(:recordable_name)
        return recordable.name if recordable.respond_to?(:name)
        return recordable.title if recordable.respond_to?(:title)

        recordable.class.name.demodulize
      end

      def default_root_description(recording:, **)
        recordable = recording&.recordable
        return "Recording ##{recording.id}" if recordable.blank?
        return recordable.description if recordable.respond_to?(:description) && recordable.description.present?
        return recordable.summary if recordable.respond_to?(:summary) && recordable.summary.present?

        recordable.class.name.demodulize
      end

      def normalize_hash(value)
        return {} unless value.respond_to?(:each_pair)

        value.each_pair.with_object({}) do |(key, nested_value), memo|
          memo[key.to_sym] = nested_value
        end
      end

      def recording_studio_accessible_supports_authorization?
        defined?(::RecordingStudioAccessible) && ::RecordingStudioAccessible.respond_to?(:authorized?)
      end

      def recording_studio_accessible_supports_root_queries?
        defined?(::RecordingStudioAccessible) && ::RecordingStudioAccessible.respond_to?(:root_recordings_for)
      end

      def log_hook_failure(hook_name, error)
        return unless defined?(Rails) && Rails.respond_to?(:env) && !Rails.env.production?
        return unless Rails.respond_to?(:logger) && Rails.logger

        Rails.logger.warn(
          "RecordingStudio::RootSwitchable::ScopeDefinition##{hook_name} raised #{error.class}: #{error.message}"
        )
      end
    end
  end
end
