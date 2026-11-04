# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"].exclude("test/dummy/test/**/*_test.rb")
  t.verbose = false
end

namespace :test do
  desc "Run root-switchable naming verification tests"
  task :rename_verification do
    ruby "test/rename_verification_test.rb", verbose: true
  end

  desc "Run root-switchable naming verification tests in verbose mode"
  task :rename_verification_verbose do
    ruby "test/rename_verification_test.rb", "--verbose", verbose: true
  end
end

namespace :app do
  desc "Run all tests for the gem"
  task test: :test
end

namespace :test do
  desc "Run gem tests and dummy app tests"
  task :all do
    Rake::Task[:test].invoke
    dummy = File.expand_path("test/dummy", __dir__)
    gemfile = File.join(dummy, "Gemfile")
    Dir.chdir(dummy) do
      sh({ "BUNDLE_GEMFILE" => gemfile }, "bundle exec rails test")
    end
  end
end

task default: :test
