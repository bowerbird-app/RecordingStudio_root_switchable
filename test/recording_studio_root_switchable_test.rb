# frozen_string_literal: true

require "test_helper"

class RecordingStudioRootSwitchableTest < Minitest::Test
  def test_version_exists
    refute_nil RecordingStudioRootSwitchable::VERSION
  end

  def test_engine_exists
    assert_kind_of Class, RecordingStudioRootSwitchable::Engine
  end

  def test_public_current_helpers_are_exposed
    RecordingStudio::RootSwitchable::Current.scope_key = "roots"
    RecordingStudio::RootSwitchable::Current.root = :example_root

    assert_equal "roots", RecordingStudio::RootSwitchable.current_root_scope_key
    assert_equal :example_root, RecordingStudio::RootSwitchable::Current.root
  ensure
    RecordingStudio::RootSwitchable::Current.reset
  end

  def test_dummy_app_schema_includes_root_switchable_selection_table
    schema_path = File.expand_path("dummy/db/schema.rb", __dir__)
    schema_source = File.read(schema_path)

    assert_includes schema_source, 'create_table "recording_studio_root_switchable_selections"'
    assert_includes schema_source, 't.string "actor_id"'
    assert_includes schema_source, 't.datetime "last_used_at", null: false'
  end

  def test_dummy_app_documents_root_switch_demo_routes
    dummy_readme_path = File.expand_path("dummy/README.md", __dir__)
    dummy_readme_source = File.read(dummy_readme_path)

    assert_includes dummy_readme_source, "/recording_studio_root_switchable/v1/root_switch?scope=all_workspaces"
    assert_includes dummy_readme_source, "per-device persistence"
  end

  def test_dummy_app_includes_root_switchable_migration
    migration_files = Dir.glob(File.expand_path("dummy/db/migrate/*root_switchable*selection*.rb", __dir__))

    refute_empty migration_files
  end
end
