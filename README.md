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

## Upgrading to 0.5.0 (shared roots)

Use this checklist when moving from `0.4.0` to `0.5.0` on RecordingStudio 4.1 shared roots.

### 1. Upgrade sibling gems first

```ruby
gem "recording_studio", "~> 4.1"                 # e.g. tag v4.1.0
gem "recording_studio_accessible", "~> 0.6"      # e.g. tag v0.6.0
gem "recording_studio_root_switchable", "~> 0.5"
```

```bash
bundle update recording_studio recording_studio_accessible recording_studio_root_switchable
```

### 2. Declare shared roots correctly (if you use them)

```ruby
class MessagesRoot < ApplicationRecord
  recording_studio_recordable label: "Messages", root: true, shared: true
end
```

Enable Accessible on domain children beneath the shared root, not on the shared root itself. Accessible `0.6.0` already excludes shared roots from `root_recordings_for`.

### 3. Expect the switcher to ignore shared roots

Root Switchable never resolves, shows, or switches into a shared root — even when:

- a custom `available_roots` returns one
- `switchable_root_types` lists the shared type
- a legacy selection still points at a shared root (it is destroyed and an owned default is used)

No migration is required for this gem.

### 4. Smoke-test root switching

- Mounted switch page and dropdown only list owned roots
- Shared roots never appear as switch targets
- Team / other type filters via `switchable_root_types` still work

## Upgrading to 0.4.0 (RecordingStudio 4.0)

Use this checklist when moving from `0.3.x` (RecordingStudio 3) to `0.4.0` (RecordingStudio 4). Prefer `0.5.0` if you are already on RecordingStudio 4.1.

### 1. Upgrade sibling gems first

```ruby
gem "recording_studio", "~> 4.0"                 # e.g. tag v4.0.0
gem "recording_studio_accessible", "~> 0.6"      # RS 4 support release
gem "recording_studio_root_switchable", "~> 0.4"
```

Until Accessible `0.6.0` is tagged on `main`, pin the published support branch/ref your team uses for that release.

```bash
bundle update recording_studio recording_studio_accessible recording_studio_root_switchable
```

### 2. Install and run RecordingStudio 4.0 migrations

```bash
bin/rails generate recording_studio:migrations
bin/rails db:migrate
```

Resolve any duplicate root recordings before the unique-root index is created. See RecordingStudio `docs/UPGRADING.md` (Upgrading To 4.0.0).

### 3. Refresh this gem’s migrations if needed

```bash
bin/rails generate recording_studio_root_switchable:migrations
bin/rails db:migrate
```

### 4. Update host recordables for Accessible 0.6

Remove the old addon mixin/API and enable the RecordingStudio capability instead:

```ruby
# before
class Workspace < ApplicationRecord
  include RecordingStudioAccessible::AllowsAccessibleChildren
  recording_studio_recordable label: "Workspace", root: true
  recording_studio_accessible_children :access
end

# after
class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", root: true
  RecordingStudio.enable_capability(:accessible, on: self)
end
```

Configure `access_actor_types` (required for new grants since Accessible 0.5):

```ruby
RecordingStudioAccessible.configure do |config|
  config.access_actor_types = ["User"]
end
```

### 5. Adopt RecordingStudio 4.0 API changes in host code

- Prefer `Recording.recent` or explicit `order:` (no default newest-first order).
- Do not update/destroy `RecordingStudio::Event` via ActiveRecord; use SQL `delete_all` for retention.
- Opt in to unsafe Relation/Arel/proc recordable query APIs only where required.
- Follow RecordingStudio’s 4.0 upgrade guide for `revert`, `require_actor`, and write authorization.

### 6. Smoke-test root switching

- Mounted switch page and dropdown still resolve accessible roots
- Switch persists per actor/device/scope
- Non-switchable root types remain excluded by `switchable_root_types`

## Upgrading from 0.3.1 to 0.3.5

Use this checklist when moving an existing host app onto this release line. Patch notes for each intermediate version are in [`CHANGELOG.md`](CHANGELOG.md).

### 1. Bump the gem and reinstall

```ruby
gem "recording_studio_root_switchable", "~> 0.3.5"
```

```bash
bundle update recording_studio_root_switchable
```

### 2. Copy and run new migrations

Regenerate engine migrations so any missing follow-ups land in the host app, then migrate:

```bash
bin/rails generate recording_studio_root_switchable:migrations
bin/rails db:migrate
```

In particular, ensure the selection foreign-key update that cascade-deletes selections when a root recording is removed is present (see `update_recording_studio_root_switchable_selection_foreign_key` in the engine `db/migrate` folder). Re-running the generator is safe if migrations are already installed.

### 3. Review security and privacy defaults

These defaults changed in 0.3.2. Confirm they match your product requirements:

| Setting | New default | Action if you need the old behavior |
| --- | --- | --- |
| Device-key cookie `httponly` | Always forced on | None — cannot be disabled |
| Device-key cookie `secure` | `true` in production | Override `device_key_cookie_options` only when you must serve HTTP |
| `allow_anonymous_selections` | `false` | Set `true` only if unsigned-in actors must persist selections |
| `store_raw_user_agent` | `false` | Set `true` only if you need the raw UA column populated |

`return_to` values are sanitized to same-origin relative paths before host redirect callbacks and in the dropdown helper. External or scheme-relative targets are dropped.

Optional knobs introduced or documented in this line:

```ruby
config.switch_rate_limit = { limit: 30, period: 1.minute }
config.last_used_at_touch_interval = 5.minutes
```

### 4. Expect simpler default switch-page copy

Default mounted-page `page_copy` is minimal:

