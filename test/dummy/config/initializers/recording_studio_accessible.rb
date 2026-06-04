# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  # Demo seeds bootstrap admin-managed access grants before an admin grant exists.
  config.access_management_authorizer = lambda do |actor:, **|
    ENV["RECORDING_STUDIO_ACCESSIBLE_BOOTSTRAP_ADMIN"] == "1" &&
      (Rails.env.development? || Rails.env.test?) &&
      actor.respond_to?(:email) &&
      actor.email == "admin@admin.com"
  end
end
