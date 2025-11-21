# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/test/'
    add_filter '/vendor/'
  end
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
