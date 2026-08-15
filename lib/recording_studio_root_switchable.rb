# frozen_string_literal: true

require "recording_studio_root_switchable/version"
require "recording_studio_root_switchable/configuration"
require "recording_studio_root_switchable/redirect_sanitizer"
require "recording_studio_root_switchable/switch_rate_limiter"
require "recording_studio_root_switchable/tailwind_source_linker"
require "recording_studio/root_switchable"
require "recording_studio/root_switchable/current"
require "recording_studio/root_switchable/scope_definition"
require "recording_studio/root_switchable/device_key"
require "recording_studio/root_switchable/device_key_preview"
require "recording_studio/root_switchable/device_metadata"
require "recording_studio/root_switchable/internal_path"
require "recording_studio/root_switchable/root_id"
require "recording_studio/root_switchable/selection_cleanup"
require "recording_studio/root_switchable/controller_support"
require "recording_studio/root_switchable/services/result"
require "recording_studio/root_switchable/services/current_assignment"
require "recording_studio/root_switchable/services/base"
require "recording_studio/root_switchable/services/scope_context"
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
