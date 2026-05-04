RecordingStudioRootSwitchable install complete.

Next steps:

1. Review config/initializers/recording_studio_root_switchable.rb and register the scopes you want to expose.
2. Add RecordingStudio::RootSwitchable::ControllerSupport to the controller layer that should expose helper methods.
3. Run bin/rails generate recording_studio_root_switchable:migrations and then bin/rails db:migrate.
4. Run bin/rails tailwindcss:build if you use Tailwind CSS.
5. Mount routes are added at the configured mount path. Adjust auth and navigation to match your host app.
