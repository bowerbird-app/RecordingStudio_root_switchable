# frozen_string_literal: true

module RecordingStudioRootSwitchable
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioRootSwitchable

    initializer "recording_studio_root_switchable.load_config" do |app|
      if app.respond_to?(:config_for)
        begin
          yaml_config = app.config_for(:recording_studio_root_switchable)
          RecordingStudioRootSwitchable.configuration.merge!(yaml_config)
        rescue StandardError
          nil
        end
      end

      if app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_root_switchable)
        RecordingStudioRootSwitchable.configuration.merge!(app.config.x.recording_studio_root_switchable)
      end
    end
  end
end
