# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  # Fail closed for new grants unless actor types are allowlisted (RSA 0.5+).
  config.access_actor_types = [ "User" ]

  # Demo seeds bootstrap admin-managed access grants before an admin grant exists.
  config.access_management_authorizer = lambda do |actor:, **|
    ENV["RECORDING_STUDIO_ACCESSIBLE_BOOTSTRAP_ADMIN"] == "1" &&
      (Rails.env.development? || Rails.env.test?) &&
      actor.respond_to?(:email) &&
      actor.email == "admin@admin.com"
  end
end

if RecordingStudio.respond_to?(:register_capability)
  accessible_child_recordables = if RecordingStudio.respond_to?(:capability_child_recordables_for)
                                   Array(RecordingStudio.capability_child_recordables_for(:accessible))
  else
    []
  end

  unless accessible_child_recordables.include?("RecordingStudio::Access")
    RecordingStudio.register_capability(
      :accessible,
      source: "recording_studio_accessible",
      child_recordables: [ "RecordingStudio::Access" ]
    )
  end
end
