# frozen_string_literal: true

require_relative 'test_helper'

class OffenseTest < Minitest::Test
  def test_parses_offense_from_json_data
    data = {
      'cop_name' => 'Style/StringLiterals',
      'message' => 'Prefer single-quoted strings',
      'severity' => 'convention',
      'correctable' => true,
      'location' => {
        'start_line' => 6,
        'start_column' => 7,
        'length' => 15
      }
    }

    offense = RubocopInteractive::Offense.new(file_path: 'test.rb', data: data)

    assert_equal 'test.rb', offense.file_path
    assert_equal 'Style/StringLiterals', offense.cop_name
    assert_equal 'Prefer single-quoted strings', offense.message
    assert_equal 'convention', offense.severity
    assert offense.correctable?
    assert_equal 6, offense.line
    assert_equal 7, offense.column
  end

  def test_location_string
    data = {
      'cop_name' => 'Test',
      'message' => 'msg',
      'severity' => 'warning',
      'correctable' => false,
      'location' => { 'start_line' => 10, 'start_column' => 5, 'length' => 1 }
    }

    offense = RubocopInteractive::Offense.new(file_path: 'foo/bar.rb', data: data)

    assert_equal 'foo/bar.rb:10:5', offense.location
  end
end
