# frozen_string_literal: true

require "test_helper"

class SelectionTest < Minitest::Test
  FakeSelection = Struct.new(:root_recording, :last_used_at, :save_behavior, keyword_init: true) do
    def save!
      save_behavior.call(self)
    end
  end

  def test_upsert_retries_once_after_unique_constraint_conflict
    root_recording = Struct.new(:id).new("root-1")
    conflicting_selection = FakeSelection.new(
      save_behavior: ->(*) { raise ActiveRecord::RecordNotUnique, "duplicate selection" }
    )
    persisted_selection = FakeSelection.new(save_behavior: ->(*) { true })
    find_calls = 0

    RecordingStudio::RootSwitchable::Selection.stub(
      :find_or_initialize_by,
      lambda do |**attributes|
        find_calls += 1
        assert_equal "device-1", attributes.fetch(:device_key)
        assert_equal "scope-1", attributes.fetch(:scope_key)
        find_calls == 1 ? conflicting_selection : persisted_selection
      end
    ) do
      selection = RecordingStudio::RootSwitchable::Selection.upsert_for(
        actor: nil,
        device_key: "device-1",
        scope_key: "scope-1",
        root_recording: root_recording
      )

      assert_equal persisted_selection, selection
      assert_equal root_recording, persisted_selection.root_recording
      assert_instance_of Time, persisted_selection.last_used_at
      assert_equal 2, find_calls
    end
  end
end
