# frozen_string_literal: true

require "recording_studio_root_switchable/version"
require "recording_studio_root_switchable/configuration"
require "recording_studio/root_switchable"
require "recording_studio/root_switchable/current"
require "recording_studio/root_switchable/scope_definition"
require "recording_studio/root_switchable/device_key"
require "recording_studio/root_switchable/controller_support"
require "recording_studio/root_switchable/services/result"
require "recording_studio/root_switchable/services/resolve_current_root"
require "recording_studio/root_switchable/services/switch_root"
require "recording_studio_root_switchable/engine"

module RecordingStudioRootSwitchable
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
