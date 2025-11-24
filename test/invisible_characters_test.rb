# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'diff_assertion_helper'

# Tests for making invisible characters (trailing spaces, tabs, newlines) visible in diffs
#
# Expected behavior:
# - Trailing whitespace (spaces/tabs at end of lines) should be shown with visible markers
#   - Spaces: shown as ·· (middle dot)
#   - Tabs: shown as →→ or ⇥⇥
# - Markers should appear on ALL diff lines that have trailing whitespace (both - and + lines)
# - Markers should appear whether trailing whitespace is the only change OR part of a larger change
# - Non-trailing whitespace (spaces in the middle of code) should NOT get markers
class InvisibleCharactersTest < Minitest::Test
  include DiffAssertionHelper

  def test_trailing_whitespace_shows_visible_markers
    # When trailing whitespace is removed, show it with visible markers like ·
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      # Line 3 intentionally has two trailing spaces
      File.write(file_path, "def foo\n  x = 1\n  \n  y = 2\nend\n")

      offense_data = {
        'cop_name' => 'Layout/TrailingWhitespace',
        'message' => 'Trailing whitespace detected.',
        'severity' => 'convention',
        'correctable' => true,
        'location' => { 'start_line' => 3, 'start_column' => 1, 'last_line' => 3, 'last_column' => 2 }
      }

      offense_obj = RubocopInteractive::Offense.new(file_path: file_path, data: offense_data)
      result = RubocopInteractive::PatchGenerator.generate(offense_obj)

      diff = result[:lines]

      # The removed line should show trailing spaces as visible markers
      # Expected format: "-  ··" or similar (using · or ␣ to show spaces)
      assert diff.include?('··'), "Trailing spaces should be shown with visible markers (··)"

      # The added line should be just "+"
      assert_match(/^\+$/, diff, "Empty line should show as just '+'")
    end
  end

  def test_trailing_whitespace_shown_even_with_other_changes
    # Even when there are other changes on the line, trailing whitespace should still be marked
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      # Line 2 has trailing spaces AND will have a string literal change
      File.write(file_path, "def foo\n  x = \"test\"  \nend\n")

      # Simulate StringLiterals offense that also happens to remove trailing whitespace
      offense_data = {
        'cop_name' => 'Style/StringLiterals',
        'message' => 'Prefer single-quoted strings.',
        'severity' => 'convention',
        'correctable' => true,
        'location' => { 'start_line' => 2, 'start_column' => 7, 'last_line' => 2, 'last_column' => 12 }
      }

      offense_obj = RubocopInteractive::Offense.new(file_path: file_path, data: offense_data)
      result = RubocopInteractive::PatchGenerator.generate(offense_obj)

      diff = result[:lines]

      # Should show markers for trailing whitespace even though main change is quotes
      # Something like: -  x = "test"··
      #                 +  x = 'test'
      assert_match(/··/, diff, "Trailing whitespace should be marked even with other changes")
    end
  end

  def test_no_markers_for_non_trailing_whitespace
    # Spaces in the middle of code should NOT get markers
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      File.write(file_path, "def foo\n  x = 1\nend\n")

      offense_data = {
        'cop_name' => 'Style/StringLiterals',
        'message' => 'Prefer single-quoted strings.',
        'severity' => 'convention',
        'correctable' => true,
        'location' => { 'start_line' => 2, 'start_column' => 7, 'last_line' => 2, 'last_column' => 7 }
      }

      offense_obj = RubocopInteractive::Offense.new(file_path: file_path, data: offense_data)
      result = RubocopInteractive::PatchGenerator.generate(offense_obj)

      # If there's no trailing whitespace, there should be no markers
      # (this might return nil if offense isn't actually correctable)
      skip "Need a better test case for non-trailing whitespace" if result.nil?

      diff = result[:lines]

      # Regular spaces in the middle of code (like "x = 1") should NOT be marked with ··
      # The markers are ONLY for trailing whitespace at end of lines
      refute_match(/x··/, diff, "Spaces in middle of code should not get markers")
      refute_match(/=··/, diff, "Spaces in middle of code should not get markers")
    end
  end

  def test_trailing_tabs_also_get_markers
    # Tabs at end of line should be visible too
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      File.write(file_path, "def foo\n  x = 1\t\t\n  y = 2\nend\n")

      offense_data = {
        'cop_name' => 'Layout/TrailingWhitespace',
        'message' => 'Trailing whitespace detected.',
        'severity' => 'convention',
        'correctable' => true,
        'location' => { 'start_line' => 2, 'start_column' => 9, 'last_line' => 2, 'last_column' => 10 }
      }

      offense_obj = RubocopInteractive::Offense.new(file_path: file_path, data: offense_data)
      result = RubocopInteractive::PatchGenerator.generate(offense_obj)

      diff = result[:lines]

      # Trailing tabs should be shown with a marker like →→ or ⇥⇥
      assert_match(/→→|⇥⇥/, diff, "Trailing tabs should be shown with visible markers")
    end
  end
end
