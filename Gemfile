# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "flat_pack", "~> 0.2", github: "bowerbird-app/flatpack", tag: "v0.2.0"
gem "recording_studio", "~> 7.8", github: "bowerbird-app/RecordingStudio", tag: "v7.8.0"
gem "recording_studio_accessible", "~> 0.56", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.56.0"
gem "recording_studio_cache", "~> 0.8", github: "bowerbird-app/RecordingStudio_cache", tag: "v0.8.0"
gem "recording_studio_metrics", "~> 0.10", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.10.0"
# Query-only trash helpers. Not an Accessible dependency.
# require: false so Bundler does not auto-load the Trashable engine.
gem "recording_studio_trashable", "~> 1.2", github: "bowerbird-app/RecordingStudio_trashable",
                                            tag: "v1.2.3", require: false
gem "view_component", "4.19.0"

gem "minitest-mock"
gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
