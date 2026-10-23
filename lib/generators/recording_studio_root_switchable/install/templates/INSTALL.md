RecordingStudioRootSwitchable install complete.

Next steps:

1. Review config/initializers/recording_studio_root_switchable.rb and register the scopes you want to expose.
2. Add RecordingStudio::RootSwitchable::ControllerSupport to the controller layer that should expose helper methods.
3. Run bin/rails generate recording_studio_root_switchable:migrations and then bin/rails db:migrate.
4. If you use Tailwind CSS:
   - Ensure app/assets/tailwind/application.css includes the injected @source lines (or add them manually).
   - Run bin/rails recording_studio_root_switchable:link_tailwind_sources so vendor/flat_pack and vendor/recording_studio_root_switchable point at the installed gems.
   - Run bin/rails tailwindcss:build.
5. The switcher uses FlatPack's dropdown and menu collapse. No gem Stimulus controller is required.
   Prefer loading `@hotwired/turbo-rails` so a switch uses Turbo Drive instead of a full page reload.
   If you are upgrading from a version that pinned `controllers/recording_studio_root_switchable`, remove that pin and its eager load.
6. Mount routes are added at the configured mount path. Adjust auth and navigation to match your host app.

Upgrading to RecordingStudio 4.1 shared roots? See the README section "Upgrading to 0.5.0 (shared roots)". For RecordingStudio 4.0 hosts still on 0.4.x, see "Upgrading to 0.4.0 (RecordingStudio 4.0)". For 0.3.x hardening-only upgrades, see "Upgrading from 0.3.1 to 0.3.5".
