# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    module SelectionCleanup
      module_function

      # Removes selections whose root recording no longer exists or is no longer a root.
      def prune_orphaned!(limit: 500)
        return 0 unless defined?(RecordingStudio::RootSwitchable::Selection)

        prune_relation(
          RecordingStudio::RootSwitchable::Selection.order(:updated_at).limit(limit)
        )
      end

      def prune_for_actor_device!(actor:, device_key:, scope_key: nil, available_root_ids: nil)
        return 0 unless defined?(RecordingStudio::RootSwitchable::Selection)

        relation = scoped_relation(actor: actor, device_key: device_key, scope_key: scope_key)
        allowed_ids = Array(available_root_ids).map(&:to_s)

        prune_relation(relation) do |selection|
          if available_root_ids
            allowed_ids.include?(selection.root_recording_id.to_s)
          else
            selection_still_valid?(selection)
          end
        end
      end

      def scoped_relation(actor:, device_key:, scope_key:)
        relation = RecordingStudio::RootSwitchable::Selection.where(device_key: device_key.to_s)
        relation = actor.present? ? relation.where(actor: actor) : relation.where(actor: nil)
        scope_key.present? ? relation.where(scope_key: scope_key.to_s) : relation
      end
      private_class_method :scoped_relation

      def prune_relation(relation)
        removed = 0
        relation.find_each do |selection|
          keep = block_given? ? yield(selection) : selection_still_valid?(selection)
          next if keep

          selection.destroy
          removed += 1
        end
        removed
      end
      private_class_method :prune_relation

      def selection_still_valid?(selection)
        recording = selection.root_recording
        return false if recording.blank?
        return false unless defined?(::RecordingStudio) && ::RecordingStudio.respond_to?(:root_recording?)

        ::RecordingStudio.root_recording?(recording)
      rescue StandardError => e
        return false if RecordingStudio::RootSwitchable.root_api_error?(e)

        raise
      end
      private_class_method :selection_still_valid?
    end
  end
end
