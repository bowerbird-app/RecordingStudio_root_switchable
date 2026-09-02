# frozen_string_literal: true

require "json"
require "test_helper"

class CloudAgentBootTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_environment_json_runs_install_and_start_hooks
    config = JSON.parse(File.read(File.join(ROOT, ".cursor/environment.json")))

    assert_equal ".cursor/install.sh", config["install"]
    assert_equal ".cursor/start.sh", config["start"]
  end

  def test_install_sh_fetches_skills_last_without_or_true
    install = File.read(File.join(ROOT, ".cursor/install.sh"))
    fetch_line = install.lines.grep(%r{fetch-skills\.sh}).last

    refute_nil fetch_line
    refute_includes fetch_line, "|| true"

    commands = install.lines.map(&:strip).reject do |line|
      line.empty? || line.start_with?("#") || line.start_with?("log ")
    end
    assert_equal '"${SCRIPT_DIR}/fetch-skills.sh"', commands.last
  end

  def test_install_sh_skips_provision_when_ruby_bundle_and_postgres_are_usable
    install = File.read(File.join(ROOT, ".cursor/install.sh"))

    assert_includes install, "ruby_ok && bundle_ok && postgres_ok"
    assert_includes install, "skipping apt, ruby-build, db:prepare, and tailwind"
  end

  def test_fetch_skills_writes_repo_cursor_dirs_not_home
    fetch = File.read(File.join(ROOT, ".cursor/fetch-skills.sh"))

    assert_includes fetch, 'SKILLS_DIR="${ROOT}/.cursor/skills"'
    assert_includes fetch, 'RULES_DIR="${ROOT}/.cursor/rules"'
    refute_match(/^[^#]*\$\{HOME\}\/\.cursor/, fetch)
    refute_match(/^[^#]*~\/\.cursor/, fetch)
  end

  def test_gitignore_excludes_fetched_skills_and_rules
    gitignore = File.read(File.join(ROOT, ".gitignore"))

    assert_includes gitignore, ".cursor/skills/"
    assert_includes gitignore, ".cursor/rules/"
  end

  def test_lockfiles_match_gem_version
    version = RecordingStudioRootSwitchable::VERSION

    %w[Gemfile.lock test/dummy/Gemfile.lock].each do |relative|
      lock = File.read(File.join(ROOT, relative))
      assert_includes lock, "recording_studio_root_switchable (#{version})", relative
    end
  end

  def test_gemspec_excludes_cursor_boot_files
    spec = Gem::Specification.load(File.join(ROOT, "recording_studio_root_switchable.gemspec"))

    refute_nil spec
    assert spec.files.none? { |path| path.start_with?(".cursor/") }
  end
end
