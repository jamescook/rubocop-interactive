# frozen_string_literal: true

require 'rubocop'
require 'stringio'
require_relative 'temp_file'

module RubocopInteractive
  # Performs actions on offenses (autocorrect, skip, disable)
  module Actions
    module_function

    def perform(action, offense, server:)
      case action
      when :autocorrect
        autocorrect(offense)
      when :disable_line
        disable_line(offense)
      when :disable_file
        disable_file(offense)
      when :quit
        { status: :quit }
      else
        nil
      end
    end

    def autocorrect(offense)
      original_content = File.read(offense.file_path)

      # Create temp file in project dir for config resolution
      temp_path = TempFile.create(original_content)
      begin
        # Run rubocop in-process (much faster than subprocess)
        run_rubocop_inprocess(
          '--autocorrect-all', '--only', offense.cop_name, temp_path
        )

        corrected_content = File.read(temp_path)

        if corrected_content != original_content
          File.write(offense.file_path, corrected_content)
          { status: :corrected }
        else
          { status: :skipped }
        end
      ensure
        TempFile.delete(temp_path)
      end
    end

    def run_rubocop_inprocess(*args)
      # Suppress stdout/stderr from rubocop
      old_stdout = $stdout
      old_stderr = $stderr
      $stdout = StringIO.new
      $stderr = StringIO.new

      cli = RuboCop::CLI.new
      cli.run(args)
    ensure
      $stdout = old_stdout
      $stderr = old_stderr
    end

    def disable_line(offense)
      lines = File.readlines(offense.file_path)
      line_index = offense.line - 1
      lines[line_index] = lines[line_index].chomp + " # rubocop:disable #{offense.cop_name}\n"
      File.write(offense.file_path, lines.join)
      { status: :disabled }
    end

    def disable_file(offense)
      lines = File.readlines(offense.file_path)
      lines.unshift("# rubocop:disable #{offense.cop_name}\n")
      lines.push("# rubocop:enable #{offense.cop_name}\n")
      File.write(offense.file_path, lines.join)
      { status: :disabled }
    end
  end
end
