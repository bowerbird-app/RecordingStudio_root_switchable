# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "logger"
require "tmpdir"

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
    app = build_app(config: app_config, create_yaml_file: true) do
      def config_for(_name)
        { device_key_cookie_options: { same_site: :strict } }
      end
    end

    find_initializer("recording_studio_root_switchable.load_config").block.call(app)

    assert_equal :strict, RecordingStudioRootSwitchable.configuration.device_key_cookie_options.fetch(:same_site)
    assert_equal "Use this root", RecordingStudioRootSwitchable.configuration.page_copy.fetch(:switch_action_label)
  end

  def test_load_config_initializer_runs_in_engine_instance_context
    x_config = Struct.new(:recording_studio_root_switchable).new(nil)
    app_config = Struct.new(:x).new(x_config)
    app = build_app(config: app_config) do
      def config_for(_name)
        { page_copy: { title: "Loaded from initializer" } }
      end
    end
    File.write(File.join(app.root, "config", "recording_studio_root_switchable.yml"), "test: true\n")

    RecordingStudioRootSwitchable::Engine.instance.instance_exec(
      app,
      &find_initializer("recording_studio_root_switchable.load_config").block
    )

    assert_equal "Loaded from initializer", RecordingStudioRootSwitchable.configuration.page_copy.fetch(:title)
  end

  def test_load_config_prefers_config_x_when_both_sources_set_the_same_key
    x_config = Struct.new(:recording_studio_root_switchable).new(
      { page_copy: { switch_action_label: "Use x config" } }
    )
    app_config = Struct.new(:x).new(x_config)
    app = build_app(config: app_config, create_yaml_file: true) do
      def config_for(_name)
        { page_copy: { switch_action_label: "Use yaml config" } }
      end
    end

    find_initializer("recording_studio_root_switchable.load_config").block.call(app)

    assert_equal "Use x config", RecordingStudioRootSwitchable.configuration.page_copy.fetch(:switch_action_label)
  end

  def test_load_config_ignores_missing_optional_yaml_file
    x_config = Struct.new(:recording_studio_root_switchable).new({ page_copy: { title: "Configured via x" } })
    app_config = Struct.new(:x).new(x_config)
    log_output = StringIO.new
    logger = Logger.new(log_output)
    app = build_app(config: app_config, logger: logger)

    find_initializer("recording_studio_root_switchable.load_config").block.call(app)

    assert_equal "Configured via x", RecordingStudioRootSwitchable.configuration.page_copy.fetch(:title)
    assert_includes log_output.string, "config/recording_studio_root_switchable.yml not found; using config.x.recording_studio_root_switchable"
  end

  def test_load_config_wraps_unexpected_config_for_errors_in_configuration_error
    x_config = Struct.new(:recording_studio_root_switchable).new(nil)
    app_config = Struct.new(:x).new(x_config)
    app = build_app(config: app_config, create_yaml_file: true) do
      def config_for(_name)
        raise "YAML syntax error occurred while parsing /tmp/recording_studio_root_switchable.yml"
      end
    end

    error = assert_raises(RecordingStudioRootSwitchable::ConfigurationError) do
      find_initializer("recording_studio_root_switchable.load_config").block.call(app)
    end

    assert_includes error.message, "YAML syntax error occurred while parsing"
    assert_equal "config/recording_studio_root_switchable.yml", error.source
    assert_equal :recording_studio_root_switchable, error.config_key
  end

  def test_load_config_rejects_invalid_x_config_payloads
    x_config = Struct.new(:recording_studio_root_switchable).new(["invalid"])
    app_config = Struct.new(:x).new(x_config)
    app = build_app(config: app_config) do
      def config_for(_name)
        nil
      end
    end

    error = assert_raises(RecordingStudioRootSwitchable::ConfigurationError) do
      find_initializer("recording_studio_root_switchable.load_config").block.call(app)
    end

    assert_equal "config.x.recording_studio_root_switchable", error.source
    assert_includes error.message, "expected a hash-like value"
  end

  private

  def build_app(config:, logger: nil, create_yaml_file: false, &)
    root = Dir.mktmpdir
    config_dir = File.join(root, "config")
    FileUtils.mkdir_p(config_dir)
    File.write(File.join(config_dir, "recording_studio_root_switchable.yml"), "test: true\n") if create_yaml_file

    klass = Struct.new(:config, :root, :logger, &)
    klass.new(config, root, logger)
  end

  def find_initializer(name)
    RecordingStudioRootSwitchable::Engine.initializers.find { |initializer| initializer.name == name }
  end
end
