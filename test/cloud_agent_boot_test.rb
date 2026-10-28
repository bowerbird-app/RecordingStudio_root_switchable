# frozen_string_literal: true

require "json"
require "yaml"
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
    fetch_line = install.lines.grep(/fetch-skills\.sh/).last

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
    refute_match(%r{^[^#]*\$\{HOME\}/\.cursor}, fetch)
    refute_match(%r{^[^#]*~/\.cursor}, fetch)
  end

  def test_gitignore_excludes_fetched_skills_and_rules
    gitignore = File.read(File.join(ROOT, ".gitignore"))

    assert_includes gitignore, ".cursor/skills/"
    assert_includes gitignore, ".cursor/rules/"
  end

  def test_dummy_coverage_is_ignored_and_untracked
    sample = "test/dummy/coverage/index.html"
    ignored = git("check-ignore", "--no-index", "-v", "--", sample)

    assert_match(%r{\.gitignore:\d+:coverage/\s+#{Regexp.escape(sample)}}, ignored)

    tracked = git("ls-files", "--", "test/dummy/coverage")
    assert_equal "", tracked
  end

  def test_dummy_nested_ci_workflow_is_absent
    refute File.exist?(File.join(ROOT, "test/dummy/.github/workflows/ci.yml"))
  end

  def test_security_workflow_runs_brakeman_and_bundler_audit_on_dummy
    workflow = YAML.safe_load_file(File.join(ROOT, ".github/workflows/security.yml"))

    assert_equal "Security", workflow["name"]
    assert_equal %w[bundler-audit brakeman importmap-audit], workflow["jobs"].keys

    assert_equal "test/dummy", workflow.dig("jobs", "bundler-audit", "steps").last["working-directory"]
    assert_equal "bin/bundler-audit", workflow.dig("jobs", "bundler-audit", "steps").last["run"]
    assert_equal "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error",
                 workflow.dig("jobs", "brakeman", "steps").last["run"]
  end

  def test_bundler_shim_and_gem_template_archive_are_gone
    refute File.exist?(File.join(ROOT, "test/support/widen_recording_studio_requirement.rb"))
    refute File.exist?(File.join(ROOT, "docs/gem_template"))
    refute File.exist?(File.join(ROOT, ".github/agents/rails_architect.agent.md"))

    gemfile = File.read(File.join(ROOT, "Gemfile"))
    dummy_gemfile = File.read(File.join(ROOT, "test/dummy/Gemfile"))
    refute_includes gemfile, "widen_recording_studio_requirement"
    refute_includes dummy_gemfile, "widen_recording_studio_requirement"
  end

  def test_ci_runs_the_full_dummy_suite_then_rubocop_and_the_gem_suite
    workflow = YAML.safe_load_file(File.join(ROOT, ".github/workflows/ci.yml"))
    steps = workflow.dig("jobs", "test", "steps")
    runs = steps.filter_map { |step| step["run"] }
    dummy_runs = steps.select { |step| step["working-directory"] == "test/dummy" }.filter_map { |step| step["run"] }

    assert_includes dummy_runs, "bundle exec rails test"
    refute(dummy_runs.any? { |run| run.include?("_test.rb") })
    assert_includes runs, "bundle exec rubocop"
    assert_includes runs, "bundle exec rake app:test"
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
    cursor_files = spec.files.select { |path| path.start_with?(".cursor/") }
    assert_empty cursor_files
  end

  private

  def git(*args)
    IO.popen(["git", "-C", ROOT, *args], &:read)
  end
end
