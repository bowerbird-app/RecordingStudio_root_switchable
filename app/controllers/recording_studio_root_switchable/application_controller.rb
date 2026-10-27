# frozen_string_literal: true

require "recording_studio/controller_layout"

module RecordingStudioRootSwitchable
  class ApplicationController < (defined?(::ApplicationController) ? ::ApplicationController : ActionController::Base)
    include RecordingStudio::ControllerLayout
    include RecordingStudio::RootSwitchable::ControllerSupport unless ancestors.include?(
      RecordingStudio::RootSwitchable::ControllerSupport
    )

    protect_from_forgery with: :exception

    recording_studio_layout { RecordingStudioRootSwitchable.configuration.layout }

    private

    def page_copy
      RecordingStudioRootSwitchable.configuration.page_copy_for(scope: RecordingStudio::RootSwitchable::Current.scope)
    end
  end
end
