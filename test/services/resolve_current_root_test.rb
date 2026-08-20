# frozen_string_literal: true

require "test_helper"

class ResolveCurrentRootTest < Minitest::Test
  RootRecord = Struct.new(:id, :recordable, :recordable_type, keyword_init: true)

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
    alpha_root = RootRecord.new(id: "alpha", recordable: Struct.new(:name).new("Alpha"), recordable_type: "Workspace")
    beta_root = RootRecord.new(id: "beta", recordable: Struct.new(:name).new("Beta"), recordable_type: "Workspace")
    selection = Struct.new(:root_recording_id, :last_used_at) do
      def update_columns(attributes)
        self.last_used_at = attributes.fetch(:last_used_at)
      end
    end.new("beta", nil)

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
      assert selection.last_used_at
    end
  end

  def test_invalid_selection_is_destroyed_and_default_root_is_used
    alpha_root = RootRecord.new(id: "alpha", recordable: Struct.new(:name).new("Alpha"), recordable_type: "Workspace")
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

  def test_default_root_selection_uses_filtered_available_roots
    page_root = RootRecord.new(id: "page", recordable: Struct.new(:name).new("Page"), recordable_type: "Page")
    workspace_root = RootRecord.new(
      id: "workspace",
      recordable: Struct.new(:name).new("Workspace"),
      recordable_type: "Workspace"
    )

    configure_roots([page_root, workspace_root], switchable_root_types: "Workspace") do |scope|
      scope.default_root = ->(**) { page_root }
    end

    RecordingStudio::RootSwitchable::Selection.stub(:lookup, nil) do
      result = RecordingStudio::RootSwitchable::Services::ResolveCurrentRoot.call(
        actor: Object.new,
        device_key: "device-1",
        scope_key: "roots"
      )

      assert result.success?
      assert_equal [workspace_root], result.available_roots
      assert_equal workspace_root, result.root_recording
      assert_equal :default, result.selected_via
    end
  end

  def test_shared_root_selection_is_destroyed_and_owned_default_is_used
    workspace_root = RootRecord.new(
      id: "workspace",
      recordable: Struct.new(:name).new("Workspace"),
      recordable_type: "Workspace"
    )
    shared_root = RootRecord.new(
      id: "shared",
      recordable: Struct.new(:name).new("Messages"),
      recordable_type: "MessageRoot"
    )
    removed_selection = Struct.new(:root_recording_id, :destroyed) do
      def destroy
        self.destroyed = true
      end
    end.new("shared", false)

    configure_roots([workspace_root, shared_root], switchable_root_types: %w[Workspace MessageRoot])

    with_recording_studio_method(:shared_root?, ->(recording) { recording.id == "shared" }) do
      RecordingStudio::RootSwitchable::Selection.stub(:lookup, removed_selection) do
        result = RecordingStudio::RootSwitchable::Services::ResolveCurrentRoot.call(
          actor: Object.new,
          device_key: "device-1",
          scope_key: "roots"
        )

        assert result.success?
        assert_equal [workspace_root], result.available_roots
        assert_equal workspace_root, result.root_recording
        assert_equal :default, result.selected_via
        assert removed_selection.destroyed
      end
    end
  end

  def test_does_not_touch_recent_last_used_at
    alpha_root = RootRecord.new(id: "alpha", recordable: Struct.new(:name).new("Alpha"), recordable_type: "Workspace")
    selection = Struct.new(:root_recording_id, :last_used_at) do
      attr_accessor :touch_count

      def update_columns(_attributes)
        self.touch_count = (touch_count || 0) + 1
      end
    end.new("alpha", Time.current)
    selection.touch_count = 0

    configure_roots([alpha_root])
    RecordingStudioRootSwitchable.configuration.last_used_at_touch_interval = 5.minutes

    RecordingStudio::RootSwitchable::Selection.stub(:lookup, selection) do
      RecordingStudio::RootSwitchable::Services::ResolveCurrentRoot.call(
        actor: Object.new,
        device_key: "device-1",
        scope_key: "roots"
      )
    end

    assert_equal 0, selection.touch_count
  end

  private

  def configure_roots(roots, switchable_root_types: nil)
    RecordingStudioRootSwitchable.configure do |config|
      config.scope(:roots) do |scope|
        scope.available_roots = ->(**) { roots }
        scope.switchable_root_types = switchable_root_types
        scope.access_check = ->(**) { true }
        scope.validity_check = ->(**) { true }
        yield(scope) if block_given?
      end
    end
  end

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
end
