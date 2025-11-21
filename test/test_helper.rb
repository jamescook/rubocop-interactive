# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/test/'
    add_filter '/vendor/'
  end
end

if ENV['PROFILE']
  require 'stackprof'
  require 'json'
end

require 'minitest/autorun'
require 'fileutils'
require_relative '../lib/rubocop_interactive'

# Ensure stdout/stderr are always restored on interrupt
ORIGINAL_STDOUT = $stdout
ORIGINAL_STDERR = $stderr

trap('INT') do
  $stdout = ORIGINAL_STDOUT
  $stderr = ORIGINAL_STDERR
  puts "\nInterrupted - stdout/stderr restored"
  exit 1
end

# Load test support files
require_relative 'support/helpers'
require_relative 'support/fakes'

if ENV['PROFILE']
  # Sample every 100 microseconds (10,000 Hz) for high resolution
  StackProf.start(mode: :wall, raw: true, interval: 100)

  Minitest.after_run do
    StackProf.stop
    profile = StackProf.results
    File.write('tmp/stackprof.json', JSON.generate(profile))
    puts "\nProfile saved to tmp/stackprof.json"
    puts "Upload to https://www.speedscope.app/"
  end
end
