# frozen_string_literal: true

RecordingStudioRootSwitchable.configure do |config|
  config.current_actor_resolver = lambda do |controller:|
    Current.actor || controller.current_user
  end

  config.default_scope_key_resolver = lambda do |**|
    "all_roots"
  end

  config.after_switch_redirect = lambda do |controller:, return_to:, **|
    return_to.presence || controller.main_app.root_path
  end

  config.scope :all_workspaces do |scope|
    scope.label = "All workspaces"
    scope.description = "Every accessible workspace root for the current actor."
    scope.switchable_root_types = "Workspace"
    scope.available_roots = lambda do |actor:, **|
      RecordingStudioAccessible.root_recordings_for(actor: actor, minimum_role: :view)
    end
    scope.default_root = lambda do |roots:, **|
      roots.find { |root| root.recordable.name == "Studio Workspace" } || roots.first
    end
    scope.root_description = lambda do |actor:, recording:, **|
      role = RecordingStudioAccessible.role_for(actor: actor, recording: recording)
      "#{recording.recordable.name} · access role #{role || "unknown"}"
    end
  end

  config.scope :client_workspaces do |scope|
    scope.label = "Client workspaces"
    scope.description = "A narrower scope that only exposes client-facing roots."
    scope.switchable_root_types = "Workspace"
    scope.available_roots = lambda do |actor:, **|
      RecordingStudioAccessible.root_recordings_for(actor: actor, minimum_role: :view)
                              .select { |root| root.recordable.is_a?(Workspace) && root.recordable.name.start_with?("Client") }
    end
    scope.default_root = ->(roots:, **) { roots.first }
    scope.root_description = lambda do |actor:, recording:, **|
      role = RecordingStudioAccessible.role_for(actor: actor, recording: recording)
      "#{recording.recordable.name} · role #{role || "unknown"} · falls back to the first accessible client root when needed"
    end
  end

  config.scope :all_roots do |scope|
    scope.label = "All roots"
    scope.description = "Every accessible root type except Team roots, which are excluded by switchable_root_types."
    scope.switchable_root_types = [ "Workspace", "Page" ]
    scope.available_roots = lambda do |actor:, **|
      RecordingStudioAccessible.root_recordings_for(actor: actor, minimum_role: :view)
    end
    scope.default_root = ->(roots:, **) { roots.first }
    scope.root_description = lambda do |actor:, recording:, **|
      role = RecordingStudioAccessible.role_for(actor: actor, recording: recording)
      "#{recording.recordable.class.name} · #{recording.recordable.try(:name) || recording.recordable.try(:title)} · role #{role || "unknown"}"
    end
  end
end
