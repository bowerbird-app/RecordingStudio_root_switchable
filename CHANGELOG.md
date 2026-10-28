# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.11.1] - 2026-10-28

Housekeeping. No behavior change.

### Changed
- Keep `test/support/widen_recording_studio_requirement.rb` until sibling gems
  allow `recording_studio` >= 6.1.0 (follow-up PR). Current Accessible, Cache,
  Metrics, and Trashable pins still require `~> 4.2` / `~> 4.7`.
- Removed nested `test/dummy/.github/workflows/ci.yml` (it never ran on this
  repository).
- Removed archived `docs/gem_template/` and `.github/agents/rails_architect.agent.md`.
- `0.10.1` was never tagged. Tags go `v0.10.0` then `v0.11.0`; there is no
  `v0.10.1` tag.

### Upgrade Notes
- Bump to `0.11.1`. No migration. No host-app changes.

## [0.11.0] - 2026-10-27

The mounted switch page uses the Recording Studio 6.1 default layout.

### Added
- A scope can set `new_root_path` and `new_root_label`. The path is a String or a callable that receives `controller:`, `actor:`, `device_key:`, `scope:`, `current_root_recording:`, and `return_to:`. `nil`, `false`, a raised error, or an unsafe URL hides the link. A safe path gains `return_to` when it does not already have one.
- The dropdown, the collapsed list, and `recording_studio_new_root_path` use that path. Pass `new_root_path: false` to hide it on one placement. The switch page registers it with `register_page_nav` when the path is present.
- The dropdown trigger stays enabled when the path is present, including when the actor has one workspace or none.
- Page copy key `new_root_action_label` and `recording_studio.root_switchable.dropdown.new_root` default to "New workspace".
- `new_root_icon` on a scope, and `new_root_icon:` on the dropdown and list helpers, chooses the FlatPack icon. Unset uses page copy `new_root_action_icon`, then `"plus"`. `false` or `""` omits the icon on the menu row and on `register_page_nav`. `recording_studio.root_switchable.dropdown.new_root_icon` defaults to `"plus"`.

### Changed
- Requires `recording_studio` >= 6.1.0 (git tag `v6.1.0`) and `flat_pack` >= 0.1.315. Development and the dummy app pin Flatpack commit `1fcbafe94f8eb118f0a22182f63f5110fcc97a56` (`FlatPack::VERSION` `0.1.319`). `view_component` is `>= 4.14, < 5`. These lockfiles resolve `4.19.0`.
- `config.layout` is checked by `RecordingStudio::Layout.accept`. `nil` follows `RecordingStudio.configuration.layout`, then `"recording_studio/default_layout"`. `false` renders no layout. A String is a layout name. A callable is invoked as `call(controller:)` and returns a String, `nil`, or `false`.
- `RecordingStudioRootSwitchable::ApplicationController` calls `recording_studio_layout`. The gem blank layout is removed.
- The switch page sets `content_for :title` and, when the subtitle is present, `content_for :subtitle`. Close uses `flat_pack_page_nav`. The default layout draws the single heading, the top nav, and flash. The switch card spans the layout width. `mx-auto` and `max-w-3xl` are gone from that wrapper.
- The root-switch dropdown uses FlatPack's dropdown trigger. FlatPack 0.1.319 removed `button_attributes` from `Button::Dropdown`. `menu_row` is unchanged.

