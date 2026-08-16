# frozen_string_literal: true

module RecordingStudioRootSwitchable
  module RedirectSanitizer
    module_function

    def sanitize(target)
      RecordingStudio::RootSwitchable::InternalPath.sanitize(target)
    end
  end
end
