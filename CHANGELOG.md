# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.4] - 2026-08-16

### Changed
- Default mounted page title is `Switch` and the action label is `Switch` (avoid backend "root" wording in UI copy).

## [0.3.3] - 2026-08-15

### Changed
- Simplify the mounted switch page defaults: no subtitle or persistence hint, and a short action label.
- Skip rendering blank `subtitle` / `persistence_hint` values so hosts can keep the chooser minimal.
- Remove explanatory scope `page_copy` overrides from the dummy app; filtering docs stay in scope descriptions.

## [0.3.2] - 2026-08-15

### Security
- Force `httponly` on device-key cookies and default `secure` in production.
- Sanitize `return_to` before host redirect callbacks and in the dropdown helper.
- Disable anonymous selections and raw user-agent storage by default.
- Add switch rate limiting and cascade-delete selections when a root recording is removed.

### Changed
- Throttle `last_used_at` updates and cache available roots per request.
- Drive mounted page copy from `page_copy` configuration.
- Share internal path sanitization, root id comparison, and device-key preview helpers.
- Allow hosts to skip automatic root resolution with `skip_recording_studio_root_resolution`.

### Added
- `RecordingStudio::RootSwitchable.prune_selections!` for orphaned selection cleanup.
- Root-level Dependabot config and gem-focused `SECURITY.md`.

## [0.3.1] - 2026-07-02

### Changed
- Bump RecordingStudioRootSwitchable to 0.3.1.
- Add scope-level `switchable_root_types` filtering so host apps can limit switchable roots by recordable type per scope while preserving existing behavior when unset.
- Apply filtering consistently in root resolution and switch actions, including fallback behavior when the current selection is filtered out.
- Refresh generator initializer guidance and README configuration docs with `switchable_root_types` usage and semantics.
- Extend the dummy app with a `Team` root type plus an `all_roots` scope example to demonstrate filtering non-Workspace roots from the switcher.
- Update dummy app navigation and setup pages to surface the new filtering scenario and route examples.

### Added
- Regression coverage for `switchable_root_types` in scope definition behavior and both root resolution/switch services.
- Dummy-app navigation coverage for the new filtering demo entry points.


## [0.3.0] - 2026-06-05

### Changed
- Require RecordingStudio `~> 3.0` and RecordingStudioAccessible `~> 0.3`.
- Clarify RecordingStudio 3.0 hierarchy requirements in docs and setup examples.
- Register the dummy app's RecordingStudioAccessible child-recordable capability metadata when core v3 capability APIs are available.

### Breaking
- Host apps must upgrade to RecordingStudio 3-compatible RecordingStudio and RecordingStudioAccessible releases before upgrading this gem.

## [0.2.0] - 2026-06-04

### Changed
- Require RecordingStudio `~> 2.0` and RecordingStudioAccessible `~> 0.2`.
- Treat only declared RecordingStudio 2.0 root recordings as switchable roots.
- Update the dummy app hierarchy declarations, access setup, and root-switch coverage for RecordingStudio 2.0.

### Security
- Restrict the dummy app access-management bootstrap authorizer to development/test seed bootstrap execution.

### Breaking
- Host apps must upgrade to RecordingStudio 2.0-compatible recordable hierarchy declarations before upgrading this gem.

## [0.1.0] - 2025-12-04

### Added
- Initial release of RecordingStudioRootSwitchable
- Per-actor, per-device, per-scope root selection persistence
- Dedicated FlatPack-powered v1 root-switching page
- RecordingStudioAccessible integration for default access checks
- Dummy app coverage for multiple scopes and fallback behavior

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.3.1...HEAD
[0.3.1]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/releases/tag/v0.1.0
