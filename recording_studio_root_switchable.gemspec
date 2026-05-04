# frozen_string_literal: true

require_relative "lib/recording_studio_root_switchable/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_root_switchable"
  spec.version     = RecordingStudioRootSwitchable::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_root_switchable"
  spec.summary     = "Reusable root selection and switching addon for RecordingStudio"
  spec.description = "Persists per-actor, per-device root selections for RecordingStudio, " \
                     "exposes a FlatPack-powered switching page, and integrates access checks " \
                     "through RecordingStudioAccessible."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bowerbird-app/RecordingStudio_root_switchable"
  spec.metadata["changelog_uri"] = "https://github.com/bowerbird-app/RecordingStudio_root_switchable/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "flat_pack"
  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio"
  spec.add_dependency "recording_studio_accessible"
end
