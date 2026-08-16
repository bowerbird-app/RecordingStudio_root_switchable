# Security notes for RecordingStudio Root Switchable

## Threat model

This gem persists a per-actor, per-device root selection and exposes a mounted
switch page plus a dropdown helper. The main risks are:

- device-key cookie theft or fixation
- open redirects through `return_to` / `after_switch_redirect`
- unauthorized root switching
- over-retention of request metadata (user agent)

## Controls

- CSRF protection is enabled on the engine application controller.
- Device keys are stored in encrypted cookies with `httponly: true` forced.
- `secure` defaults on in production; install generator sets it from `Rails.env.production?`.
- `same_site: :none` is only accepted when paired with secure cookies.
- Redirect targets are sanitized to same-origin relative paths before host callbacks and before `redirect_to`.
- Switch actions re-check that the chosen root is in the actor's available/allowed set.
- Anonymous selections are disabled by default (`allow_anonymous_selections = false`).
- Raw user-agent storage is off by default (`store_raw_user_agent = false`).
- Switch updates are rate-limited through `Rails.cache` when available.
- Selecting an unavailable root recording cascades away via FK `ON DELETE CASCADE`.
- Hosts can prune orphaned selections with `RecordingStudio::RootSwitchable.prune_selections!`.

## Host responsibilities

- Authenticate before including `ControllerSupport`.
- Customize `mounted_page_authorizer` beyond `actor.present?` when needed.
- Serve the mounted page over HTTPS in production.
- Skip root resolution on health/asset endpoints with `skip_recording_studio_root_resolution`.
- Do not log or render full device keys; use `DeviceKeyPreview` if a preview is required.
