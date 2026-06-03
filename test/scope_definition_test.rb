# frozen_string_literal: true

require "test_helper"

class ScopeDefinitionTest < Minitest::Test
  RootRecord = Struct.new(:id, :recordable, :recordable_type, keyword_init: true)
  Recordable = Struct.new(:id, keyword_init: true)

  def test_defaults_fail_closed_without_explicit_access_callbacks
    scope = RecordingStudio::RootSwitchable::ScopeDefinition.new(:roots)

    assert_empty scope.available_roots_for(actor: Object.new)
    refute scope.allowed?(actor: Object.new, recording: Object.new)
  end

  def test_default_validity_uses_recording_studio_root_recording_api
    scope = RecordingStudio::RootSwitchable::ScopeDefinition.new(:roots)
    declared_root = RootRecord.new(id: "root", recordable: Object.new, recordable_type: "Workspace")
    child_recording = RootRecord.new(id: "child", recordable: Object.new, recordable_type: "Page")

    with_recording_studio_method(:root_recording?, ->(recording) { recording.id == "root" }) do
      assert scope.valid?(recording: declared_root)
      refute scope.valid?(recording: child_recording)
    end
  end

  def test_available_roots_deduplicates_normalized_candidates
    scope = RecordingStudio::RootSwitchable::ScopeDefinition.new(:roots)
    root = RootRecord.new(id: "root", recordable: Object.new, recordable_type: "Workspace")
    scope.available_roots = ->(**) { [root, root] }

    assert_equal [root], scope.available_roots_for(actor: Object.new)
  end

  def test_recordable_candidate_normalization_requires_root_allowed_existing_recording
    scope = RecordingStudio::RootSwitchable::ScopeDefinition.new(:roots)
    recordable = Recordable.new(id: "workspace-1")
    root = RootRecord.new(id: "root", recordable: recordable, recordable_type: "Workspace")
    expected_recordable = recordable
    relation = Object.new
    relation.define_singleton_method(:where) do |recordable:|
      recordable == expected_recordable ? [root] : []
    end

    scope.available_roots = ->(**) { [recordable] }

    with_recording_studio_method(:root_allowed?, ->(candidate) { candidate == recordable }) do
      with_recording_studio_method(:root_recording?, ->(recording) { recording == root }) do
        with_recording_unscoped(relation) do
          assert_equal [root], scope.available_roots_for(actor: Object.new)
        end
      end
    end
  end

  def test_recordable_candidate_normalization_rejects_non_root_allowed_types
    scope = RecordingStudio::RootSwitchable::ScopeDefinition.new(:roots)
    recordable = Recordable.new(id: "page-1")
    scope.available_roots = ->(**) { [recordable] }

    with_recording_studio_method(:root_allowed?, ->(_) { false }) do
      assert_empty scope.available_roots_for(actor: Object.new)
    end
  end

  private

  def with_recording_studio_method(name, implementation)
    singleton = RecordingStudio.singleton_class
    existed = RecordingStudio.respond_to?(name)
    original = RecordingStudio.method(name) if existed

    singleton.define_method(name, implementation)
    yield
  ensure
    if existed
      singleton.define_method(name, original)
    elsif singleton.method_defined?(name)
      singleton.remove_method(name)
    end
  end

  def with_recording_unscoped(relation)
    existed = RecordingStudio.const_defined?(:Recording, false)
    recording_class = existed ? RecordingStudio.const_get(:Recording) : Class.new
    RecordingStudio.const_set(:Recording, recording_class) unless existed
    singleton = recording_class.singleton_class
    unscoped_existed = recording_class.respond_to?(:unscoped)
    original_unscoped = recording_class.method(:unscoped) if unscoped_existed
    singleton.define_method(:unscoped) { relation }

    yield
  ensure
    if unscoped_existed
      singleton.define_method(:unscoped, original_unscoped)
    elsif singleton&.method_defined?(:unscoped)
      singleton.remove_method(:unscoped)
    end
    RecordingStudio.send(:remove_const, :Recording) unless existed
  end
end
