class HomeController < ApplicationController
  def index
    @scope_rows = build_scope_rows
    @current_scope_row = @scope_rows.find { |row| row[:scope_key] == current_root_scope_key } || @scope_rows.first
  end

  private

  def build_scope_rows
    current_state = {
      root_recordable: RecordingStudio::RootSwitchable::Current.root_recordable,
      root_recording: RecordingStudio::RootSwitchable::Current.root_recording,
      scope: RecordingStudio::RootSwitchable::Current.scope,
      scope_key: RecordingStudio::RootSwitchable::Current.scope_key,
      selection: RecordingStudio::RootSwitchable::Current.selection
    }

    RecordingStudioRootSwitchable.configuration.scopes.keys.map do |scope_key|
      RecordingStudio::RootSwitchable::Current.set(current_state) do
        result = RecordingStudio::RootSwitchable::Services::ResolveCurrentRoot.call(
          controller: self,
          actor: Current.actor,
          device_key: current_root_device_key,
          scope_key: scope_key
        )

        {
          available_roots: result.available_roots.map { |root| root.recordable.name },
          current_root_label: result.root_recording&.recordable&.name,
          scope_description: result.scope.description_for(controller: self, actor: Current.actor, device_key: current_root_device_key),
          scope_key: scope_key,
          scope_label: result.scope.label_for(controller: self, actor: Current.actor, device_key: current_root_device_key),
          selected_via: result.selected_via
        }
      end
    end
  end
end
