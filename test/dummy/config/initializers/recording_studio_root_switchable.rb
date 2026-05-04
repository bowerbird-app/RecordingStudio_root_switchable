# frozen_string_literal: true

RecordingStudioRootSwitchable.configure do |config|
  config.current_actor_resolver = lambda do |controller:|
    Current.actor || controller.current_user
  end

  config.scope :all_workspaces do |scope|
    scope.label = "All workspaces"
    scope.description = "Every accessible workspace root for the current actor."
    scope.available_roots = lambda do |actor:, **|
      RecordingStudioAccessible.root_recordings_for(actor: actor, minimum_role: :view)
                              .select { |root| root.recordable.is_a?(Workspace) }
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
    scope.available_roots = lambda do |actor:, **|
      RecordingStudioAccessible.root_recordings_for(actor: actor, minimum_role: :view)
                              .select { |root| root.recordable.is_a?(Workspace) && root.recordable.name.start_with?("Client") }
    end
    scope.default_root = ->(roots:, **) { roots.first }
    scope.root_description = lambda do |actor:, recording:, **|
      role = RecordingStudioAccessible.role_for(actor: actor, recording: recording)
      "#{recording.recordable.name} · role #{role || "unknown"} · falls back to the first accessible client root when needed"
    end
    scope.page_copy = {
      subtitle: "Choose which client workspace should be current on this device."
    }
  end
end
