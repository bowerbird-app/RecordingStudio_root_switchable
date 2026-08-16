# RecordingStudio Root Switchable

RecordingStudioRootSwitchable is a Rails engine addon for `RecordingStudio`.

It lets a host app resolve and persist a current root recording per actor, per device, and per scope without mutating recordings, recordables, or events.

## What the gem provides

- a gem-owned `recording_studio_root_switchable_selections` table
- request-local state under `RecordingStudio::RootSwitchable::Current`
- per-device persistence through an encrypted cookie-backed `device_key`
- configuration hooks for scopes, available roots, defaults, labels, descriptions, and page copy
- helper APIs for `current_root`, `current_root_recording`, `current_root_recordable`, and `current_root_scope_key`
- a dedicated FlatPack-powered root-switch page
- default access integration through `RecordingStudioAccessible`

This addon was derived from the Recording Studio gem template and keeps the same engine-oriented structure, dummy app workflow, install generator, migration generator, and FlatPack-first UI conventions while replacing the template sample feature with root-switching behavior.

## Update summary (0.3.3 to 0.3.4)

- Default switch-page title and action label are both `Switch` (no backend "root" wording in default UI copy).

## Update summary (0.3.2 to 0.3.3)

- Keep the mounted switch page as a simple chooser: title, list, Current badge, and a short action.
- Default `page_copy` no longer ships explanatory subtitle or persistence-hint text; blank values are not rendered.
- Hosts can still set `subtitle` / `persistence_hint` when they want extra context.

## Update summary (0.3.1 to 0.3.2)

Hardening pass focused on security, performance, and shared helpers:

- Secure device-key cookies by default in production; `httponly` cannot be disabled.
- Sanitize `return_to` before host redirect callbacks and in the dropdown helper.
- Disable anonymous selections and raw user-agent storage by default.
- Throttle `last_used_at` writes, cache available roots per request, and skip duplicate root loads.
- Add `skip_recording_studio_root_resolution`, selection pruning, switch rate limiting, and FK cascade on root delete.
- Drive the mounted page UI from `page_copy` and share path/device-key helpers.

## Installation

Add the gems to your host app:

```ruby
gem "recording_studio", "~> 3.0"
gem "recording_studio_accessible", "~> 0.3"
gem "recording_studio_root_switchable", "~> 0.3.4"
```

Then run:

```bash
bundle install
bin/rails generate recording_studio_root_switchable:install
bin/rails generate recording_studio_root_switchable:migrations
bin/rails db:migrate
```

If you generated an earlier copy of the selection migration before the actor compatibility fix, rerun `bin/rails generate recording_studio_root_switchable:migrations` so the follow-up actor-id conversion migration is copied into your host app.

## Host app setup

Include the controller concern anywhere you want request-local helper methods:

```ruby
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action { Current.actor = current_user }

  include RecordingStudio::RootSwitchable::ControllerSupport

  # Optional: skip resolution on endpoints that do not need a current root.
  # skip_recording_studio_root_resolution only: %i[health]
end
```

Configure scopes in `config/initializers/recording_studio_root_switchable.rb`:

```ruby
RecordingStudioRootSwitchable.configure do |config|
  config.current_actor_resolver = ->(controller:) { Current.actor || controller.current_user }

  # Optional: render the mounted page inside a host layout instead of the gem blank layout.
  # Accepts a String, Symbol, callable, or nil.
  # config.layout = :application_layout

  # Optional: choose where to redirect after a successful switch.
  # Available args: controller:, actor:, device_key:, scope:, root_recording:, return_to:
  # return_to is pre-sanitized to a same-origin relative path (or nil).
  # config.after_switch_redirect = ->(controller:, return_to:, **) do
  #   return_to.presence || controller.main_app.root_path
  # end

  # Optional hardening / privacy knobs (defaults shown):
  # config.allow_anonymous_selections = false
  # config.store_raw_user_agent = false
  # config.last_used_at_touch_interval = 5.minutes
  # config.switch_rate_limit = { limit: 30, period: 1.minute }
  # config.device_key_cookie_options = config.device_key_cookie_options.merge(secure: Rails.env.production?)

  config.scope :all_workspaces do |scope|
    scope.label = "All workspaces"
    scope.description = "Every accessible workspace root"
    # Optional: constrain this scope to root recordings whose recordable_type matches.
    # Accepts nil/blank (no filter), strings, class-name symbols, classes, or arrays.
    # Symbols are converted with to_s, so use :"Workspace"/:Workspace rather than :workspace.
    scope.switchable_root_types = ["Workspace"]
    scope.available_roots = lambda do |actor:, **|
      RecordingStudioAccessible.root_recordings_for(actor: actor, minimum_role: :view)
    end
    scope.default_root = ->(roots:, **) { roots.first }
  end
end
```