- title / action label: `Switch`
- blank `subtitle` and `persistence_hint` (blank values are not rendered)

If your product needs explanatory copy, set it explicitly:

```ruby
config.page_copy = {
  title: "Switch",
  switch_action_label: "Switch",
  subtitle: "Choose the workspace for this device.",
  persistence_hint: "Saved per signed-in user and device."
}
```

Scope-level `page_copy` overrides still merge on top of the global defaults.

### 5. Fix Tailwind / FlatPack styling (if the switch UI looks unstyled)

Host Tailwind builds must scan FlatPack and this gem. After upgrading:

1. Ensure `app/assets/tailwind/application.css` includes `@source` lines for this gem and FlatPack (the install generator can inject them).
2. Link gem sources into `vendor/` so those paths resolve outside Docker-only bundle locations:

```bash
bin/rails recording_studio_root_switchable:link_tailwind_sources
bin/rails tailwindcss:build
```

Run the link task in CI before the Tailwind build if your pipeline builds CSS in a clean checkout.

### 6. Wire dropdown JavaScript (if you use `recording_studio_root_switch_dropdown`)

0.3.5 adds optimistic trigger feedback. Without the Stimulus controller, switching still works but feels slower.

In `config/importmap.rb` (the engine also registers its importmap automatically):

```ruby
pin_all_from RecordingStudioRootSwitchable::Engine.root.join("app/javascript/recording_studio_root_switchable/controllers"),
             under: "controllers/recording_studio_root_switchable",
             to: "recording_studio_root_switchable/controllers"
```

In your Stimulus loader (for example `app/javascript/controllers/index.js`):

```js
eagerLoadControllersFrom("controllers/recording_studio_root_switchable", application)
```

Load `@hotwired/turbo-rails` so dropdown forms use Turbo Drive instead of a full document reload:

```js
import "@hotwired/turbo-rails"
```

### 7. Optional APIs you can adopt

- `skip_recording_studio_root_resolution` on controllers/actions that do not need a current root
- `RecordingStudio::RootSwitchable.prune_selections!` for cleaning orphaned selection rows
- Shared helpers remain internal; host apps should keep using the public `ControllerSupport` and configuration APIs

### 8. Smoke-test

- Sign in, open the mounted switch page, and confirm title/action copy and styling
- Switch via the page and via the top-nav dropdown (if used)
- Confirm the active label updates promptly in the dropdown and the chosen root persists across refresh

## What changed since 0.3.1 (release notes)

Short summaries; full detail is in [`CHANGELOG.md`](CHANGELOG.md).

### 0.3.5
- Optimistic dropdown trigger update + pending state
- Dropdown forms use Turbo Drive when Turbo is loaded
- Gem Stimulus controller shipped via importmap

### 0.3.4
- Default UI title/action label: `Switch` (no backend “root” wording)

### 0.3.3
- Minimal default `page_copy`; blank subtitle/hint omitted from the page

### 0.3.2
- Security hardening (cookies, `return_to`, anonymous selections, UA storage, rate limit, FK cascade)
- Performance helpers (`last_used_at` throttle, request-local roots cache, skip resolution)
- `page_copy` configuration and shared path/device helpers
- Selection pruning API and Tailwind gem-source linker for host CSS builds

## Installation

Add the gems to your host app:

```ruby
gem "recording_studio", "~> 4.1"
gem "recording_studio_accessible", "~> 0.6"
gem "recording_studio_root_switchable", "~> 0.5.0"
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

**Shared roots are never switchable.** RecordingStudio 4.1 types declared with
`shared: true` are domain forests (for example a messages catalog), not owned
buckets. Root Switchable always excludes them via `RecordingStudio.shared_root?`,
even if `switchable_root_types` lists the type or a custom `available_roots`
returns the recording. Accessible `0.6+` also omits shared roots from
`root_recordings_for`; the gem still enforces the rule for custom scopes.

Use `switchable_root_types` when Accessible returns structural owned roots because
the actor has access to descendants inside that root tree, but those root types
should not appear in the user-facing switcher. This is a Root Switchable display
and switching policy only; it does not change RecordingStudio core root
behavior. Roots must still be declared RecordingStudio roots, and access checks
still apply before a root can be selected.

RecordingStudio 4.1 requires every configured recordable to declare its hierarchy
rules explicitly. Root Switchable only treats declared RecordingStudio roots as
switchable roots; parentless recordings are not enough. Shared roots remain
non-switchable even though they are valid RecordingStudio roots.

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
repo-local compatibility touchpoint is the optional
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

This gem now expects a RecordingStudio 4-compatible
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

Switchable roots must be valid RecordingStudio 4.0 root recordings. By default,
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

The dropdown is built for a fast feel:

- clicking an option updates the trigger label immediately and disables the control while the request is in flight
- forms submit with Turbo Drive when Turbo is loaded in the host app
- load the gem Stimulus controller via importmap (see install notes) so optimistic feedback is registered

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

## Cloud Agent boot

Cloud Agent Builds run `.cursor/install.sh`, then `.cursor/fetch-skills.sh`.
The install hook provisions a cold image. On a warm snapshot it skips apt,
ruby-build, db:prepare, and tailwind when Ruby, bundle, and Postgres are
already usable. Fetch-skills always runs last. `.cursor/start.sh` starts
PostgreSQL on each boot. Rebuild with Draft off to load a new pack. See
[Cursor skills in Cloud Agents](docs/cursor-skills.md).

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
- Cloud Agent boot and fetched Cursor skills: [`docs/cursor-skills.md`](docs/cursor-skills.md)
- Template reference material remains archived under `docs/gem_template/`.
