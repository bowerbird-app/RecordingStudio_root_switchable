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

### Actor expectations

The gem is actor-agnostic. It persists selections through a polymorphic `actor` reference and expects the host app to expose the current actor through `Current.actor` or a custom `config.current_actor_resolver`.

### Device-key persistence

Selections are remembered by `actor + device_key + scope_key`.

- `device_key` is a generated random identifier stored in an encrypted cookie
- clearing cookies creates a new device context
- the cookie does not replace authentication; access is revalidated against the current actor on every restore

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