### Upgrade Notes
- Bump to `0.11.0`. No migration.
- Pin `recording_studio` to tag `v6.1.0` and `flat_pack` to ref `1fcbafe94f8eb118f0a22182f63f5110fcc97a56` (or tag `v0.1.315` or newer). Lock `view_component` at `4.19.0`.
- Delete `include RecordingStudio::UsesDefaultLayout`, `layout "recording_studio/default_layout"`, and `layout "recording_studio_root_switchable/blank"`.
- Replace `config.layout = :some_method` and any callable that takes a positional argument or a keyword other than `controller:`. `RecordingStudio::Layout.accept` raises `ArgumentError` for those values.
- Move a copied heading into `content_for :title` (and `content_for :subtitle` when the page has one). Put back and close on `flat_pack_page_nav`. Put a page action on `register_page_nav`.
- A host layout that replaces the default has to render `:title`, flash, and `flat_pack_page_nav_tag`. Load `flat_pack/variables`, `flat_pack/application`, and `flat_pack/rich_text` before the host Tailwind sheet.
- `new_root_path` defaults to `nil`. Existing scopes gain no create link until you set it. Return `nil` or `false` from the callable when the actor cannot create a root.
- If a sibling gemspec still requires `recording_studio` below 6, load `test/support/widen_recording_studio_requirement.rb` before Bundler evaluates gemspecs. Accessible `v0.18.0`, Cache `v0.5.0`, Metrics `v0.6.1`, and Trashable `v0.11.0` need that hook.

## [0.10.1] - 2026-10-26

The mounted switch page renders on FlatPack 0.1.311.

### Changed
- The switch page card passes `background: :default`, `border: :default`, and
  `shadow: :none`. That is the FlatPack 0.1.311 spelling of the old
  `style: :default` card: the default fill, a 1px border, and no shadow.
  `Card` `style:` raises `ArgumentError` on this FlatPack.
- The close control stays `PageNav` `with_close`. `anchor_label:` raises on
  0.1.311. `anchor_url:` alone does not, and it also does not draw the close
  control.
- Development and the dummy app pin FlatPack tag `v0.1.311`. The runtime floor
  stays `flat_pack >= 0.1.304`. `with_close`, `background:`, `border:`, and
  `shadow: :none` already exist there, so this page does not need a 0.1.311-only
  API.
- Lockfiles move `view_component` from 4.12.0 to 4.19.0. FlatPack 0.1.311
  requires `view_component >= 4.14, < 5`. 4.12.0 is GHSA-8qw7-6phv-7q6p (a
  reused component instance could leak slot content). A host that stays on
  `flat_pack` < 0.1.311 keeps `view_component` `~> 4.12.0` through FlatPack
  itself (that is the constraint on 0.1.304 through 0.1.310), so it cannot
  take that fix until it bumps `flat_pack` to >= 0.1.311.
- Lockfiles already resolved `crass` 1.0.8 (GHSA-pq4g-8rxf-4g29). A
  conservative lock update left that pin in place. `Gemfile.lock` and
  `test/dummy/Gemfile.lock` both resolve `crass (1.0.8)` and
  `view_component (4.19.0)`. There is no other lockfile.

### Upgrade Notes
- Bump to `0.10.1`. No migration.
- Hosts can stay on `flat_pack` >= 0.1.304. Move to tag `v0.1.311` when you
  want that release. That tag requires `view_component` >= 4.14 and < 5
  (this repo locks 4.19.0). Render each component instance once.
- A copied switch page that still passes `PageNav` `anchor_label:` or `Card`
  `style:` will raise. Use `with_close(href:, tooltip:)` and
  `background:` / `border:` / `shadow:`.
- On the rounded theme, a card that omitted `border:` and `shadow:` followed
  the theme edge (no border, a soft shadow). This page now keeps the old
  `style: :default` edge: 1px border, no shadow.
- FlatPack 0.1.310 stopped putting `h-full` on `Card`. This page does not add
  it back. The card sits in the show template's `flex flex-col` wrapper, which
  has no fixed height, and the default blank layout's `main` is a flex row
  with no fixed height. `h-full` would not change the painted height.
- A host on `flat_pack` < 0.1.311 stays on `view_component` `~> 4.12.0` via
  FlatPack's own dependency. That range cannot install the GHSA-8qw7-6phv-7q6p
  fix. Bump `flat_pack` to >= 0.1.311 to take `view_component` >= 4.14, < 5.

## [0.10.0] - 2026-10-23

Hosts can put the same root list in their own dropdown and in a FlatPack
button group that collapses to a menu.

