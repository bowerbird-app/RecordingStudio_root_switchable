# frozen_string_literal: true

require "test_helper"

class ResolveCurrentRootTest < Minitest::Test
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

  def test_prefers_persisted_selection_when_it_is_still_available
    alpha_root = RootRecord.new(id: "alpha", recordable: Struct.new(:name).new("Alpha"), parent_recording_id: nil)
    beta_root = RootRecord.new(id: "beta", recordable: Struct.new(:name).new("Beta"), parent_recording_id: nil)
    selection = Struct.new(:root_recording_id).new("beta")

    configure_roots([alpha_root, beta_root])

    RecordingStudio::RootSwitchable::Selection.stub(:lookup, selection) do
      result = RecordingStudio::RootSwitchable::Services::ResolveCurrentRoot.call(
        actor: Object.new,
        device_key: "device-1",
        scope_key: "roots"
      )

      assert result.success?
      assert_equal "beta", result.root_recording.id
      assert_equal :persisted, result.selected_via
      assert_equal "beta", RecordingStudio::RootSwitchable.current_root_recording.id
    end
  end

  def test_invalid_selection_is_destroyed_and_default_root_is_used
    alpha_root = RootRecord.new(id: "alpha", recordable: Struct.new(:name).new("Alpha"), parent_recording_id: nil)
    removed_selection = Struct.new(:root_recording_id, :destroyed) do
      def destroy
        self.destroyed = true
      end
    end.new("missing", false)

    configure_roots([alpha_root])

    RecordingStudio::RootSwitchable::Selection.stub(:lookup, removed_selection) do
      result = RecordingStudio::RootSwitchable::Services::ResolveCurrentRoot.call(
        actor: Object.new,
        device_key: "device-1",
        scope_key: "roots"
      )

      assert result.success?
      assert_equal "alpha", result.root_recording.id
      assert_equal :default, result.selected_via
      assert removed_selection.destroyed
    end
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
