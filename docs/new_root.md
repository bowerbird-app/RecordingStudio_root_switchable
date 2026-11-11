# New root

A scope can offer a way to start a new root from the switcher. The host owns
the create form and the create action. The gem never writes a recording, a
recordable, or an event.

## Creatable types

```ruby
scope.switchable_root_types = ["Workspace", "Team"]
scope.creatable_root "Workspace",
  label: "New workspace",
  icon: "plus",
  description: "A place for one client's work.",
  path: "/workspaces/new"
scope.creatable_root "Team",
  label: "New team",
  icon: "users",
  path: ->(controller:, **) { controller.main_app.new_team_path }
```

`path` is the host form. A String is used as-is. A callable receives
`controller:`, `actor:`, `device_key:`, `scope:`, `current_root_recording:`,
`return_to:`, and `root_type:`. Return `nil` or `false` to hide that type.
`label`, `icon`, and `description` may also be callables with those keywords.

Every creatable type must be in that scope's `switchable_root_types`. A shared
root (`RecordingStudio.shared_root_type?`) cannot be creatable. Either mistake
raises `ArgumentError` when the scope is configured.

## The `new_root_path` shorthand

`new_root_path`, `new_root_label`, and `new_root_icon` still work.

- One entry in `switchable_root_types`, and `new_root_path` is set: that type
  is the single creatable entry. The menu goes to the gate, then to this path.
  `new_root_label` and `new_root_icon` are the label and icon.
- Zero or several switchable types: `new_root_path` stays a direct host link.
  There is no type to check.
- `creatable_root` and `new_root_path` together raise `ArgumentError`.

The callable for `new_root_path` does not receive `root_type:`. It still
receives `controller:`, `actor:`, `device_key:`, `scope:`,
`current_root_recording:`, and `return_to:`. Unsafe paths are dropped. The gem
adds `return_to` when the path does not already include it.

A blank label uses page copy `new_root_action_label`, then "New workspace".
A blank icon uses page copy `new_root_action_icon`, then `"plus"`. `false` or
`""` draws no icon.

Helper keywords `new_root_path:`, `new_root_label:`, and `new_root_icon:` on
the dropdown and list helpers skip the creatable menu and keep today's
override. `new_root_path: false` hides the entry on that placement.

## One type and several types

One visible type links straight to the gate:

```text
GET /recording_studio_root_switchable/v1/new_root?scope=all_workspaces&type=Workspace&return_to=/
```

Several visible types show "New…" at the bottom of the dropdown, the collapsed
list, and the switch page top nav. The item opens a FlatPack modal. Without
JavaScript, the same list is a page:

```text
GET /recording_studio_root_switchable/v1/new_roots?scope=studio&return_to=/
```

Yield the modal outside the menu:

```erb
<%= yield :recording_studio_new_root_modal %>
```

The switch page renders its own modal and does not need that yield.

## `before_root_create`

```ruby
scope.before_root_create do |ctx|
  next unless ctx.root_type == "Team"

  RecordingStudio::RootSwitchable::CreateDecision.refuse(
    redirect_to: "/upgrade",
    reason: "Teams are full on this plan. Upgrade to add another."
  )
end
```

`config.before_root_create` is the default when the scope sets none. A scope
hook that returns `nil` allows. It does not fall through to the global hook.

`ctx` has `actor`, `scope_key`, `root_type`, `current_root_recording`,
`controller`, `return_to`, and `mode`. `mode` is `:display` while the menu is
built and `:gate` on the gate request. `ctx.display?` and `ctx.gate?` match
that.

| Return | Menu | Gate |
| --- | --- | --- |
| `nil`, `true`, `:allow`, or `CreateDecision.allow` | Link to the gate | Redirect to `path` with a sanitized `return_to` |
| `:hide` or `CreateDecision.hide` | Type is omitted | 404 |
| `CreateDecision.refuse(redirect_to:, reason:)` | Disabled, with the reason | Redirect to a sanitized `redirect_to`, reason flashed |
| Anything else, or a raise | Treated as refuse | Treated as refuse, logged, no crash |

An unsafe `redirect_to` or `return_to` is dropped. Refuse then uses the safe
`return_to`, then the switch page. A blank reason uses page copy
`new_root_disabled_reason`, then "Not available on this plan."

A type that is not creatable is a 404 on the gate.

## Host form

```ruby
class WorkspacesController < ApplicationController
  include RecordingStudio::RootSwitchable::GuardsRootCreation

  guard_root_creation! scope: :all_workspaces, type: "Workspace", only: %i[new create]
end
```

`guard_root_creation!` runs the same hook as a `before_action`. Allow
continues. Hide or an unknown type is a 404. Refuse redirects and flashes
the reason.

After create, the host can switch into the new root:

```ruby
recording_studio_switch_to_root!(root_recording, scope: :all_workspaces)
```

That goes through the switch service. Access checks, shared-root exclusion,
and the rate limit still apply. Nothing switches unless the host calls it.

## Copy

| Key | English |
| --- | --- |
| `recording_studio.root_switchable.dropdown.new_root_menu` | New… |
| `recording_studio.root_switchable.new_root.type_label` | New %{type} |
| `recording_studio.root_switchable.page_copy.new_root_picker_title` | Start something new |
| `recording_studio.root_switchable.page_copy.new_root_picker_body` | Pick one. The form comes next. |
| `recording_studio.root_switchable.page_copy.new_root_disabled_reason` | Not available on this plan. |

Call sites pass an English `default:`.