### Added
- `RecordingStudioRootSwitchable::RootSwitch::MenuRows` builds the current root
  and the other accessible roots. The list comes from the request resolution,
  which already applied `ScopeContext` and Recording Studio Accessible.
  `return_to` still goes through `RedirectSanitizer`. Each other root submits
  the existing switch update.
- `RootSwitch::DropdownComponent`, a FlatPack `Button::Dropdown` labelled with
  the current root. `recording_studio_root_switch_dropdown` renders it.
  `recording_studio_root_switch_for` returns it for a button group or
  `register_page_nav`.
- `menu_row` on that dropdown, so `FlatPack::ButtonGroup` with `collapse: :menu`
  gets a `FlatPack::Menu::Collapse` (header = current root, rows = the other roots).
- `RootSwitch::ListComponent` for a host dropdown, plus
  `recording_studio_root_switch_list_for` and
  `render_recording_studio_root_switch_list`. The gem wraps the rows in the
  collapse so the host does not.

### Changed
- Runtime dependency `flat_pack` is `>= 0.1.304`. Development and the dummy app
  pin tag `v0.1.305`.
- The mounted switch page closes with `FlatPack::PageNav` `with_close`. FlatPack
  0.1.304 removed `anchor_label` and `anchor_url`.
- The install generator also scans this gem's `app/components` for Tailwind.

### Removed
- Stimulus controller `recording-studio-root-switchable--root-switch-dropdown`,
  the dropdown partial, and the gem importmap pin. FlatPack opens and closes
  the menu.

### Upgrade Notes
- Bump to `0.10.0`. No migration.
- Require `flat_pack` >= 0.1.304 (tag `v0.1.305`).
- Remove the root-switch Stimulus pin and
  `eagerLoadControllersFrom("controllers/recording_studio_root_switchable", application)`.
- Pass `placement:` instead of `position:` on the dropdown helper.
- Add the gem `app/components` paths to the host Tailwind `@source` list. New
  installs get them from the generator.
- `Menu::Collapse` text renders at 16px. Host menu items stay 14px. That size
  comes from FlatPack. This gem does not override it.

## [0.9.8] - 2026-10-23

CI runs the whole dummy app suite, and SimpleCov output stays untracked.

### Changed
- CI runs every test under `test/dummy/test` (dropdown, site-selection metrics,
  and credentials included), then RuboCop and `rake app:test`.
- `test/dummy/coverage/` is no longer in the index. The existing `coverage/`
  ignore rule already matches that directory.

### Upgrade Notes
- Bump to `0.9.8`. No migration. No host-app changes.

## [0.9.7] - 2026-10-22

Site selection metrics still register through the existing Metrics engine.
>= 0.3, < 1.0 (tested with 0.6.1).

### Changed
- Runtime dependency `recording_studio_metrics` is `>= 0.3.0, < 1.0`.
  Registration is unchanged: boot still calls
  `RecordingStudioRootSwitchable::Metrics.register!`, which calls
  `RecordingStudioMetrics.register` with
  `api_authorize: RecordingStudioRootSwitchable::Api::Access.can_view?`.

### Upgrade Notes
- Bump to `0.9.7`. No migration.
- Pin `recording_studio_metrics` to `>= 0.3.0, < 1.0` (GitHub tag `v0.6.1`).
- This gem still does not call `RecordingStudioMetrics::Api.register!`. The
  host registers Metrics endpoints once:

```ruby
RecordingStudioMetrics::Api.register!(api: :operations)
```

## [0.9.6] - 2026-10-20

Site selection metrics still register through the existing Metrics engine.
The runtime range now includes Metrics 0.5.

### Added
- Render-level multi-locale coverage for mounted-page `page_copy` (test-only
  French fixture, plus Hash / Symbol / callable config forms on a real page).
- MCP 0.17 tool names for the existing `:root_selections` metrics (dot becomes
  a hyphen). None of these metrics is a timeseries, so they do not take
  `from`, `to`, or `interval`.

