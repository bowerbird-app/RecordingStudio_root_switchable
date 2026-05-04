# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioRootSwitchable.instance_variable_get(:@configuration)
    RecordingStudioRootSwitchable.reset_configuration!
  end

  def teardown
    RecordingStudioRootSwitchable.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_load_config_merges_config_for_and_x_config
    x_config = Struct.new(:recording_studio_root_switchable).new(
      { page_copy: { switch_action_label: "Use this root" } }
    )
    app_config = Struct.new(:x).new(x_config)
    app = Struct.new(:config) do
      def config_for(_name)
        { device_key_cookie_options: { same_site: :strict } }
      end
    end.new(app_config)

    find_initializer("recording_studio_root_switchable.load_config").block.call(app)

    assert_equal :strict, RecordingStudioRootSwitchable.configuration.device_key_cookie_options.fetch(:same_site)
    assert_equal "Use this root", RecordingStudioRootSwitchable.configuration.page_copy.fetch(:switch_action_label)
  end

  private

  def find_initializer(name)
    RecordingStudioRootSwitchable::Engine.initializers.find { |initializer| initializer.name == name }
  end
end
