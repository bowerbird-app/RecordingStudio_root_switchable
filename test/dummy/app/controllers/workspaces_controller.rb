# frozen_string_literal: true

class WorkspacesController < ApplicationController
  include RecordingStudio::RootSwitchable::GuardsRootCreation

  guard_root_creation! scope: :all_workspaces, type: "Workspace", only: %i[new create]

  before_action :set_return_to, only: %i[new create]

  def new
  end

  def create
    redirect_to @return_to.presence || root_path, notice: "Form accepted. Nothing was saved."
  end

  private

  def set_return_to
    @return_to = RecordingStudioRootSwitchable::RedirectSanitizer.sanitize(params[:return_to])
  end
end
