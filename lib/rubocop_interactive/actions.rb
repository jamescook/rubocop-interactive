# frozen_string_literal: true

require 'tempfile'
require 'diffy'

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

      diff = Diffy::Diff.new(original, corrected, context: 0, include_diff_info: true)
      diff_text = diff.to_s

      hunks = parse_hunks(diff_text)
      original_lines = original.lines

      hunks.each do |hunk|
        # Check if this hunk affects our target line
        hunk_start = hunk[:old_start]
        hunk_end = hunk[:old_start] + hunk[:old_count] - 1
        hunk_end = hunk_start if hunk[:old_count] == 0

        next unless target_line >= hunk_start && target_line <= hunk_end

        # Apply this hunk
        result_lines = original_lines.dup
        start_index = hunk[:old_start] - 1
        delete_count = hunk[:old_count]

        # Remove old lines, insert new lines
        result_lines.slice!(start_index, delete_count)
        hunk[:new_lines].each_with_index do |line, i|
          result_lines.insert(start_index + i, line)
        end

        return result_lines.join
      end

      nil # No hunk matched target line
    end

    def parse_hunks(diff_text)
      hunks = []
      current_hunk = nil

      diff_text.each_line do |line|
        if line.start_with?('@@')
          # Save previous hunk
          hunks << current_hunk if current_hunk

          # Parse header: @@ -start,count +start,count @@ or @@ -start +start @@
          match = line.match(/@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@/)
          next unless match

          current_hunk = {
            old_start: match[1].to_i,
            old_count: (match[2] || 1).to_i,
            new_start: match[3].to_i,
            new_count: (match[4] || 1).to_i,
            new_lines: []
          }
        elsif current_hunk
          # Collect new lines (+ lines)
          if line.start_with?('+') && !line.start_with?('+++')
            current_hunk[:new_lines] << line[1..]
          elsif line.start_with?(' ')
            current_hunk[:new_lines] << line[1..]
          end
          # Skip - lines (they're being removed)
        end
      end

      # Don't forget last hunk
      hunks << current_hunk if current_hunk

      hunks
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
