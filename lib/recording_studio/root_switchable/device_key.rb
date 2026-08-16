# frozen_string_literal: true

require "securerandom"

module RecordingStudio
  module RootSwitchable
    module DeviceKey
      class Unavailable < StandardError; end

      class << self
        def fetch(controller:, cookies: nil)
          return Current.device_key if Current.device_key.present?

          cookie_jar = cookies || cookies_from(controller)
          raise Unavailable, "device key cookies are unavailable" unless cookie_jar

          encrypted_jar = cookie_jar.respond_to?(:encrypted) ? cookie_jar.encrypted : cookie_jar
          cookie_name = RecordingStudioRootSwitchable.configuration.device_key_cookie_name
          existing_key = encrypted_jar[cookie_name]
          return existing_key if existing_key.present?

          generated_key = SecureRandom.uuid
          cookie_options = RecordingStudioRootSwitchable.configuration.resolved_device_key_cookie_options
          encrypted_jar[cookie_name] = cookie_options.merge(value: generated_key)
          generated_key
        end

        private

        def cookies_from(controller)
          return unless controller
          return unless controller.respond_to?(:cookies, true)

          controller.send(:cookies)
        end
      end
    end
  end
end
