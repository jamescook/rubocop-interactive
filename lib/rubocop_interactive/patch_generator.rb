# frozen_string_literal: true

require 'tempfile'
require 'diff/lcs'

module RubocopInteractive
  # Generates a preview patch for an offense without applying it
  module PatchGenerator
    module_function

    def generate(offense)
      return nil unless offense.correctable?

      original_content = File.read(offense.file_path)

      # Create temp file and run rubocop autocorrect on it
      temp = Tempfile.new(['rubocop', '.rb'])
      begin
        temp.write(original_content)
        temp.close

        system(
          'rubocop', '--autocorrect', '--only', offense.cop_name, temp.path,
          out: File::NULL, err: File::NULL
        )

        corrected_content = File.read(temp.path)

        return nil if original_content == corrected_content

        # Generate diff and find the hunk for this offense
        original_lines = original_content.lines
        corrected_lines = corrected_content.lines

        hunk = extract_relevant_hunk(original_lines, corrected_lines, offense.line)
        return nil unless hunk

        { lines: hunk[:lines], start_line: hunk[:start] }
      ensure
        temp.unlink
      end
    end

    def extract_relevant_hunk(original_lines, corrected_lines, target_line)
      diffs = Diff::LCS.sdiff(original_lines, corrected_lines)

      # Group consecutive changes into hunks
      hunks = []
      current_hunk = { start: nil, lines: [] }
      context_before = nil

      diffs.each_with_index do |change, idx|
        old_pos = change.old_position ? change.old_position + 1 : nil

        case change.action
        when '='
          # Context line - keep track for potential hunk context
          if current_hunk[:lines].any?
            # Add trailing context and close hunk
            current_hunk[:lines] << " #{change.old_element}"
            hunks << current_hunk
            current_hunk = { start: nil, lines: [] }
          end
          context_before = { pos: old_pos, line: change.old_element }
        when '!', '-', '+'
          # Start new hunk if needed
          if current_hunk[:start].nil?
            current_hunk[:start] = old_pos || (context_before ? context_before[:pos] + 1 : 1)
            # Add leading context
            if context_before
              current_hunk[:lines] << " #{context_before[:line]}"
              current_hunk[:start] = context_before[:pos]
            end
          end

          case change.action
          when '!'
            current_hunk[:lines] << "-#{change.old_element}"
            current_hunk[:lines] << "+#{change.new_element}"
          when '-'
            current_hunk[:lines] << "-#{change.old_element}"
          when '+'
            current_hunk[:lines] << "+#{change.new_element}"
          end
        end
      end

      # Don't forget last hunk
      hunks << current_hunk if current_hunk[:lines].any?

      # Find hunk that contains target line
      hunks.each do |hunk|
        next unless hunk[:start]

        # Count only lines from the original (context and deletions)
        original_line_count = hunk[:lines].count { |l| l.start_with?(' ') || l.start_with?('-') }
        hunk_end = hunk[:start] + original_line_count - 1

        if target_line >= hunk[:start] && target_line <= hunk_end
          # Return only the portion of the hunk relevant to this specific offense
          # For now, return the whole hunk - but we could be smarter here
          return { lines: hunk[:lines].join, start: hunk[:start] }
        end
      end

      nil
    end
  end
end
