# frozen_string_literal: true

require_relative 'test_helper'
require 'rubocop_interactive/patch_generator'

class PatchGeneratorTest < Minitest::Test
  def test_extract_relevant_hunk_single_change
    original = ["line 1\n", "line 2\n", "line 3\n"]
    corrected = ["line 1\n", "changed 2\n", "line 3\n"]

    result = RubocopInteractive::PatchGenerator.extract_relevant_hunk(original, corrected, 2)

    assert result
    assert_equal 1, result[:start]  # Context starts at line 1
    assert_includes result[:lines], " line 1\n"
    assert_includes result[:lines], "-line 2\n"
    assert_includes result[:lines], "+changed 2\n"
  end

  def test_extract_relevant_hunk_with_context
    original = ["a\n", "b\n", "c\n", "d\n", "e\n"]
    corrected = ["a\n", "b\n", "X\n", "d\n", "e\n"]

    result = RubocopInteractive::PatchGenerator.extract_relevant_hunk(original, corrected, 3)

    assert result
    # Should include context line before
    assert_includes result[:lines], " b\n"
    assert_includes result[:lines], "-c\n"
    assert_includes result[:lines], "+X\n"
    # Should include context line after
    assert_includes result[:lines], " d\n"
  end

  def test_extract_relevant_hunk_deletion
    original = ["a\n", "b\n", "c\n"]
    corrected = ["a\n", "c\n"]

    result = RubocopInteractive::PatchGenerator.extract_relevant_hunk(original, corrected, 2)

    assert result
    assert_includes result[:lines], "-b\n"
    refute_includes result[:lines], "+b"
  end

  def test_extract_relevant_hunk_addition
    original = ["a\n", "c\n"]
    corrected = ["a\n", "b\n", "c\n"]

    # Target line 2 in original (which is "c")
    # After addition, we're looking at the change near line 2
    result = RubocopInteractive::PatchGenerator.extract_relevant_hunk(original, corrected, 1)

    assert result
    assert_includes result[:lines], "+b\n"
  end

  def test_extract_relevant_hunk_multiple_hunks_returns_correct_one
    original = ["a\n", "b\n", "c\n", "d\n", "e\n", "f\n", "g\n"]
    corrected = ["a\n", "X\n", "c\n", "d\n", "e\n", "Y\n", "g\n"]

    # Get hunk for line 2 (b -> X)
    result = RubocopInteractive::PatchGenerator.extract_relevant_hunk(original, corrected, 2)
    assert result
    assert_includes result[:lines], "-b\n"
    assert_includes result[:lines], "+X\n"
    refute_includes result[:lines], "-f\n"

    # Get hunk for line 6 (f -> Y)
    result = RubocopInteractive::PatchGenerator.extract_relevant_hunk(original, corrected, 6)
    assert result
    assert_includes result[:lines], "-f\n"
    assert_includes result[:lines], "+Y\n"
    refute_includes result[:lines], "-b\n"
  end

  def test_extract_relevant_hunk_no_match_returns_nil
    original = ["a\n", "b\n", "c\n"]
    corrected = ["a\n", "X\n", "c\n"]

    # Line 3 is not in any hunk
    result = RubocopInteractive::PatchGenerator.extract_relevant_hunk(original, corrected, 3)

    # Line 3 is context after the hunk, so might be included
    # Let's check line 1 which is definitely not in the hunk
    result = RubocopInteractive::PatchGenerator.extract_relevant_hunk(original, corrected, 1)

    # Line 1 is context before the hunk at line 2
    # The hunk includes it, so we need a line that's not in any hunk
    original = ["a\n", "b\n", "c\n", "d\n", "e\n"]
    corrected = ["a\n", "X\n", "c\n", "d\n", "e\n"]

    # Line 5 is far from the change
    result = RubocopInteractive::PatchGenerator.extract_relevant_hunk(original, corrected, 5)
    assert_nil result
  end

  def test_extract_relevant_hunk_returns_start_line
    original = ["line 1\n", "line 2\n", "line 3\n", "line 4\n", "line 5\n"]
    corrected = ["line 1\n", "line 2\n", "changed\n", "line 4\n", "line 5\n"]

    result = RubocopInteractive::PatchGenerator.extract_relevant_hunk(original, corrected, 3)

    assert result
    assert_equal 2, result[:start]  # Context starts at line 2
  end

  def test_extract_relevant_hunk_consecutive_changes
    original = ["a\n", "b\n", "c\n", "d\n"]
    corrected = ["a\n", "X\n", "Y\n", "d\n"]

    result = RubocopInteractive::PatchGenerator.extract_relevant_hunk(original, corrected, 2)

    assert result
    assert_includes result[:lines], "-b\n"
    assert_includes result[:lines], "+X\n"
    assert_includes result[:lines], "-c\n"
    assert_includes result[:lines], "+Y\n"
  end
end
