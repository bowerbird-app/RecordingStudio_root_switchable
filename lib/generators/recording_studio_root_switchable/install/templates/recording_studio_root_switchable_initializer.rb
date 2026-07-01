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

  # RecordingStudio 3.0 root checks require host apps to configure every
  # delegated_type recordable used by switchable roots.
  # RecordingStudio.configure do |recording_studio_config|
  #   recording_studio_config.recordable_types = ["Workspace", "Page"]
  # end
  #
  # If you also use RecordingStudioAccessible on RecordingStudio 3.0 and your
  # installed accessible version has not yet registered its addon-owned
  # RecordingStudio::Access child recordable, add this in
  # config/initializers/recording_studio_accessible.rb:
  #
  # RecordingStudio.register_capability(
  #   :accessible,
  #   source: "recording_studio_accessible",
  #   child_recordables: ["RecordingStudio::Access"]
  # ) if RecordingStudio.respond_to?(:register_capability)

  config.scope :roots do |scope|
    scope.label = "Roots"
    scope.description = "All accessible root recordings"
    # Optional: constrain this scope to one or more delegated_type recordable classes.
    # Accepts strings, symbols, classes, arrays, nil, or blank values.
    # scope.switchable_root_types = ["Workspace"]
    scope.available_roots = lambda do |actor:, **|
      RecordingStudioAccessible.root_recordings_for(actor: actor, minimum_role: :view)
    end
  end
end
