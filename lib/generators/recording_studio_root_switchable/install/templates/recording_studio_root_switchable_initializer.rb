# frozen_string_literal: true

RecordingStudioRootSwitchable.configure do |config|
  config.current_actor_resolver = lambda do |controller:|
    Current.actor || controller.current_user
  end

  # For production hosts, enable secure cookies and force SSL in the host app.
  # config.device_key_cookie_options = config.device_key_cookie_options.merge(secure: Rails.env.production?)

  config.scope :roots do |scope|
    scope.label = "Roots"
    scope.description = "All accessible root recordings"
    scope.available_roots = lambda do |actor:, **|
      RecordingStudioAccessible.root_recordings_for(actor: actor, minimum_role: :view)
    end
  end
end
