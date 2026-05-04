# frozen_string_literal: true

module RecordingStudioRootSwitchable
  class Engine < ::Rails::Engine
    CONFIG_KEY = :recording_studio_root_switchable

    isolate_namespace RecordingStudioRootSwitchable

    initializer "recording_studio_root_switchable.load_config" do |app|
      yaml_config = RecordingStudioRootSwitchable::Engine.load_yaml_config(app)
      if yaml_config
        RecordingStudioRootSwitchable.configuration.merge!(yaml_config, source: RecordingStudioRootSwitchable::Engine.yaml_config_source)
      end

      x_config = RecordingStudioRootSwitchable::Engine.load_x_config(app)
      if x_config
        RecordingStudioRootSwitchable::Engine.log_x_config_usage(app) unless yaml_config
        RecordingStudioRootSwitchable.configuration.merge!(x_config, source: RecordingStudioRootSwitchable::Engine.x_config_source)
      end
    end

    def self.load_yaml_config(app)
      return unless app.respond_to?(:config_for)
      return if missing_yaml_config?(app)

      app.config_for(CONFIG_KEY)
    rescue StandardError => e
      raise ConfigurationError.new(source: yaml_config_source, config_key: CONFIG_KEY, detail: e.message), cause: e
    end

    def self.load_x_config(app)
      return unless app.config.respond_to?(:x) && app.config.x.respond_to?(CONFIG_KEY)

      app.config.x.public_send(CONFIG_KEY)
    end

    def self.missing_yaml_config?(app)
      config_path = yaml_config_path(app)
      config_path && !File.exist?(config_path)
    end

    def self.yaml_config_path(app)
      if app.respond_to?(:paths) && app.paths["config"].respond_to?(:first)
        return File.join(app.paths["config"].first.to_s, "#{CONFIG_KEY}.yml")
      end

      return unless app.respond_to?(:root)

      File.join(app.root.to_s, "config", "#{CONFIG_KEY}.yml")
    end

    def self.yaml_config_source
      "config/#{CONFIG_KEY}.yml"
    end

    def self.x_config_source
      "config.x.#{CONFIG_KEY}"
    end

    def self.log_x_config_usage(app)
      logger = if app.respond_to?(:logger) && app.logger.present?
                 app.logger
               elsif defined?(Rails) && Rails.respond_to?(:logger)
                 Rails.logger
               end
      return unless logger

      logger.info(
        "RecordingStudioRootSwitchable: #{yaml_config_source} not found; using #{x_config_source}"
      )
    end
  end
end
