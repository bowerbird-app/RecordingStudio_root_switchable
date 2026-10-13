# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.9.0] - 2026-10-13

Switch rate limiting uses the shared `RecordingStudioCache::RateLimiter`.

### Changed
- `RecordingStudioRootSwitchable::SwitchRateLimiter` is a thin adapter over
  `RecordingStudioCache::RateLimiter` (`backend: :rails_cache`, `strategy: :ttl`,
  `prefix: "recording_studio_root_switchable:switch_rate"`, `separator: ":"`,
  `fail_closed: false`, `rescue_errors: [StandardError]`). Public config
  (`config.switch_rate_limit`) and `allowed?(actor:, device_key:)` are unchanged.
  Cache keys, windows, and fail-open cache errors match 0.8.x.
- Store is still `Rails.cache` (what main incremented against). This gem has no
  switch-rate `cache_store` / `config.cache` setting; the adapter resolves
  `Rails.cache` once and passes that object as `store:` so the shared limiter
  cannot fall through to `RecordingStudioCache.store`. Key TTLs are unchanged:
  main already passed `expires_in: period` on `increment`.
- Adapter keeps two main-era edge cases the shared limiter would otherwise flip:
  `limit.to_i <= 0` still blocks every switch (shared treats `<= 0` as disabled),
  and a non-Numeric `period` (e.g. `"60"`) still fails open / never limits (main
  raised from `expires_in:` and rescued; shared would coerce via `to_i`).
- Runtime dependency `recording_studio_cache` `~> 0.5` (GitHub tag `v0.5.0`).

### Upgrade Notes
- Bump to `0.9.0`. No migration.
- Add `recording_studio_cache` at tag `v0.5.0`:
  `gem "recording_studio_cache", github: "bowerbird-app/RecordingStudio_cache", tag: "v0.5.0"`.
- No host code changes when you already use `config.switch_rate_limit` / the
  mounted switch page with Numeric `limit` / `period` (including Duration).
  `limit <= 0` still blocks; String `period` still fails open.

## [0.8.0] - 2026-10-12

Default mounted-page `page_copy` is translatable through Rails I18n at render time.

### Added
- English Rails I18n keys for every `DEFAULT_PAGE_COPY` field under
  `recording_studio.root_switchable.page_copy.*` in `config/locales/en.yml`.
- `config.page_copy` values may be a plain String, a Symbol I18n key, an
  `i18n:`-prefixed String key, a per-request callable, or a locale Hash.
  Resolution happens in `page_copy_for` per request. A bare `i18n:` (empty key)
  falls back to the gem page_copy key. `nil` is allowed only for optional keys
  (`subtitle`, `persistence_hint`) at global and scope level; required keys
  still reject `nil` at configure time.

### Changed
- Unconfigured `page_copy` keys resolve through I18n at render time (honoring
  `I18n.locale`) with `default:` set to the original English from
  `DEFAULT_PAGE_COPY`. The `DEFAULT_PAGE_COPY` constant remains the public
  English default table.
- Precedence is `config.page_copy` > gem/host translation > English default.
  Plain String configs stay fixed in every locale.
- Scope-level Symbol `page_copy` values are I18n keys at render time (they used
  to render via `to_s`).
- `configuration.page_copy` returns a fresh merged hash. Mutating that hash in
  place no longer updates stored config, and entries may be unresolved Symbol,
  Hash, or callable values until `page_copy_for` resolves them.

### Upgrade Notes
- Bump to `0.8.0`. No migration.
- This release changes two host-visible behaviors:
  1. A Symbol in scope (or global) `page_copy` is an I18n key, not `to_s` text.
     Use a plain String if you need a fixed label in every locale.
  2. `configuration.page_copy` returns a fresh merge of defaults and overrides.
     Do not mutate the returned hash in place; assign `config.page_copy = { ... }`
     (or merge) instead. The reader may return unresolved Symbol / Hash /
     callable values — call `page_copy_for` for rendered strings.
- English hosts that only use plain-String `page_copy` (or leave it unset) keep
  the same English output. To translate defaults, define the same
  `recording_studio.root_switchable.page_copy.*` keys in the host's
  `config/locales`.
- Missing Symbol / `i18n:...` keys fall back to the gem page_copy key in the
  current locale, then English. A bare `i18n:` falls back the same way.
- There is no dependency on `recording_studio_internationalization`.

## [0.7.0] - 2026-10-09

Site-wide last-used selection metrics register with Recording Studio Metrics for the operations API.

### Added
- `RecordingStudioRootSwitchable::Metrics.register!` registers a `:root_selections`
  resource (`blast_radius: :site`) on the existing Selection table. Metrics:
  `root_selections.active_actors_7d`, `root_selections.active_actors_30d`
  (distinct `actor_id` with `last_used_at` in the window),
  `root_selections.active_devices_30d` (distinct `device_key` with `last_used_at`
  in 30 days), and `root_selections.by_device_type` / `by_platform` / `by_browser`
  (last-used selection rows in the last 30 days). Each is exposed on
  `:operations` only. Distinct actor/device counts use custom calculators;
  `by_device_type` / `by_platform` / `by_browser` are DSL `breakdown`s with a
  per-metric `scope:` for the 30-day `last_used_at` window. Rows are upserted per
  actor+device+scope: last-used, not switch-event counts. `user_agent` and actor
  identities are never exposed.
- `api_authorize` uses `RecordingStudioRootSwitchable::Api::Access.can_view?`
  (AdminRoot `:view` via Accessible).