`switchable_root_types` defaults to no filtering, preserving existing host app
behavior when it is unset or blank. When configured, it is applied after root
normalization and before the current/default/dropdown/switch result is chosen,
so excluded recordable types cannot be selected for that scope. The filter
compares against `recording.recordable_type` first and only falls back to
`recording.recordable.class.name` when the recording has no stored type.

Use this when `RecordingStudioAccessible` returns structural roots because the
actor has access to descendants inside that root tree, but those root types
should not appear in the user-facing switcher. This is a Root Switchable display
and switching policy only; it does not change RecordingStudio core root
behavior. Roots must still be declared RecordingStudio roots, and access checks
still apply before a root can be selected.

RecordingStudio 3.0 requires every configured recordable to declare its hierarchy
rules explicitly. Root Switchable only treats declared RecordingStudio roots as
switchable roots; parentless recordings are not enough.

```ruby
RecordingStudio.configure do |config|
  config.recordable_types = ["Workspace", "Page"]
end

class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", root: true
end

class Page < ApplicationRecord
  recording_studio_recordable label: "Page", root: false, allowed_parent_types: ["Workspace"]
end
```

Root Switchable does not own any RecordingStudio child recordables itself, so this
gem does not need to register a capability with RecordingStudio core. The only
repo-local v3 compatibility touchpoint is the optional
`RecordingStudioAccessible` integration used by the default scope examples and
dummy app. If your `recording_studio_accessible` version has not yet registered
its addon-owned `RecordingStudio::Access` child recordable, add this temporary
shim in your host `config/initializers/recording_studio_accessible.rb`:

```ruby
if RecordingStudio.respond_to?(:register_capability)
  RecordingStudio.register_capability(
    :accessible,
    source: "recording_studio_accessible",
    child_recordables: ["RecordingStudio::Access"]
  )
end
```

This gem now expects a RecordingStudio 3-compatible
`recording_studio_accessible ~> 0.3` release.

## How query scoping works

The gem does not automatically scope every query in your app to a workspace.

Instead, it resolves a current root once per request and exposes that root through request-local state:

- `RecordingStudio::RootSwitchable.current_root`
- `RecordingStudio::RootSwitchable.current_root_recording`
- `RecordingStudio::RootSwitchable.current_root_recordable`
- `RecordingStudio::RootSwitchable.current_root_scope_key`

That means a host app does **not** need to start every query by re-discovering the workspace. The usual pattern is:

1. set the current actor
2. include `RecordingStudio::RootSwitchable::ControllerSupport`
3. let the gem resolve the active root for the request
4. use the resolved root only in the parts of the app that are meant to be workspace-aware

### Typical controller usage

```ruby
class ProjectsController < ApplicationController
  def index
    workspace = current_root_recordable
    return head :not_found unless workspace

    @projects = Project.where(workspace: workspace)
  end
end
```

### Service usage

```ruby
class SyncWorkspace
  def self.call
    root_recording = RecordingStudio::RootSwitchable.current_root_recording
    return unless root_recording

    WorkspaceSyncJob.perform_later(root_recording.id)
  end
end
```

### Explicit resolution when you need it

```ruby
resolution = RecordingStudio::RootSwitchable.resolve_current_root(
  controller: self,
  actor: Current.actor,
  device_key: RecordingStudio::RootSwitchable.current_device_key,
  scope_key: "all_workspaces"
)

workspace = resolution.root_recording&.recordable
```

### What the gem owns vs what the host app owns

The gem answers: "Which root is current for this actor, on this device, in this scope?"

The host app answers: "Which queries or services should use that current root?"

This separation is intentional. It keeps the gem from applying hidden global query scoping across the host app.

### Configuration sources and precedence

The engine loads optional configuration from two places during boot, in this order:

1. `config/recording_studio_root_switchable.yml`
2. `config.x.recording_studio_root_switchable`

If both sources set the same key, `config.x.recording_studio_root_switchable` wins because it is merged second.

If `config/recording_studio_root_switchable.yml` is absent, the engine skips it and continues booting. If either configuration source is malformed, uses unsupported keys, or provides values with the wrong shape, boot now fails fast with `RecordingStudioRootSwitchable::ConfigurationError` so the host app does not silently fall back to defaults.

Supported boot-time configuration keys are:

- `device_key_cookie_name`
- `device_key_cookie_options`
- `layout`
- `page_copy`
- `after_switch_redirect`

`page_copy` must be a hash whose keys match the documented copy fields exposed by the gem, and each value must be a string.

Default copy is intentionally minimal (`Switch` title + list actions only) and avoids backend "root" wording. Blank `subtitle` and `persistence_hint` values are omitted from the page. Hosts can override any field, for example:

