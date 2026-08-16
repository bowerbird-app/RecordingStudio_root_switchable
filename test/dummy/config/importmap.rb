# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# Pin FlatPack controllers
pin_all_from FlatPack::Engine.root.join("app/javascript/flat_pack/controllers"), under: "controllers/flat_pack", to: "flat_pack/controllers"

# Pin RecordingStudioRootSwitchable controllers (also registered via the gem importmap)
pin_all_from RecordingStudioRootSwitchable::Engine.root.join("app/javascript/recording_studio_root_switchable/controllers"),
             under: "controllers/recording_studio_root_switchable",
             to: "recording_studio_root_switchable/controllers"
