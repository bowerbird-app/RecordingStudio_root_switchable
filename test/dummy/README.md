# Dummy App

This Rails app exists to validate RecordingStudioRootSwitchable in a real host application.

## What It Covers

- Devise authentication with a seeded admin user
- `Current.actor` wiring for Recording Studio events
- Multiple accessible root recordings
- Two configured root-switch scopes (`all_workspaces` and `client_workspaces`)
- Device-key-backed selection persistence through `RecordingStudio::RootSwitchable::ControllerSupport`
- FlatPack layout integration and mounted engine routes for RecordingStudio, RecordingStudioAccessible, and RecordingStudioRootSwitchable

## Quick Start

```bash
bundle install
bin/rails db:setup
bin/dev
```

Then open the app and sign in with:

- Email: `admin@admin.com`
- Password: `Password`

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