- Runtime dependency `recording_studio_metrics` `~> 0.2` (GitHub tag `v0.2.0`).

### Upgrade Notes
- Bump to `0.7.0`. No migration.
- Add `recording_studio_metrics` at tag `v0.2.0`.
- This gem does not call `RecordingStudioMetrics::Api.register!`. The host
  registers Metrics endpoints once:

```ruby
RecordingStudioMetrics::Api.register!(api: :operations)
```

## [0.6.0] - 2026-10-09

### Added

- English Rails I18n keys for static interface copy in the gem's own blank
  layout, root switch page, and dropdown helper (`config/locales/en.yml` under
  `recording_studio.root_switchable`)

### Changed

- Pin development and dummy bundles to RecordingStudioAccessible `v0.11.1`.
- Widen the gemspec Accessible dependency from `~> 0.6` to `~> 0.11`.
- Dummy app copies Accessible 0.8–0.11 migrations (`depends_on_recording_id`,
  access invitations, string `role`), and seeds owner/viewer grants through
  `bootstrap_owner_access!` and `grant_access`.
- Hard-coded layout title / application-name, PageNav close label, and dropdown
  empty selection label resolve through `t("recording_studio.root_switchable.*")`
  (English output unchanged)

### Upgrade Notes

- Hosts that install from the gemspec should use RecordingStudioAccessible `0.11.x`
  (for example tag `v0.11.1`).
- Hosts upgrading Accessible with this dummy should run
  `bin/rails generate recording_studio_accessible:migrations` then
  `bin/rails db:migrate` so `recording_studio_accesses.role` is a string.
  Grant through Accessible public services; `RecordingStudio::Access` is readonly.
- No migration or host code change is required for English.
- This gem had no older top-level `recording_studio_root_switchable.*` locale
  file; new strings use only the nested `recording_studio.root_switchable`
  namespace.
- To translate or override the defaults, add keys under
  `recording_studio.root_switchable` in the host's locale files.
- Host `page_copy` configuration remains the override path for mounted-page
  titles, badges, switch actions, and empty states.
- There is no dependency on `recording_studio_internationalization`.

## [0.5.1] - 2026-09-02

Cloud Agent Builds fetch Cursor skills at Build. Warm install skips apt, Ruby,
the dummy database, and Tailwind when they are already usable.

### Added
- Track `.cursor/environment.json`, `.cursor/install.sh`, `.cursor/fetch-skills.sh`,
  and `.cursor/start.sh`. Builds fetch the Recording Studio Cursor pack instead of
  vendoring `SKILL.md` or plugin `*.mdc` files.
- Ignore `.cursor/skills/` and `.cursor/rules/` so the fetched pack stays out of git
  and out of the gem.

### Fixed
- `.cursor/install.sh` skips apt, ruby-build, `db:prepare`, and Tailwind when Ruby,
  bundle, and Postgres are already usable. A skippable provision failure no longer
  fails the Build. Fetch-skills always runs last.

### Upgrade Notes
- No host or schema changes. Rebuild the Cloud Agent environment with Draft off so
  Build loads the pack.

## [0.5.0] - 2026-08-20

### Added
- Never switch into RecordingStudio shared roots (`shared: true`). Shared roots are
  filtered from available roots, defaults, validity checks, resolve, and switch
  even when a custom `available_roots` returns them or `switchable_root_types`
  lists their type.
- Dummy `MessageRoot` (`shared: true`) demo plus home-page switchability messaging
  for shared vs owned roots.

### Changed
- Require RecordingStudio `~> 4.1` (shared-root helpers) and pin dummy/dev bundles
  to RecordingStudio `v4.1.0` and RecordingStudioAccessible `v0.6.0`.

### Upgrade Notes
- Upgrade RecordingStudio to `4.1.0+` before installing `0.5.0`.
- Shared root types are never switchable. Do not rely on `switchable_root_types`
  alone to hide them; the gem enforces the policy.
- See README **Upgrading to 0.5.0 (shared roots)**.

## [0.4.0] - 2026-08-18

### Breaking
- Require RecordingStudio `~> 4.0` and RecordingStudioAccessible `~> 0.6`.
- Hosts must complete the RecordingStudio 4.0 harden migration before upgrading.
- Replace `RecordingStudioAccessible::AllowsAccessibleChildren` /
  `recording_studio_accessible_children` with
  `RecordingStudio.enable_capability(:accessible, on: ...)` on host recordables.

### Changed
- Development and dummy-app bundles pin RecordingStudio `v4.0.0`, FlatPack `v0.1.129`,
  and RecordingStudioAccessible `0.6.0` (RS 4 support branch until tagged on main).
- Dummy accessible initializer configures `access_actor_types = ["User"]` for RSA 0.5+ fail-closed grants.

### Upgrade Notes
- Stay on `0.3.x` if you are still on RecordingStudio 3 / Accessible `~> 0.3`–`0.5`.
- See README **Upgrading to 0.4.0 (RecordingStudio 4.0)** for the full checklist.

## [0.3.5] - 2026-08-16

### Changed
- Root-switch dropdown updates the trigger label immediately and shows a pending state while the switch request completes.
- Dropdown forms use Turbo Drive when available (no `local: true` full-page submit).

### Added
- Stimulus controller `recording-studio-root-switchable--root-switch-dropdown` shipped via the gem importmap.
- Consolidated host upgrade guide for 0.3.1 → 0.3.5 in the README.

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.8.0...HEAD
[0.8.0]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.7.0...v0.8.0
[0.3.1]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/releases/tag/v0.1.0
[0.7.0]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.6.0...v0.7.0
