# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    class Selection < ActiveRecord::Base
      self.table_name = "recording_studio_root_switchable_selections"

      belongs_to :actor, polymorphic: true, optional: true
      belongs_to :root_recording, class_name: "RecordingStudio::Recording"

      validates :device_key, :scope_key, :root_recording, presence: true
      validates :last_used_at, presence: true
      validate :actor_reference_is_complete
      validate :root_recording_is_a_root

      before_validation :normalize_attributes

      class << self
        def lookup(actor:, device_key:, scope_key:)
          relation = where(device_key: device_key.to_s, scope_key: scope_key.to_s)
          actor.present? ? relation.find_by(actor: actor) : relation.find_by(actor: nil)
        end

        def upsert_for(actor:, device_key:, scope_key:, root_recording:)
          with_upsert_retry do
            selection = find_or_initialize_selection(actor: actor, device_key: device_key, scope_key: scope_key)
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
        self.device_key = device_key.to_s.strip
        self.scope_key = scope_key.to_s.strip
        self.last_used_at ||= Time.current
      end

      def actor_reference_is_complete
        return if actor_type.blank? && actor_id.blank?
        return if actor_type.present? && actor_id.present?

        errors.add(:actor, "must include both type and id")
      end

      def root_recording_is_a_root
        return if root_recording.blank? || root_recording.parent_recording_id.nil?

        errors.add(:root_recording, "must reference a root recording")
      end
    end
  end
end
