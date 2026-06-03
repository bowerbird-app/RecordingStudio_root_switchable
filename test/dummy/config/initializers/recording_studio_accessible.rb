# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  # Demo seeds bootstrap access grants before an admin grant exists.
  config.access_management_authorizer = ->(**) { true }
end
