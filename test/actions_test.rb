# frozen_string_literal: true

require_relative 'test_helper'

class ActionsTest < Minitest::Test
  include TestHelper

  def setup
    @offense_data = {
      'cop_name' => 'Style/StringLiterals',
      'message' => 'Prefer single-quoted strings',
      'severity' => 'convention',
      'correctable' => true,
      'location' => { 'start_line' => 6, 'start_column' => 7, 'length' => 15 }
    }
  end

  def test_autocorrect_fixes_only_target_offense
    with_temp_fixture do |dir|
      file_path = File.join(dir, 'bad_code.rb')

      # Target the first StringLiterals offense on line 6
      offense = RubocopInteractive::Offense.new(file_path: file_path, data: @offense_data)
      server = FakeServer.new

      result = RubocopInteractive::Actions.perform(:autocorrect, offense, server: server)

      assert_equal :corrected, result

      corrected_content = File.read(file_path)

      # Line 6 should be fixed (double quotes -> single quotes)
      corrected_lines = corrected_content.lines
      assert_match(/'double quotes'/, corrected_lines[5])

      # Line 15 should still have double quotes (not fixed)
      assert_match(/"test"/, corrected_lines[14])
    end
  end

  def test_disable_line_adds_comment
    with_temp_fixture do |dir|
      file_path = File.join(dir, 'bad_code.rb')
      @offense_data['location']['start_line'] = 6
      offense = RubocopInteractive::Offense.new(file_path: file_path, data: @offense_data)
      server = FakeServer.new

      result = RubocopInteractive::Actions.perform(:disable_line, offense, server: server)

      assert_equal :disabled, result

      content = File.read(file_path)
      assert_match(/rubocop:disable Style\/StringLiterals/, content)
    end
  end

  def test_disable_file_adds_comments_at_top_and_bottom
    with_temp_fixture do |dir|
      file_path = File.join(dir, 'bad_code.rb')
      offense = RubocopInteractive::Offense.new(file_path: file_path, data: @offense_data)
      server = FakeServer.new

      result = RubocopInteractive::Actions.perform(:disable_file, offense, server: server)

      assert_equal :disabled, result

      lines = File.readlines(file_path)
      assert_match(/rubocop:disable Style\/StringLiterals/, lines.first)
      assert_match(/rubocop:enable Style\/StringLiterals/, lines.last)
    end
  end
end
