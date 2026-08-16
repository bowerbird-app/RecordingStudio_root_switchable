// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

// Eager load FlatPack controllers
eagerLoadControllersFrom("controllers/flat_pack", application)

// Eager load RecordingStudioRootSwitchable controllers (optimistic dropdown feedback)
eagerLoadControllersFrom("controllers/recording_studio_root_switchable", application)
