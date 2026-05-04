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

## Documentation

Template reference material remains archived under `docs/gem_template/`.
