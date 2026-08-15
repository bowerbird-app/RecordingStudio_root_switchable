# frozen_string_literal: true

# Dummy-app convenience alias around the engine Tailwind source linker.
desc "Symlink FlatPack and RecordingStudio into vendor/ for Tailwind @source scanning"
task "gem_sources:link" => "recording_studio_root_switchable:link_tailwind_sources"
