# frozen_string_literal: true

require "test_helper"

class SwitchRootTest < Minitest::Test
  RootRecord = Struct.new(:id, :recordable, :parent_recording_id, keyword_init: true)

  def setup
    @original_configuration = RecordingStudioRootSwitchable.instance_variable_get(:@configuration)
    RecordingStudioRootSwitchable.reset_configuration!
    RecordingStudio::RootSwitchable::Current.reset
  end

  def teardown
    RecordingStudioRootSwitchable.instance_variable_set(:@configuration, @original_configuration)
    RecordingStudio::RootSwitchable::Current.reset
  end

  def test_persists_selected_root_for_scope
    alpha_root = RootRecord.new(id: "alpha", recordable: Struct.new(:name).new("Alpha"), parent_recording_id: nil)
    beta_root = RootRecord.new(id: "beta", recordable: Struct.new(:name).new("Beta"), parent_recording_id: nil)
    persisted_selection = Struct.new(:root_recording_id).new("beta")

    configure_roots([alpha_root, beta_root])

    RecordingStudio::RootSwitchable::Selection.stub(:upsert_for, persisted_selection) do
      result = RecordingStudio::RootSwitchable::Services::SwitchRoot.call(
        actor: Object.new,
        device_key: "device-1",
        root_recording_id: "beta",
        scope_key: "roots"
      )

      assert result.success?
      assert_equal "beta", result.root_recording.id
      assert_equal "beta", RecordingStudio::RootSwitchable.current_root_recording.id
    end
  end

  def test_rejects_unknown_roots
    alpha_root = RootRecord.new(id: "alpha", recordable: Struct.new(:name).new("Alpha"), parent_recording_id: nil)

    configure_roots([alpha_root])

    result = RecordingStudio::RootSwitchable::Services::SwitchRoot.call(
      actor: Object.new,
      device_key: "device-1",
      root_recording_id: "missing",
      scope_key: "roots"
    )

    refute result.success?
    assert_includes result.errors, "Selected root is not available for this scope."
  end

  private

  def configure_roots(roots)
    RecordingStudioRootSwitchable.configure do |config|
      config.scope(:roots) do |scope|
        scope.available_roots = ->(**) { roots }
      end
    end
  end
end
