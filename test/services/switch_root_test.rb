# frozen_string_literal: true

require "test_helper"

class SwitchRootTest < Minitest::Test
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

  def test_persists_selected_root_for_scope
    alpha_root = RootRecord.new(id: "alpha", recordable: Struct.new(:name).new("Alpha"), recordable_type: "Workspace")
    beta_root = RootRecord.new(id: "beta", recordable: Struct.new(:name).new("Beta"), recordable_type: "Workspace")
    persisted_selection = Struct.new(:root_recording_id).new("beta")
    controller = Struct.new(:request).new(
      Struct.new(:user_agent).new(
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
        "(KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36"
      )
    )

    configure_roots([alpha_root, beta_root])

    RecordingStudio::RootSwitchable::Selection.stub(:upsert_for, lambda { |**attributes|
      assert_equal "device-1", attributes[:device_key]
      assert_equal "Chrome", attributes.dig(:device_metadata, :device_browser)
      assert_equal "Chrome on macOS", attributes.dig(:device_metadata, :device_label)
      persisted_selection
    }) do
      result = RecordingStudio::RootSwitchable::Services::SwitchRoot.call(
        controller: controller,
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
    alpha_root = RootRecord.new(id: "alpha", recordable: Struct.new(:name).new("Alpha"), recordable_type: "Workspace")

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

  def test_rejects_roots_excluded_by_switchable_root_types
    alpha_root = RootRecord.new(id: "alpha", recordable: Struct.new(:name).new("Alpha"), recordable_type: "Workspace")
    beta_root = RootRecord.new(id: "beta", recordable: Struct.new(:name).new("Beta"), recordable_type: "Page")

    configure_roots([alpha_root, beta_root], switchable_root_types: "Workspace")

    result = RecordingStudio::RootSwitchable::Services::SwitchRoot.call(
      actor: Object.new,
      device_key: "device-1",
      root_recording_id: "beta",
      scope_key: "roots"
    )

    refute result.success?
    assert_includes result.errors, "Selected root is not available for this scope."
    assert_equal [alpha_root], result.available_roots
  end

  def test_rejects_shared_roots_even_when_listed_as_available
    alpha_root = RootRecord.new(id: "alpha", recordable: Struct.new(:name).new("Alpha"), recordable_type: "Workspace")
    shared_root = RootRecord.new(id: "shared", recordable: Struct.new(:name).new("Messages"), recordable_type: "MessageRoot")

    configure_roots([alpha_root, shared_root], switchable_root_types: %w[Workspace MessageRoot])

    with_recording_studio_method(:shared_root?, ->(recording) { recording.id == "shared" }) do
      result = RecordingStudio::RootSwitchable::Services::SwitchRoot.call(
        actor: Object.new,
        device_key: "device-1",
        root_recording_id: "shared",
        scope_key: "roots"
      )

      refute result.success?
      assert_includes result.errors, "Selected root is not available for this scope."
      assert_equal [alpha_root], result.available_roots
    end
  end

  def test_rejects_anonymous_actor_by_default
    alpha_root = RootRecord.new(id: "alpha", recordable: Struct.new(:name).new("Alpha"), recordable_type: "Workspace")
    configure_roots([alpha_root])

    result = RecordingStudio::RootSwitchable::Services::SwitchRoot.call(
      actor: nil,
      device_key: "device-1",
      root_recording_id: "alpha",
      scope_key: "roots"
    )

    refute result.success?
    assert_includes result.errors, "An authenticated actor is required to switch roots."
  end

  private

  def configure_roots(roots, switchable_root_types: nil)
    RecordingStudioRootSwitchable.configure do |config|
      config.scope(:roots) do |scope|
        scope.available_roots = ->(**) { roots }
        scope.switchable_root_types = switchable_root_types
        scope.access_check = ->(**) { true }
        scope.validity_check = ->(**) { true }
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
