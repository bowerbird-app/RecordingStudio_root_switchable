# frozen_string_literal: true

module RecordingStudio
  module RootSwitchable
    module DeviceKeyPreview
      module_function

      def format(device_key)
        value = device_key.to_s
        return "Unavailable" if value.blank?
        return "••••" if value.length <= 12

        "#{value.first(8)}…#{value.last(4)}"
      end
    end
  end
end
