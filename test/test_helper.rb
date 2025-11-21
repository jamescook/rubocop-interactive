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

# Load test support files
require_relative 'support/helpers'
require_relative 'support/fakes'
