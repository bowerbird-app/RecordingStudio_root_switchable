# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    class Selection < ActiveRecord::Base
      DEVICE_METADATA_ATTRIBUTES = %i[
        device_label
        device_platform
        device_browser
        device_type
        user_agent
      ].freeze

      DEVICE_KEY_MAX_LENGTH = 128
      SCOPE_KEY_MAX_LENGTH = 128
      DEVICE_METADATA_MAX_LENGTH = 255
      USER_AGENT_MAX_LENGTH = 512

      self.table_name = "recording_studio_root_switchable_selections"

      belongs_to :actor, polymorphic: true, optional: true
      belongs_to :root_recording, class_name: "RecordingStudio::Recording"

      validates :device_key, :scope_key, :root_recording, presence: true
      validates :device_key, length: { maximum: DEVICE_KEY_MAX_LENGTH }
      validates :scope_key, length: { maximum: SCOPE_KEY_MAX_LENGTH }
      validates :device_label, :device_platform, :device_browser, :device_type,
                length: { maximum: DEVICE_METADATA_MAX_LENGTH },
                allow_nil: true
      validates :user_agent, length: { maximum: USER_AGENT_MAX_LENGTH }, allow_nil: true
      validates :last_used_at, presence: true
      validate :actor_reference_is_complete
      validate :root_recording_is_a_root
      validate :actor_presence_matches_configuration

      before_validation :normalize_attributes

      class << self
        def lookup(actor:, device_key:, scope_key:)
          relation = where(device_key: device_key.to_s, scope_key: scope_key.to_s)
          actor.present? ? relation.find_by(actor: actor) : relation.find_by(actor: nil)
        end

        def upsert_for(actor:, device_key:, scope_key:, root_recording:, device_metadata: {})
          with_upsert_retry do
            selection = find_or_initialize_selection(actor: actor, device_key: device_key, scope_key: scope_key)
            assign_device_metadata(selection, device_metadata)
            selection.root_recording = root_recording
            selection.last_used_at = Time.current
            selection.save!
            selection
          end
        end

        private

        def find_or_initialize_selection(actor:, device_key:, scope_key:)
          find_or_initialize_by(
            actor: actor,
            device_key: device_key.to_s,
            scope_key: scope_key.to_s
          )
        end

        def assign_device_metadata(selection, device_metadata)
          normalized = normalized_device_metadata(device_metadata)
          DEVICE_METADATA_ATTRIBUTES.each do |attribute|
            writer = "#{attribute}="
            next unless selection.respond_to?(writer)

            if normalized.key?(attribute)
              selection.public_send(writer, normalized[attribute])
            elsif attribute == :user_agent && !RecordingStudioRootSwitchable.configuration.store_raw_user_agent
              selection.public_send(writer, nil)
            end
          end
        end

        def normalized_device_metadata(device_metadata)
          DEVICE_METADATA_ATTRIBUTES.each_with_object({}) do |attribute, result|
            value = device_metadata[attribute] || device_metadata[attribute.to_s]
            next if value.blank?

            max_length = attribute == :user_agent ? USER_AGENT_MAX_LENGTH : DEVICE_METADATA_MAX_LENGTH
            result[attribute] = value.to_s.strip.presence&.slice(0, max_length)
          end.compact
        end

        def with_upsert_retry
          attempts = 0

          begin
            yield
          rescue ActiveRecord::RecordNotUnique
            attempts += 1
            raise if attempts > 1

            retry
          end
        end
      end

      private

      def normalize_attributes
        self.device_key = device_key.to_s.strip.slice(0, DEVICE_KEY_MAX_LENGTH)
        self.scope_key = scope_key.to_s.strip.slice(0, SCOPE_KEY_MAX_LENGTH)
        DEVICE_METADATA_ATTRIBUTES.each do |attribute|
          value = public_send(attribute).to_s.strip.presence
          max_length = attribute == :user_agent ? USER_AGENT_MAX_LENGTH : DEVICE_METADATA_MAX_LENGTH
          public_send("#{attribute}=", value&.slice(0, max_length))
        end
        self.last_used_at ||= Time.current
      end

      def actor_reference_is_complete
        return if actor_type.blank? && actor_id.blank?
        return if actor_type.present? && actor_id.present?

        errors.add(:actor, "must include both type and id")
      end

      def actor_presence_matches_configuration
        return if RecordingStudioRootSwitchable.configuration.allow_anonymous_selections
        return if actor.present?

        errors.add(:actor, "must be present unless anonymous selections are enabled")
      end

      def root_recording_is_a_root
        return if root_recording.blank?
        return if valid_root_recording_reference?

        errors.add(:root_recording, "must reference a root recording")
      rescue StandardError => e
        raise unless RecordingStudio::RootSwitchable.root_api_error?(e)

        errors.add(:root_recording, "must reference a root recording")
      end

      def valid_root_recording_reference?
        defined?(::RecordingStudio) &&
          ::RecordingStudio.respond_to?(:root_recording?) &&
          ::RecordingStudio.root_recording?(root_recording)
      end
    end
  end
end
