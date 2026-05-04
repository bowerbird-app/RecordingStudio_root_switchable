# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "generators/recording_studio_root_switchable/migrations/migrations_generator"

class MigrationsGeneratorTest < Minitest::Test
  def with_temp_app
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "db/migrate"))
      yield dir
    end
  end

  def build_generator(destination_root, options = {})
    RecordingStudioRootSwitchable::Generators::MigrationsGenerator.new(
      [],
      options,
      destination_root: destination_root
    )
  end

  def test_copy_migrations_adds_follow_up_actor_id_fix_when_create_migration_already_exists
    with_temp_app do |dir|
      File.write(
        File.join(dir, "db/migrate/20250101000001_create_recording_studio_root_switchable_selections.rb"),
        "# existing host-app migration\n"
      )

      generator = build_generator(dir)

      generator.stub(:say, nil) do
        generator.copy_migrations
      end

      migration_files = Dir.glob(File.join(dir, "db/migrate/*.rb")).map { |path| File.basename(path) }

      assert_equal 3, migration_files.size
      assert_includes migration_files.join("\n"), "add_device_metadata_to_recording_studio_root_switchable_selections.rb"
      assert_includes migration_files.join("\n"), "change_recording_studio_root_switchable_selection_actor_id_to_string.rb"
      assert_equal 1, migration_files.grep(/create_recording_studio_root_switchable_selections/).size
    end
  end
end
