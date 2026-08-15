# frozen_string_literal: true

namespace :recording_studio_root_switchable do
  desc "Symlink FlatPack and related gems into vendor/ for Tailwind @source scanning"
  task link_tailwind_sources: :environment do
    require "fileutils"

    resolve_gem_path = lambda do |gem_name|
      Bundler.rubygems.find_name(gem_name).first&.full_gem_path ||
        Bundler.load.specs.find { |spec| spec.name == gem_name }&.full_gem_path
    rescue StandardError
      nil
    end

    recursive_link = lambda do |source|
      source_pathname = Pathname.new(source).expand_path
      rails_root = Rails.root.expand_path
      source_pathname == rails_root || rails_root.to_s.start_with?("#{source_pathname}/")
    rescue StandardError
      false
    end

    vendor_dir = Rails.root.join("vendor")
    FileUtils.mkdir_p(vendor_dir)

    {
      "flat_pack" => %w[flat_pack],
      "recording_studio_root_switchable" => %w[recording_studio_root_switchable],
      "recording_studio" => %w[recording_studio]
    }.each do |link_name, gem_names|
      source = gem_names.filter_map { |gem_name| resolve_gem_path.call(gem_name) }.first
      destination = vendor_dir.join(link_name)

      unless source && Dir.exist?(source)
        warn "recording_studio_root_switchable:link_tailwind_sources skipped #{link_name}"
        next
      end

      if recursive_link.call(source)
        warn "recording_studio_root_switchable:link_tailwind_sources skipped #{link_name}: " \
             "gem path contains the app root"
        next
      end

      FileUtils.rm_f(destination) if File.symlink?(destination) || File.exist?(destination)
      File.symlink(source, destination)
      puts "Linked vendor/#{link_name} -> #{source}"
    end
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
