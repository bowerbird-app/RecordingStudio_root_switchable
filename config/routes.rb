# frozen_string_literal: true

RecordingStudioRootSwitchable::Engine.routes.draw do
  root "root_switches#show"

  scope :v1 do
    resource :root_switch, only: %i[show update], controller: :root_switches
  end
end
