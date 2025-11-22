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
