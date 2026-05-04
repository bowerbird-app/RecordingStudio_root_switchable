# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    class ScopeDefinition
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
      attr_reader :key

      def initialize(key)
        @key = key.to_s
        @label = @key.humanize
        @description = nil
        @page_copy = {}
        @supported_if = ->(**) { true }
        @available_roots = method(:default_available_roots)
        @default_root = ->(roots:, **) { roots.first }
        @access_check = method(:default_access_allowed?)
        @validity_check = ->(recording:, **) { recording.present? && recording.parent_recording_id.nil? }
        @root_label = method(:default_root_label)
        @root_description = method(:default_root_description)
      end

      def assign!(options)
        options.each do |name, value|
          if name.to_sym == :page_copy
            @page_copy = @page_copy.merge(normalize_hash(value))
          else
            public_send("#{name}=", value)
          end
        end
      end

      def supported?(**)
        !!resolve_callable(supported_if, **)
      rescue StandardError
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
          .uniq(&:id)
      end

      def default_root_for(**)
        normalize_root_recording(resolve_callable(default_root, **))
      end

      def allowed?(**)
        !!resolve_callable(access_check, **)
      rescue StandardError
        false
      end

      def valid?(**)
        !!resolve_callable(validity_check, **)
      rescue StandardError
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
        return candidate if candidate.respond_to?(:id) && candidate.respond_to?(:recordable)
        return if candidate.blank? || !defined?(::RecordingStudio::Recording)

        ::RecordingStudio::Recording.unscoped.find_by(recordable: candidate, parent_recording_id: nil)
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
    end
  end
end
