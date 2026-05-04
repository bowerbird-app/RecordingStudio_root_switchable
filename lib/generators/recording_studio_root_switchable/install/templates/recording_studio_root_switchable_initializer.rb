# frozen_string_literal: true

RecordingStudioRootSwitchable.configure do |config|
  config.current_actor_resolver = lambda do |controller:|
    Current.actor || controller.current_user
  end

  # Optional: render the mounted page inside a host layout instead of the gem blank layout.
  # config.layout = :application_layout

  # For production hosts, enable secure cookies and force SSL in the host app.
  # config.device_key_cookie_options = config.device_key_cookie_options.merge(secure: Rails.env.production?)

  # Optionally control where the browser lands after a successful switch.
  # Available args: controller:, actor:, device_key:, scope:, root_recording:, return_to:
  # config.after_switch_redirect = lambda do |controller:, return_to:, **|
  #   return_to.presence || controller.main_app.root_path
  # end

  config.scope :roots do |scope|
    scope.label = "Roots"
    scope.description = "All accessible root recordings"
    scope.available_roots = lambda do |actor:, **|
      RecordingStudioAccessible.root_recordings_for(actor: actor, minimum_role: :view)
    end
  end
end