```ruby
config.page_copy = {
  title: "Switch",
  switch_action_label: "Switch",
  subtitle: "Optional context shown under the title.",
  persistence_hint: "Optional note above the list."
}
```

Filtering rules (such as which root types are switchable) belong in scope configuration and docs, not in default page copy.

`layout` controls which Rails layout the mounted root-switch page renders inside. When `layout` is `nil`, the gem uses its own blank layout. Host apps can set `layout` to a String such as `"application"`, a Symbol such as `:application_layout`, or a callable that returns either value per request.

### Actor expectations

The gem is actor-agnostic. It persists selections through a polymorphic `actor` reference and expects the host app to expose the current actor through `Current.actor` or a custom `config.current_actor_resolver`.

### Device-key persistence

Selections are remembered by `actor + device_key + scope_key`.

- `device_key` is a generated random identifier stored in an encrypted cookie
- clearing cookies creates a new device context
- the cookie does not replace authentication; access is revalidated against the current actor on every restore
- production hosts enable `secure` cookies by default and should serve the mounted page over HTTPS
- anonymous actor-less selections are disabled by default; set `allow_anonymous_selections = true` only when required
- raw user-agent strings are not stored unless `store_raw_user_agent = true`
- hosts can prune orphaned rows with `RecordingStudio::RootSwitchable.prune_selections!`

### Scope keys

Scope keys are host-defined identifiers such as `workspace`, `team`, or `account`. Each scope decides:

- which roots are available
- which root is the default
- how labels and descriptions are rendered
- whether a candidate root is valid and accessible

Switchable roots must be valid RecordingStudio 3.0 root recordings. By default,
the available root list comes from
`RecordingStudioAccessible.root_recordings_for(actor:, minimum_role: :view)` and
each candidate is revalidated through RecordingStudio's public root APIs before
it can become current.

## Public API

```ruby
RecordingStudio::RootSwitchable.current_root
RecordingStudio::RootSwitchable.current_root_recording
RecordingStudio::RootSwitchable.current_root_recordable
RecordingStudio::RootSwitchable.current_root_scope_key

RecordingStudio::RootSwitchable.resolve_current_root(
  controller: self,
  actor: Current.actor,
  device_key: RecordingStudio::RootSwitchable.current_device_key,
  scope_key: "all_workspaces"
)
```

## Behavior notes

- selections point at existing `RecordingStudio::Recording` rows
- only root recordings are valid selections
- selections record `last_used_at` so host apps can inspect recent usage
- saved selections are invalidated when they fall out of scope or fail access/validity checks
- fallback uses the configured default root for the active scope, then the first available root
- default access checks use `RecordingStudioAccessible.authorized?`

## Mounted engine routes

Mount the engine wherever you want:

```ruby
mount RecordingStudioRootSwitchable::Engine, at: "/recording_studio_root_switchable"
```

The gem exposes a dedicated root-switch page at:

```text
/recording_studio_root_switchable/v1/root_switch?scope=all_workspaces
```

From a mounted host app, you can link to it with the engine route helper:

```ruby
recording_studio_root_switchable.root_switch_path(scope: "all_workspaces", return_to: request.fullpath)
```

If you want a compact top-nav switcher backed by the same controller action, the gem
also exposes a helper that renders a FlatPack button dropdown using the current root
as the trigger label and the other available roots as PATCH actions:

```erb
<%= recording_studio_root_switch_dropdown(style: :ghost, size: :md) %>
```

If you want to return the user to the page that launched the switcher, pass a `return_to`
param when linking to the mounted page and set `config.after_switch_redirect` to prefer that
path. The gem validates redirect targets and falls back to the root-switch page when the target
is blank or unsafe.

## Dummy app

The dummy app in `test/dummy/` demonstrates:

- Devise authentication with `Current.actor`
- multiple accessible workspace roots
- two scopes (`all_workspaces` and `client_workspaces`)
- per-device persistence through the encrypted cookie-backed device key
- fallback behavior when a persisted selection is no longer valid

Login:

- Email: `admin@admin.com`
- Password: `Password`

These dummy credentials are for local demonstration only and should never be deployed as-is.

## Validation

Standard validation:

```bash
bundle exec rake test
```

If dummy app boot, migrations, or assets change, also validate the dummy app flow used in CI.

## V1 non-goals

- no business-specific workspace/account semantics in gem internals
- no mutation of the RecordingStudio graph when switching roots
- no automatic global query scoping across the host app

The dedicated mounted page remains the primary switcher. A compact FlatPack
dropdown helper is also available for host chrome that needs an inline switcher.

## Documentation

- Gem security notes: [`SECURITY.md`](SECURITY.md)
- Template reference material remains archived under `docs/gem_template/`.
