# frozen_string_literal: true

# Dummy-app convenience wrappers around the engine Tailwind source linker.
namespace :gem_sources do
  desc "Symlink FlatPack and RecordingStudio into vendor/ for Tailwind @source scanning"
  task link: :environment do
    Rake::Task["recording_studio_root_switchable:link_tailwind_sources"].invoke
  end
end

Rake::Task["tailwindcss:build"].enhance(["gem_sources:link"]) if Rake::Task.task_defined?("tailwindcss:build")
Rake::Task["tailwindcss:watch"].enhance(["gem_sources:link"]) if Rake::Task.task_defined?("tailwindcss:watch")
