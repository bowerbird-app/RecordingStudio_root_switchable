# frozen_string_literal: true

module RecordingStudioRootSwitchable
  class ApplicationController < (defined?(::ApplicationController) ? ::ApplicationController : ActionController::Base)
    include RecordingStudio::RootSwitchable::ControllerSupport unless ancestors.include?(
      RecordingStudio::RootSwitchable::ControllerSupport
    )

    protect_from_forgery with: :exception

    private

    def page_copy
      RecordingStudioRootSwitchable.configuration.page_copy_for(scope: RecordingStudio::RootSwitchable::Current.scope)
    end
  end
end
