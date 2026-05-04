# Project Guidelines

## Architecture

- This repository is a Rails mountable engine for root switching on top of RecordingStudio.
- Preserve engine namespace isolation under `RecordingStudioRootSwitchable`.
- Treat `docs/gem_template/` as archived architectural reference material. Prefer the top-level README and dummy app for current behavior.
- Keep changes small and scoped.

## UI Conventions

- FlatPack is the default UI system for this repo.
- When editing ERB views, prefer `render FlatPack::...` components over custom HTML when an equivalent component exists.
- Prefer standardized and testable FlatPack ViewComponents over one-off ERB markup or custom JavaScript.
- Keep custom markup limited to semantic wrappers or content that FlatPack does not cover.

## Testing

- The standard root validation command is `bundle exec rake test` from the repository root.
- If a change affects dummy app boot, assets, or migrations, also validate the dummy app setup the same way CI does.
- Add focused regression tests for services, generators, Recording Studio integration points, and root-switching UX changes.

## Repo Conventions

- Keep internal dependency assumptions intact unless the request explicitly asks to change them.
- Update docs when setup steps or switching behavior change.
- Prefer explicit APIs over hidden magic.
