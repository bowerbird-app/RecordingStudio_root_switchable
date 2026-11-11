# frozen_string_literal: true

RecordingStudioRootSwitchable::Engine.routes.draw do
  root "root_switches#show"

  scope :v1 do
    resource :root_switch, only: %i[show update], controller: :root_switches
    get "new_roots", to: "new_roots#index", as: :new_roots
    get "new_root", to: "new_roots#show", as: :new_root
  end
end