### Changed
- Runtime dependency `recording_studio_metrics` is `>= 0.3.0, < 0.6`.
  Registration is unchanged: boot still calls
  `RecordingStudioRootSwitchable::Metrics.register!`, which calls
  `RecordingStudioMetrics.register` with
  `api_authorize: RecordingStudioRootSwitchable::Api::Access.can_view?`.

### Upgrade Notes
- Bump to `0.9.6`. No migration.
- Pin `recording_studio_metrics` to `>= 0.3.0, < 0.6` (GitHub tag `v0.5.0`).
- This gem still does not call `RecordingStudioMetrics::Api.register!`. The
  host registers Metrics endpoints once:

```ruby
RecordingStudioMetrics::Api.register!(api: :operations)
```

## [0.9.4] - 2026-10-16

Site selection metrics stay on the existing Metrics engine. The pin moves to
Metrics 0.3 so RecordingStudio MCP 0.17 can advertise one tool per metric.

### Added
- Documented MCP tool names for `root_selections.*` (see README). Scalars and
  breakdowns do not take `from`, `to`, or `interval`.

### Changed
- Runtime dependency `recording_studio_metrics` from `~> 0.2` to
  `>= 0.3.0, < 0.4` (GitHub tag `v0.3.1`).

### Upgrade Notes
- Bump to `0.9.4`. No migration.
- Pin `recording_studio_metrics` to `>= 0.3.0, < 0.4` (tag `v0.3.1`).
- This gem still does not call `RecordingStudioMetrics::Api.register!`. The
  host registers Metrics endpoints once:

```ruby
RecordingStudioMetrics::Api.register!(api: :operations)
```

- MCP 0.17 names tools from the metric identifier: `users.total` becomes
  `users-total`. This gem's tools are `root_selections-active_actors_7d`,
  `root_selections-active_actors_30d`, `root_selections-active_devices_30d`,
  `root_selections-by_device_type`, `root_selections-by_platform`, and
  `root_selections-by_browser`. Windows are baked into each metric. Do not
  send `from`, `to`, or `interval`.

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
  switch-rate `cache_store` / `config.cache` setting; the adapter passes
  `store: Rails.cache` so the shared limiter cannot fall through to
  `RecordingStudioCache.store`. Key TTLs are unchanged: main already passed
  `expires_in: period` on `increment`.
- Adapter keeps main-era edges the shared limiter would otherwise flip:
  for `limit.to_i <= 0`, main still called `increment` first, then
  `count.to_i <= limit.to_i` (raise still fails open). So `limit: 0` +
  NullStore (`nil`) allows, while `limit: -1` + NullStore blocks; shared would
  treat `<= 0` as disabled / always allow. A non-Numeric `period` (e.g. `"60"`)
  still fails open (main raised from `expires_in:` and rescued; shared would
  coerce via `to_i`).
- Runtime dependency `recording_studio_cache` `~> 0.5` (GitHub tag `v0.5.0`).

### Upgrade Notes
- Bump to `0.9.0`. No migration.
- Add `recording_studio_cache` at tag `v0.5.0`:
  `gem "recording_studio_cache", github: "bowerbird-app/RecordingStudio_cache", tag: "v0.5.0"`.
- No host code changes when you already use `config.switch_rate_limit` / the
  mounted switch page with Numeric `limit` / `period` (including Duration).
  `limit <= 0` still increments then compares with `count.to_i <= limit.to_i`
  (raise fails open); String `period` still fails open.

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.11.1...HEAD
[0.11.1]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.11.0...v0.11.1
[0.11.0]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.10.0...v0.11.0
[0.10.0]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.9.8...v0.10.0
[0.9.8]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.9.7...v0.9.8
[0.9.7]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.9.6...v0.9.7
[0.9.6]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.9.4...v0.9.6
[0.9.4]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.9.3...v0.9.4
[0.8.0]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.7.0...v0.8.0
[0.3.1]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/releases/tag/v0.1.0
[0.7.0]: https://github.com/bowerbird-app/RecordingStudio_root_switchable/compare/v0.6.0...v0.7.0
