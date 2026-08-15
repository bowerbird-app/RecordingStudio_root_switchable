# frozen_string_literal: true

namespace :recording_studio_root_switchable do
  desc "Symlink FlatPack and related gems into vendor/ for Tailwind @source scanning"
  task link_tailwind_sources: :environment do
    require "recording_studio_root_switchable/tailwind_source_linker"
    RecordingStudioRootSwitchable::TailwindSourceLinker.link!
  end
end

# Keep host Tailwind builds in sync with installed gem locations.
%w[tailwindcss:build tailwindcss:watch].each do |task_name|
  next unless Rake::Task.task_defined?(task_name)

  task = Rake::Task[task_name]
  prerequisite = "recording_studio_root_switchable:link_tailwind_sources"
  next if task.prerequisites.include?(prerequisite)

  task.enhance([prerequisite])
end
