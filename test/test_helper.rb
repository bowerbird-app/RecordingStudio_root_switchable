# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require_relative "simplecov_helper"
require "minitest/autorun"
require "rails"
require "active_record"
require "recording_studio_root_switchable"
require_relative "../app/models/recording_studio/root_switchable/selection"
