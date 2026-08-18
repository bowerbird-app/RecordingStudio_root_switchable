# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.129"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.0.0"
# Pin to the RecordingStudio 4.0 support branch until 0.6.0 is tagged on main.
gem "recording_studio_accessible",
    github: "bowerbird-app/RecordingStudio_accessible",
    branch: "cursor/support-recording-studio-4-8e1e"

gem "puma"
gem "sprockets-rails"
gem "minitest-mock"

group :development, :test do
  gem "debug"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
