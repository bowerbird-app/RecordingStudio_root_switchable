# frozen_string_literal: true

class WorkspacesController < ApplicationController
  def new
    @return_to = local_return_path(params[:return_to])
  end

  private

  def local_return_path(raw)
    path = RecordingStudioRootSwitchable::RedirectSanitizer.sanitize(raw)
    return unless path.is_a?(String)
    return unless path.start_with?("/")
    return if path.start_with?("//")

    path
  end
end
