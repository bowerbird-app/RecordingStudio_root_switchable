# frozen_string_literal: true

class TeamsController < ApplicationController
  include RecordingStudio::RootSwitchable::GuardsRootCreation

  guard_root_creation! scope: :studio, type: "Team", only: %i[new create]

  def new
  end

  def create
    redirect_to root_path, notice: "Form accepted. Nothing was saved."
  end
end
