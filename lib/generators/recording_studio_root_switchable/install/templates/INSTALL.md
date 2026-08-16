RecordingStudioRootSwitchable install complete.

Next steps:

1. Review config/initializers/recording_studio_root_switchable.rb and register the scopes you want to expose.
2. Add RecordingStudio::RootSwitchable::ControllerSupport to the controller layer that should expose helper methods.
3. Run bin/rails generate recording_studio_root_switchable:migrations and then bin/rails db:migrate.
4. If you use Tailwind CSS:
   - Ensure app/assets/tailwind/application.css includes the injected @source lines (or add them manually).
   - Run bin/rails recording_studio_root_switchable:link_tailwind_sources so vendor/flat_pack and vendor/recording_studio_root_switchable point at the installed gems.
   - Run bin/rails tailwindcss:build.
5. If you use the root-switch dropdown helper with importmap + Stimulus:
   - Pin gem controllers (the engine also registers config/importmap.rb):

```ruby
pin_all_from RecordingStudioRootSwitchable::Engine.root.join("app/javascript/recording_studio_root_switchable/controllers"),
             under: "controllers/recording_studio_root_switchable",
             to: "recording_studio_root_switchable/controllers"
```

   - Eager-load them next to your other Stimulus controllers:

```js
eagerLoadControllersFrom("controllers/recording_studio_root_switchable", application)
```

   - Prefer loading `@hotwired/turbo-rails` so dropdown switches use Turbo Drive instead of a full page reload.
6. Mount routes are added at the configured mount path. Adjust auth and navigation to match your host app.

Upgrading from 0.3.1? See the "Upgrading from 0.3.1 to 0.3.5" section in the gem README for migrations, security defaults, page copy, Tailwind linking, and dropdown JS.
