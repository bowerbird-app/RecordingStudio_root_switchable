# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  # Demo seeds bootstrap admin-managed access grants before an admin grant exists.
  config.access_management_authorizer = ->(actor:, **) { actor.respond_to?(:email) && actor.email == "admin@admin.com" }
end
