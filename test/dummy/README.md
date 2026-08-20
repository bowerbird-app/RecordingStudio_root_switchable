# Dummy App

This Rails app exists to validate RecordingStudioRootSwitchable in a real host application.

## What It Covers

- Devise authentication with a seeded admin user
- `Current.actor` wiring for Recording Studio events
- Multiple declared RecordingStudio 4.1 root recordings
- Configured root-switch scopes (`all_workspaces`, `client_workspaces`, and `all_roots`)
- A seeded non-workspace root (`Team`) to demonstrate `switchable_root_types` filtering
- A seeded shared root (`MessageRoot`) that is never switchable
- Device-key-backed selection persistence through `RecordingStudio::RootSwitchable::ControllerSupport`
- FlatPack layout integration, PageNav-backed gem views, and mounted engine routes for RecordingStudio, RecordingStudioAccessible, and RecordingStudioRootSwitchable

## Quick Start

```bash
bundle install
bin/rails db:setup
bin/dev
```

Then open the app and sign in with:

- The sign-in form is prefilled with the seeded admin demo user.
- Email: `admin@admin.com`
- Password: `Password`

These seeded credentials are for local demo use only.

## Useful Routes

- `/` - dummy app home page and root-switch summary
- `/recording_studio` - mounted Recording Studio engine
- `/recording_studio_accessible` - mounted Recording Studio Accessible engine
- `/recording_studio_root_switchable/v1/root_switch?scope=all_workspaces` - root switch page for all accessible workspace roots
- `/recording_studio_root_switchable/v1/root_switch?scope=client_workspaces` - root switch page filtered to client workspaces
- `/users/sign_in` - Devise sign-in page
- `/up` - Rails health check

## Why This App Exists

Use this app to verify the root-switching addon end to end. It demonstrates per-device persistence, actor-aware access filtering, multiple scopes, and fallback to the default accessible root when a saved selection no longer qualifies.

## switchable_root_types Example

The seed data creates an `Operations Team` root using the `Team` model (a non-`Workspace` root type) and grants access to demo users.

In `config/initializers/recording_studio_root_switchable.rb`, the `all_roots` scope sets `switchable_root_types` to include Workspace, Page, and MessageRoot. Team stays out of the switch UI because its type is not allowlisted.

## Shared roots Example

The seed data also creates a `Studio Messages` `MessageRoot` declared with `shared: true`. Shared roots are domain forests, not owned buckets. Accessible does not list them in `root_recordings_for`, and Root Switchable never switches into them — even when the host intentionally returns them from `available_roots` and lists `MessageRoot` in `switchable_root_types`.
