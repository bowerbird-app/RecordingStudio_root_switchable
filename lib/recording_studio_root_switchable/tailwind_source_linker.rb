# frozen_string_literal: true

module RecordingStudioRootSwitchable
  module TailwindSourceLinker
    module_function

    def link!(rails_root: Rails.root)
      require "fileutils"

      vendor_dir = rails_root.join("vendor")
      FileUtils.mkdir_p(vendor_dir)

      gem_links.each do |link_name, gem_names|
        source = gem_names.filter_map { |gem_name| resolve_gem_path(gem_name) }.first
        destination = vendor_dir.join(link_name)

        unless source && Dir.exist?(source)
          warn "recording_studio_root_switchable:link_tailwind_sources skipped #{link_name}"
          next
        end

        if recursive_link?(source, rails_root)
          warn "recording_studio_root_switchable:link_tailwind_sources skipped #{link_name}: " \
               "gem path contains the app root"
          next
        end

        FileUtils.rm_f(destination) if File.symlink?(destination) || File.exist?(destination)
        File.symlink(source, destination)
        puts "Linked vendor/#{link_name} -> #{source}"
      end
    end

    def gem_links
      {
        "flat_pack" => %w[flat_pack],
        "recording_studio_root_switchable" => %w[recording_studio_root_switchable],
        "recording_studio" => %w[recording_studio]
      }
    end
    private_class_method :gem_links

    def resolve_gem_path(gem_name)
      Bundler.rubygems.find_name(gem_name).first&.full_gem_path ||
        Bundler.load.specs.find { |spec| spec.name == gem_name }&.full_gem_path
    rescue StandardError
      nil
    end
    private_class_method :resolve_gem_path

    def recursive_link?(source, rails_root)
      source_pathname = Pathname.new(source).expand_path
      root = rails_root.expand_path
      source_pathname == root || root.to_s.start_with?("#{source_pathname}/")
    rescue StandardError
      false
    end
    private_class_method :recursive_link?
  end
end
