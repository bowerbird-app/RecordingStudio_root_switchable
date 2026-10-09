# frozen_string_literal: true

require "test_helper"

class RootSelectionsMetricsTest < Minitest::Test
  def test_seeded_selection_metric_values_and_api_authorize
    dummy = File.expand_path("dummy", __dir__)
    gemfile = File.join(dummy, "Gemfile")
    test_file = "test/models/root_selections_metrics_test.rb"
    env = ENV.to_h.merge(
      "RAILS_ENV" => "test",
      "BUNDLE_GEMFILE" => gemfile
    )

    Bundler.with_unbundled_env do
      Dir.chdir(dummy) do
        assert system(env, "bundle", "exec", "rails", "test", test_file),
               "dummy #{test_file} failed"
      end
    end
  end
end
