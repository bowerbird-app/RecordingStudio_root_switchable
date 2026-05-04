# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    module DeviceMetadata
      PLATFORM_PATTERNS = [
        [/iPhone/i, "iPhone"],
        [/iPad/i, "iPad"],
        [/Android/i, "Android"],
        [/Macintosh|Mac OS X/i, "macOS"],
        [/Windows/i, "Windows"],
        [/Linux/i, "Linux"]
      ].freeze

      BROWSER_PATTERNS = [
        [%r{Edg/}i, "Edge"],
        [%r{Chrome/}i, "Chrome"],
        [%r{CriOS/}i, "Chrome"],
        [%r{Firefox/}i, "Firefox"],
        [%r{FxiOS/}i, "Firefox"],
        [%r{Safari/}i, "Safari"]
      ].freeze

      class << self
        def capture(controller:)
          user_agent = extract_user_agent(controller)
          return {} if user_agent.blank?

          build_metadata(user_agent)
        end

        private

        def build_metadata(user_agent)
          platform = detect_platform(user_agent)
          browser = detect_browser(user_agent)
          device_type = detect_device_type(user_agent)

          {
            device_label: build_label(browser: browser, platform: platform, device_type: device_type),
            device_platform: platform,
            device_browser: browser,
            device_type: device_type,
            user_agent: user_agent
          }.compact
        end

        def extract_user_agent(controller)
          request = controller&.request
          return if request.nil?

          request.user_agent.to_s.strip.presence
        end

        def detect_platform(user_agent)
          detect_match(user_agent, PLATFORM_PATTERNS)
        end

        def detect_browser(user_agent)
          detect_match(user_agent, BROWSER_PATTERNS)
        end

        def detect_device_type(user_agent)
          case user_agent
          when /iPad|Tablet/i
            "tablet"
          when /iPhone|Mobile|Android.+Mobile/i
            "mobile"
          else
            "desktop"
          end
        end

        def build_label(browser:, platform:, device_type:)
          return "#{browser} on #{platform}" if browser.present? && platform.present?
          return browser if browser.present?
          return platform if platform.present?

          device_type.to_s.humanize.presence
        end

        def detect_match(user_agent, patterns)
          patterns.each do |pattern, value|
            return value if user_agent.match?(pattern)
          end

          nil
        end
      end
    end
  end
end
