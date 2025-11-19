# frozen_string_literal: true

require 'tempfile'
require 'diff/lcs'

module RubocopInteractive
  # Performs actions on offenses (autocorrect, skip, disable)
  module Actions
    module_function

    def perform(action, offense, server:)
      case action
      when :autocorrect
        autocorrect(offense)
      when :skip
        :skipped
      when :disable_line
        disable_line(offense)
      when :disable_file
        disable_file(offense)
      when :quit
        :quit
      else
        :skipped
      end
    end

    def autocorrect(offense)
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

        # Apply only the hunk that affects our offense line
        result = apply_surgical_correction(
          original_content,
          corrected_content,
          offense.line
        )

        if result
          File.write(offense.file_path, result)
          :corrected
        else
          :skipped # No applicable correction found
        end
      ensure
        temp.unlink
      end
    end

    def apply_surgical_correction(original, corrected, target_line)
      return original if original == corrected

      original_lines = original.lines
      corrected_lines = corrected.lines

      diffs = Diff::LCS.sdiff(original_lines, corrected_lines)

      # Group consecutive changes into hunks
      hunks = []
      current_hunk = { start: nil, old_lines: [], new_lines: [] }

      diffs.each do |change|
        old_pos = change.old_position ? change.old_position + 1 : nil

        case change.action
        when '='
          # Close current hunk if any
          if current_hunk[:start]
            hunks << current_hunk
            current_hunk = { start: nil, old_lines: [], new_lines: [] }
          end
        when '!', '-', '+'
          # Start new hunk if needed
          current_hunk[:start] ||= old_pos || 1

          case change.action
          when '!'
            current_hunk[:old_lines] << change.old_element
            current_hunk[:new_lines] << change.new_element
          when '-'
            current_hunk[:old_lines] << change.old_element
          when '+'
            current_hunk[:new_lines] << change.new_element
          end
        end
      end

      # Don't forget last hunk
      hunks << current_hunk if current_hunk[:start]

      # Find hunk that contains target line
      hunks.each do |hunk|
        hunk_start = hunk[:start]
        hunk_end = hunk_start + hunk[:old_lines].size - 1
        hunk_end = hunk_start if hunk[:old_lines].empty?

        next unless target_line >= hunk_start && target_line <= hunk_end

        # Apply this hunk
        result_lines = original_lines.dup
        start_index = hunk_start - 1
        delete_count = hunk[:old_lines].size

        result_lines.slice!(start_index, delete_count)
        hunk[:new_lines].each_with_index do |line, i|
          result_lines.insert(start_index + i, line)
        end

        return result_lines.join
      end

      nil # No hunk matched target line
    end

    def disable_line(offense)
      # Add rubocop:disable comment to the line
      add_disable_comment(offense, scope: :line)
      :disabled
    end

    def disable_file(offense)
      # Add rubocop:disable comment at top of file
      add_disable_comment(offense, scope: :file)
      :disabled
    end

    def add_disable_comment(offense, scope:)
      lines = File.readlines(offense.file_path)

      case scope
      when :line
        line_index = offense.line - 1
        lines[line_index] = lines[line_index].chomp + " # rubocop:disable #{offense.cop_name}\n"
      when :file
        lines.unshift("# rubocop:disable #{offense.cop_name}\n")
        lines.push("# rubocop:enable #{offense.cop_name}\n")
      end

      File.write(offense.file_path, lines.join)
    end
  end
end
