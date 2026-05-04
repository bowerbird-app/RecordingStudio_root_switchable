# RecordingStudio Root Switchable

RecordingStudioRootSwitchable is a Rails engine addon for `RecordingStudio`.

It lets a host app resolve and persist a current root recording per actor, per device, and per scope without mutating recordings, recordables, or events.

## What the gem provides

- a gem-owned `recording_studio_root_switchable_selections` table
- request-local state under `RecordingStudio::RootSwitchable::Current`
- per-device persistence through an encrypted cookie-backed `device_key`
- configuration hooks for scopes, available roots, defaults, labels, descriptions, and page copy
- helper APIs for `current_root`, `current_root_recording`, `current_root_recordable`, and `current_root_scope_key`
- a dedicated FlatPack-powered v1 root-switch page
- default access integration through `RecordingStudioAccessible`

This addon was derived from the Recording Studio gem template and keeps the same engine-oriented structure, dummy app workflow, install generator, migration generator, and FlatPack-first UI conventions while replacing the template sample feature with root-switching behavior.

## Installation

Add the gems to your host app:

```ruby
gem "recording_studio"
gem "recording_studio_accessible"
gem "recording_studio_root_switchable"
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
  # config.after_switch_redirect = ->(controller:, return_to:, **) do
  #   return_to.presence || controller.main_app.root_path
  # end

  config.scope :all_workspaces do |scope|
    scope.label = "All workspaces"
    scope.description = "Every accessible workspace root"
    scope.available_roots = lambda do |actor:, **|
      RecordingStudioAccessible.root_recordings_for(actor: actor, minimum_role: :view)
    end
    scope.default_root = ->(roots:, **) { roots.first }
  end
end
```

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

`layout` controls which Rails layout the mounted root-switch page renders inside. When `layout` is `nil`, the gem uses its own blank layout. Host apps can set `layout` to a String such as `"application"`, a Symbol such as `:application_layout`, or a callable that returns either value per request.

### Actor expectations

The gem is actor-agnostic. It persists selections through a polymorphic `actor` reference and expects the host app to expose the current actor through `Current.actor` or a custom `config.current_actor_resolver`.

### Device-key persistence

Selections are remembered by `actor + device_key + scope_key`.

- `device_key` is a generated random identifier stored in an encrypted cookie
- clearing cookies creates a new device context
- the cookie does not replace authentication; access is revalidated against the current actor on every restore
- production hosts should set `config.device_key_cookie_options[:secure] = true` and serve the mounted page over HTTPS

### Scope keys

Scope keys are host-defined identifiers such as `workspace`, `team`, or `account`. Each scope decides:

- which roots are available
- which root is the default
- how labels and descriptions are rendered
- whether a candidate root is valid and accessible

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

The gem exposes a dedicated v1 page at:

```text
/recording_studio_root_switchable/v1/root_switch?scope=all_workspaces
```

From a mounted host app, you can link to it with the engine route helper:

```ruby
recording_studio_root_switchable.root_switch_path(scope: "all_workspaces")
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
- no dropdown-style switcher; v1 intentionally uses a dedicated page flow

## Documentation

Template reference material remains archived under `docs/gem_template/`.
