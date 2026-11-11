# frozen_string_literal: true

require "test_helper"

class CreateGateTest < Minitest::Test
  def setup
    @actor = Object.new
    @scope = RecordingStudio::RootSwitchable::ScopeDefinition.new(:workspaces)
    @scope.switchable_root_types = ["Workspace"]
    @scope.creatable_root("Workspace", label: "New workspace", path: "/workspaces/new")
    @scope.validate_creatable_roots!
  end

  def test_allow_redirects_to_the_host_path_with_a_safe_return_to
    outcome = gate

    assert outcome.allow?
    assert_equal "/workspaces/new?return_to=%2Fback", outcome.location
  end

  def test_refuse_redirects_with_the_reason
    @scope.before_root_create do |_ctx|
      RecordingStudio::RootSwitchable::CreateDecision.refuse(redirect_to: "/upgrade", reason: "Teams are full.")
    end

    outcome = gate

    assert outcome.refuse?
    assert_equal "/upgrade", outcome.location
    assert_equal "Teams are full.", outcome.reason
  end

  def test_hide_is_missing_on_the_gate
    @scope.before_root_create { :hide }

    assert gate.missing?
  end

  def test_an_undeclared_type_is_missing
    outcome = gate(type_name: "Page")

    assert outcome.missing?
  end

  def test_a_type_outside_switchable_root_types_is_rejected_at_configure
    scope = RecordingStudio::RootSwitchable::ScopeDefinition.new(:mixed)
    scope.switchable_root_types = ["Workspace"]
    scope.creatable_root("Team", path: "/teams/new")

    error = assert_raises(ArgumentError) { scope.validate_creatable_roots! }

    assert_includes error.message, "Team"
    assert_includes error.message, "switchable_root_types"
  end

  def test_new_root_path_and_creatable_root_together_are_rejected
    @scope.new_root_path = "/other"

    error = assert_raises(ArgumentError) { @scope.validate_creatable_roots! }

    assert_includes error.message, "new_root_path"
  end

  def test_a_raising_hook_refuses_without_raising
    @scope.before_root_create { raise "boom" }

    outcome = gate

    assert outcome.refuse?
    assert_equal "/back", outcome.location
  end

  def test_an_unsafe_redirect_to_is_dropped
    @scope.before_root_create do |_ctx|
      RecordingStudio::RootSwitchable::CreateDecision.refuse(
        redirect_to: "https://evil.example/phish",
        reason: "No"
      )
    end

    outcome = gate

    assert outcome.refuse?
    assert_equal "/back", outcome.location
    refute_includes outcome.location, "evil.example"
  end

  def test_an_unsafe_return_to_is_not_appended
    outcome = gate(return_to: "https://evil.example/phish")

    assert outcome.allow?
    assert_equal "/workspaces/new", outcome.location
  end

  def test_legacy_new_root_path_is_one_creatable_entry_for_a_single_switchable_type
    scope = RecordingStudio::RootSwitchable::ScopeDefinition.new(:legacy)
    scope.switchable_root_types = ["Workspace"]
    scope.new_root_path = "/workspaces/new"
    scope.new_root_label = "New workspace"
    scope.validate_creatable_roots!

    assert_equal ["Workspace"], scope.creatable_catalog.entries.map(&:type_name)
    refute scope.creatable_catalog.direct_legacy?

    outcome = RecordingStudio::RootSwitchable::CreateGate.call(
      scope: scope,
      type_name: "Workspace",
      arguments: arguments(scope, "/back"),
      fallback_location: "/switch"
    )

    assert outcome.allow?
    assert_equal "/workspaces/new?return_to=%2Fback", outcome.location
  end

  def test_legacy_new_root_path_stays_a_direct_link_when_several_types_are_switchable
    scope = RecordingStudio::RootSwitchable::ScopeDefinition.new(:legacy)
    scope.switchable_root_types = %w[Workspace Team]
    scope.new_root_path = "/workspaces/new"

    assert scope.creatable_catalog.direct_legacy?
    assert_empty scope.creatable_catalog.entries
    assert_equal "/workspaces/new", scope.new_root_path_for(actor: @actor)
  end

  def test_display_refuse_keeps_the_type_and_hide_drops_it
    @scope.switchable_root_types = %w[Workspace Team]
    @scope.creatable_root("Team", label: "New team", path: "/teams/new")
    @scope.before_root_create do |ctx|
      next unless ctx.root_type == "Team"

      if ctx.display?
        RecordingStudio::RootSwitchable::CreateDecision.refuse(redirect_to: "/upgrade", reason: "Full")
      else
        :hide
      end
    end

    shown = @scope.creatable_catalog.presented(arguments(@scope, "/back"), mode: :display)
    team = shown.find { |item| item.type_name == "Team" }

    assert_equal "Full", team.disabled_reason
    assert_nil @scope.creatable_catalog.present_type("Team", arguments(@scope, "/back"), mode: :gate)
  end

  private

  def gate(type_name: "Workspace", return_to: "/back")
    RecordingStudio::RootSwitchable::CreateGate.call(
      scope: @scope,
      type_name: type_name,
      arguments: arguments(@scope, return_to),
      fallback_location: "/switch"
    )
  end

  def arguments(scope, return_to)
    {
      actor: @actor,
      controller: Object.new,
      scope: scope,
      current_root_recording: nil,
      return_to: return_to
    }
  end
end
