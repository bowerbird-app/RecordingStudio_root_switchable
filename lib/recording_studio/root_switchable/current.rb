# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    class Current < ActiveSupport::CurrentAttributes
      attribute :actor,
                :available_roots_cache,
                :device_key,
                :root_recordable,
                :root_recording,
                :scope,
                :scope_key,
                :selection

      def root
        root_recording
      end

      def root=(value)
        self.root_recording = value
      end

      def cached_available_roots_for(scope_key)
        cache = available_roots_cache
        return unless cache

        cache[scope_key.to_s]
      end

      def store_available_roots(scope_key, roots)
        self.available_roots_cache ||= {}
        available_roots_cache[scope_key.to_s] = roots
      end
    end
  end
end
