# frozen_string_literal: true

require 'minitest/autorun'
require 'fileutils'
require_relative '../lib/rubocop_interactive'

module TestHelper
  FIXTURES_PATH = File.expand_path('fixtures', __dir__)

  def fixture_json
    File.read(File.join(FIXTURES_PATH, 'rubocop_output.json'))
  end

  def fixture_project_path
    File.join(FIXTURES_PATH, 'sample_project')
  end

  # Create a temp copy of the fixture for tests that modify files
  def with_temp_fixture
    Dir.mktmpdir do |dir|
      FileUtils.cp_r(Dir.glob("#{fixture_project_path}/*"), dir)
      yield dir
    end
  end
end

# Fake UI for testing - returns predetermined responses
class FakeUI
  attr_reader :prompts_shown, :offenses_shown

  def initialize(responses: [])
    @responses = responses.dup
    @prompts_shown = 0
    @offenses_shown = []
  end

  def show_summary(total:)
    # no-op
  end

  def show_offense(offense, index:, total:)
    @offenses_shown << offense
  end

  def prompt_for_action(_offense)
    @prompts_shown += 1
    @responses.shift || :skip
  end

  def show_stats(_stats)
    # no-op
  end
end

# Fake Server for testing
class FakeServer
  attr_reader :autocorrect_calls

  def initialize
    @autocorrect_calls = []
  end

  def ensure_running!
    # no-op
  end

  def autocorrect(file:, cop:, line:)
    @autocorrect_calls << { file: file, cop: cop, line: line }
  end
end
