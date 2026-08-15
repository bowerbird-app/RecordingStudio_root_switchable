# frozen_string_literal: true

namespace :gem_sources do
  desc "Symlink FlatPack and RecordingStudio into vendor/ for Tailwind @source scanning"
  task link: :environment do
    require "fileutils"

    vendor_dir = Rails.root.join("vendor")
    FileUtils.mkdir_p(vendor_dir)

    {
      "flat_pack" => "flat_pack",
      "recording_studio" => "recording_studio"
    }.each do |link_name, gem_name|
      destination = vendor_dir.join(link_name)
      source = Bundler.rubygems.find_name(gem_name).first&.full_gem_path
      source ||= begin
        spec = Bundler.load.specs.find { |entry| entry.name == gem_name }
        spec&.full_gem_path
      end

      unless source && Dir.exist?(source)
        warn "gem_sources:link skipped #{link_name}: could not locate #{gem_name}"
        next
      end

      FileUtils.rm_f(destination) if File.symlink?(destination) || File.exist?(destination)
      File.symlink(source, destination)
      puts "Linked vendor/#{link_name} -> #{source}"
    end
  end
end

# Ensure Tailwind builds always see gem component classes.
Rake::Task["tailwindcss:build"].enhance(["gem_sources:link"]) if Rake::Task.task_defined?("tailwindcss:build")
Rake::Task["tailwindcss:watch"].enhance(["gem_sources:link"]) if Rake::Task.task_defined?("tailwindcss:watch")
