# frozen_string_literal: true

class WorkspacesController < ApplicationController
  def new
    @return_to = RecordingStudioRootSwitchable::RedirectSanitizer.sanitize(params[:return_to])
  end
end
