# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  # Fail closed for new grants unless actor types are allowlisted (RSA 0.5+).
  config.access_actor_types = [ "User" ]

  # Accessible 0.45 denies mounted pages unless this returns the admin root.
  # Studio Workspace is that root. The seeded admin holds the admin role there.
  config.admin_root_resolver = lambda do
    workspace = Workspace.find_by(name: "Studio Workspace")
    next unless workspace

    RecordingStudio.root_recording_for(workspace)
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
