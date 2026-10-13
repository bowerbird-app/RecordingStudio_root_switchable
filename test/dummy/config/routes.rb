Rails.application.routes.draw do
  devise_for :users

  # RecordingStudio engine is data/API-focused and has no browser root route.
  # Keep legacy links working by redirecting the base path to the app home.
  get "/recording_studio", to: redirect("/"), as: nil
  mount RecordingStudio::Engine, at: "/recording_studio"
  mount RecordingStudioAccessible::Engine, at: "/recording_studio_accessible"
  mount RecordingStudioRootSwitchable::Engine, at: "/recording_studio_root_switchable"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  get "setup", to: "home#setup"
  get "config", to: "home#configuration"
  get "usage", to: "home#usage"
  get "switch_log", to: "home#switch_log"
   get "persistence", to: redirect("/switch_log")
  get "method", to: "home#method_docs"
  get "gem_views", to: "home#gem_views"
  get "gem_views/*view_path", to: "home#gem_view", as: :gem_view
  root "home#index"
end
