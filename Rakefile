# frozen_string_literal: true

require 'bundler/setup'
require 'rake/testtask'

# Set RUBOCOP_OPTS before running tests so fixtures aren't excluded
task :set_test_rubocop_config do
  ENV['RUBOCOP_OPTS'] = '--config .rubocop_for_tests.yml'
end

Rake::TestTask.new(:test_run) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
end

# Make test depend on setting the environment
task test: [:set_test_rubocop_config, :test_run]

task default: :test

namespace :build do
  desc 'Build, install, and test the gem'
  task :gem_test do
    require_relative 'lib/rubocop_interactive/version'

    version = RubocopInteractive::VERSION
    gem_file = "rubocop-interactive-#{version}.gem"

    puts "Building gem..."
    sh 'gem build rubocop-interactive.gemspec'

    puts "\nInstalling gem..."
    sh "gem install #{gem_file}"

    puts "\nRunning sanity checks..."

    # Check that the gem can be required
    sh "ruby -e 'require \"rubocop_interactive\"; puts \"Version: #{RubocopInteractive::VERSION}\"'"

    # Check that the binary exists and shows version
    sh 'rubocop-interactive --version'

    puts "\n✓ Gem build and sanity checks passed!"

    # Clean up
    puts "\nCleaning up #{gem_file}..."
    File.delete(gem_file) if File.exist?(gem_file)
  end
end
