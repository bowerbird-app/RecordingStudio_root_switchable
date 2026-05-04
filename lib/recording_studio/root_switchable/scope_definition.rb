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
        @access_check = method(:default_access_check)
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

      def supported?(**kwargs)
        !!resolve_callable(supported_if, **kwargs)
      rescue StandardError
        false
      end

      def label_for(**kwargs)
        resolve_callable(label, **kwargs)
      end

      def description_for(**kwargs)
        resolve_callable(description, **kwargs)
      end

      def available_roots_for(**kwargs)
        Array(resolve_callable(available_roots, **kwargs))
          .filter_map { |candidate| normalize_root_recording(candidate) }
          .uniq { |recording| recording.id }
      end

      def default_root_for(**kwargs)
        normalize_root_recording(resolve_callable(default_root, **kwargs))
      end

      def allowed?(**kwargs)
        !!resolve_callable(access_check, **kwargs)
      rescue StandardError
        false
      end

      def valid?(**kwargs)
        !!resolve_callable(validity_check, **kwargs)
      rescue StandardError
        false
      end

      def root_label_for(**kwargs)
        resolve_callable(root_label, **kwargs)
      end

      def root_description_for(**kwargs)
        resolve_callable(root_description, **kwargs)
      end

      private

      def resolve_callable(value, **kwargs)
        return value unless value.respond_to?(:call)

        value.call(**kwargs)
      end

      def normalize_root_recording(candidate)
        return candidate if candidate.respond_to?(:id) && candidate.respond_to?(:recordable)
        return if candidate.blank? || !defined?(::RecordingStudio::Recording)

        ::RecordingStudio::Recording.unscoped.find_by(recordable: candidate, parent_recording_id: nil)
      end

      def default_available_roots(actor:, **)
        if defined?(::RecordingStudioAccessible) && ::RecordingStudioAccessible.respond_to?(:root_recordings_for)
          return [] if actor.blank?

          Array(::RecordingStudioAccessible.root_recordings_for(actor: actor, minimum_role: :view))
        elsif defined?(::RecordingStudio::Recording)
          ::RecordingStudio::Recording.unscoped.where(parent_recording_id: nil).order(:created_at, :id)
        else
          []
        end
      end

      def default_access_check(actor:, recording:, **)
        if defined?(::RecordingStudioAccessible) && ::RecordingStudioAccessible.respond_to?(:authorized?)
          actor.present? && ::RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :view)
        else
          true
        end
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
    end
  end
end
