# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Clarify RecordingStudio 3.0 hierarchy requirements in docs and setup examples.
- Register the dummy app's RecordingStudioAccessible child-recordable capability metadata when core v3 capability APIs are available.

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/releases/tag/v0.1.0
