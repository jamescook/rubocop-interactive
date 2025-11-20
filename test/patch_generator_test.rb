# frozen_string_literal: true

require_relative 'test_helper'

class PatchGeneratorTest < Minitest::Test
  def test_generate_diff_single_change
    original = ["line 1\n", "line 2\n", "line 3\n"]
    corrected = ["line 1\n", "changed 2\n", "line 3\n"]

    result = RubocopInteractive::PatchGenerator.generate_diff(original, corrected)

    assert_includes result, " line 1\n"
    assert_includes result, "-line 2\n"
    assert_includes result, "+changed 2\n"
    assert_includes result, " line 3\n"
  end

  def test_generate_diff_deletion
    original = ["a\n", "b\n", "c\n"]
    corrected = ["a\n", "c\n"]

    result = RubocopInteractive::PatchGenerator.generate_diff(original, corrected)

    assert_includes result, " a\n"
    assert_includes result, "-b\n"
    assert_includes result, " c\n"
    refute_includes result, "+b"
  end

  def test_generate_diff_addition
    original = ["a\n", "c\n"]
    corrected = ["a\n", "b\n", "c\n"]

    result = RubocopInteractive::PatchGenerator.generate_diff(original, corrected)

    assert_includes result, " a\n"
    assert_includes result, "+b\n"
    assert_includes result, " c\n"
  end

  def test_generate_diff_multiple_changes
    original = ["a\n", "b\n", "c\n", "d\n"]
    corrected = ["a\n", "X\n", "Y\n", "d\n"]

    result = RubocopInteractive::PatchGenerator.generate_diff(original, corrected)

    assert_includes result, " a\n"
    assert_includes result, "-b\n"
    assert_includes result, "+X\n"
    assert_includes result, "-c\n"
    assert_includes result, "+Y\n"
    assert_includes result, " d\n"
  end

  def test_generate_diff_no_changes
    original = ["a\n", "b\n", "c\n"]
    corrected = ["a\n", "b\n", "c\n"]

    result = RubocopInteractive::PatchGenerator.generate_diff(original, corrected)

    # All context lines
    assert_equal [" a\n", " b\n", " c\n"], result
  end

  def test_generate_with_string_literals_offense
    # Create a temp file with double-quoted string that should be single-quoted
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        def foo
          x = "double quotes"
          x
        end
      RUBY

      # Create an offense like RuboCop would report
      offense = RubocopInteractive::Offense.new(
        file_path: file_path,
        data: {
          'cop_name' => 'Style/StringLiterals',
          'message' => "Prefer single-quoted strings when you don't need string interpolation or special symbols.",
          'severity' => 'convention',
          'correctable' => true,
          'location' => {
            'start_line' => 4,
            'start_column' => 7,
            'length' => 15
          }
        }
      )

      result = RubocopInteractive::PatchGenerator.generate(offense)

      assert result, "Should generate a patch for Style/StringLiterals"
      assert result[:lines], "Should have patch lines"
      assert_match(/-.*"double quotes"/, result[:lines], "Should show old double-quoted string")
      assert_match(/\+.*'double quotes'/, result[:lines], "Should show new single-quoted string")
    end
  end

  def test_generate_with_bad_code_fixture
    # Use the actual bad_code.rb fixture - Style/StringLiterals on line 6
    file_path = File.expand_path('fixtures/sample_project/bad_code.rb', __dir__)

    offense = RubocopInteractive::Offense.new(
      file_path: file_path,
      data: {
        'cop_name' => 'Style/StringLiterals',
        'message' => "Prefer single-quoted strings when you don't need string interpolation or special symbols.",
        'severity' => 'convention',
        'correctable' => true,
        'location' => {
          'start_line' => 6,
          'start_column' => 7,
          'length' => 15
        }
      }
    )

    result = RubocopInteractive::PatchGenerator.generate(offense)

    assert result, "Should generate a patch for Style/StringLiterals in bad_code.rb"
    assert result[:lines], "Should have patch lines"
    assert_match(/-.*"double quotes"/, result[:lines], "Should show old double-quoted string")
    assert_match(/\+.*'double quotes'/, result[:lines], "Should show new single-quoted string")
  end

  def test_generate_useless_assignment_only_shows_target_line
    # Lint/UselessAssignment on line 12 should only show line 12 being deleted
    # Not line 13 (hash = ...) which is unrelated
    file_path = File.expand_path('fixtures/sample_project/bad_code.rb', __dir__)

    offense = RubocopInteractive::Offense.new(
      file_path: file_path,
      data: {
        'cop_name' => 'Lint/UselessAssignment',
        'message' => 'Useless assignment to variable - `array`.',
        'severity' => 'warning',
        'correctable' => true,
        'location' => {
          'start_line' => 12,
          'start_column' => 3,
          'length' => 5
        }
      }
    )

    result = RubocopInteractive::PatchGenerator.generate(offense)

    assert result, "Should generate a patch for Lint/UselessAssignment"
    assert result[:lines], "Should have patch lines"

    # Should show the deletion of line 12's assignment
    assert_match(/-.*array\s*=/, result[:lines], "Should show deletion of array assignment")

    # Should NOT show line 13's hash as a change
    refute_match(/-.*hash\s*=/, result[:lines], "Should not show line 13 hash as deleted")
    refute_match(/\+.*hash\s*=/, result[:lines], "Should not show line 13 hash as added")
  end
end
