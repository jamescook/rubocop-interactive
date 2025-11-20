# frozen_string_literal: true

require 'diff/lcs'
require_relative 'temp_file'

module RubocopInteractive
  # Generates a preview patch for an offense without applying it
  module PatchGenerator
    CONTEXT_LINES = 2

    # Diff::LCS action types
    UNCHANGED = '='
    CHANGED = '!'
    DELETED = '-'
    ADDED = '+'

    module_function

    def generate(offense)
      return nil unless offense.correctable?

      original_content = File.read(offense.file_path)
      original_lines = original_content.lines

      # Create temp file with full content for valid Ruby syntax
      temp_path = TempFile.create(original_content)
      begin
        # Run rubocop on the full file
        run_rubocop_autocorrect(offense.cop_name, temp_path)

        corrected_content = File.read(temp_path)

        return nil if original_content == corrected_content

        corrected_lines = corrected_content.lines

        # Extract only the window around the target offense line
        extract_window(original_lines, corrected_lines, offense.line)
      ensure
        TempFile.delete(temp_path)
      end
    end

    # Extract a small window of diff output around a specific target line.
    #
    # Given a full file diff with multiple changes, this extracts only the
    # change affecting target_line plus surrounding context lines.
    #
    # Example: File with changes on lines 4, 6, and 8. Target is line 6.
    #
    #   Original:                    Corrected:
    #   1: # frozen_string_literal   1: # frozen_string_literal
    #   2:                           2:
    #   3: def foo                   3: def foo
    #   4:   x = "hello"             4:   x = 'hello'        <- change
    #   5:   y = 1                   5:   y = 1
    #   6:   z = "world"             6:   z = 'world'        <- TARGET
    #   7:   w = 2                   7:   w = 2
    #   8:   v = "bye"               8:   v = 'bye'          <- change
    #   9: end                       9: end
    #
    #   Diff::LCS.sdiff produces (simplified):
    #   [0] UNCHANGED line 1    [4] CHANGED line 4     [8] CHANGED line 8
    #   [1] UNCHANGED line 2    [5] UNCHANGED line 5   [9] UNCHANGED line 9
    #   [2] UNCHANGED line 3    [6] CHANGED line 6
    #   [3] UNCHANGED line 4    [7] UNCHANGED line 7
    #
    #   For target_line=6, we find diff index 6 (CHANGED).
    #   Then expand context, stopping at other changes:
    #     - Before: index 5 (UNCHANGED line 5) - can add
    #               index 4 (CHANGED line 4) - stop!
    #     - After:  index 7 (UNCHANGED line 7) - can add
    #               index 8 (CHANGED line 8) - stop!
    #
    #   Result (start_line=5):
    #     "   y = 1\n"           <- context
    #     "-  z = \"world\"\n"   <- old
    #     "+  z = 'world'\n"     <- new
    #     "   w = 2\n"           <- context
    #
    def extract_window(original_lines, corrected_lines, target_line)
      # Get the full diff
      diffs = Diff::LCS.sdiff(original_lines, corrected_lines)

      # Find the change that affects target_line
      target_diff_idx = nil
      current_orig_line = 0

      diffs.each_with_index do |change, idx|
        # Track line position in original file
        if [UNCHANGED, CHANGED, DELETED].include?(change.action)
          current_orig_line += 1
        end

        if change.action != UNCHANGED
          if current_orig_line == target_line
            # Change on the target line
            target_diff_idx = idx
            break
          elsif change.action == ADDED && current_orig_line == 0 && target_line == 1
            # Special case: addition before first line when targeting line 1
            target_diff_idx = idx
            break
          end
        end
      end

      return nil unless target_diff_idx

      # Only include this specific change, not consecutive changes for other lines
      # For CHANGED, this is just one diff entry
      # For DELETED/ADDED pairs on the same conceptual line, include both
      change_start = target_diff_idx
      change_end = target_diff_idx

      # If this is a DELETED followed by ADDED, include the ADDED
      if diffs[target_diff_idx].action == DELETED &&
         target_diff_idx + 1 < diffs.size &&
         diffs[target_diff_idx + 1].action == ADDED
        change_end = target_diff_idx + 1
      end

      # Add context lines before and after (stop at other changes)
      start_idx = expand_context(diffs, change_start, direction: :before)
      end_idx = expand_context(diffs, change_end, direction: :after)

      # Find actual start line number
      start_line = 1
      (0...start_idx).each do |i|
        action = diffs[i].action
        start_line += 1 if [UNCHANGED, CHANGED, DELETED].include?(action)
      end

      # Generate patch for this window
      result = []
      (start_idx..end_idx).each do |i|
        change = diffs[i]
        case change.action
        when UNCHANGED
          result << " #{change.old_element}"
        when CHANGED
          result << "-#{change.old_element}"
          result << "+#{change.new_element}"
        when DELETED
          result << "-#{change.old_element}"
        when ADDED
          result << "+#{change.new_element}"
        end
      end

      return nil if result.empty? || result.all? { |l| l.start_with?(' ') }

      { lines: result.join, start_line: start_line }
    end

    def expand_context(diffs, idx, direction:)
      step = direction == :before ? -1 : 1
      boundary = direction == :before ? 0 : diffs.size - 1
      context_added = 0

      while idx != boundary && context_added < CONTEXT_LINES
        next_idx = idx + step
        if diffs[next_idx].action == UNCHANGED
          idx = next_idx
          context_added += 1
        else
          break
        end
      end

      idx
    end

    def run_rubocop_autocorrect(cop_name, file_path)
      require 'rubocop'
      require 'stringio'

      old_stdout = $stdout
      old_stderr = $stderr
      $stdout = StringIO.new
      $stderr = StringIO.new

      cli = RuboCop::CLI.new
      cli.run(['--autocorrect-all', '--only', cop_name, file_path])
    ensure
      $stdout = old_stdout
      $stderr = old_stderr
    end

    def generate_diff(original_lines, corrected_lines)
      diffs = Diff::LCS.sdiff(original_lines, corrected_lines)

      result = []
      diffs.each do |change|
        case change.action
        when UNCHANGED
          result << " #{change.old_element}"
        when CHANGED
          result << "-#{change.old_element}"
          result << "+#{change.new_element}"
        when DELETED
          result << "-#{change.old_element}"
        when ADDED
          result << "+#{change.new_element}"
        end
      end

      result
    end
  end
end
