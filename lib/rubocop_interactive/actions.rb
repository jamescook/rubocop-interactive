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

      # Use RuboCop's internal corrector API to fix just this one offense
      corrected_content = apply_single_correction(
        offense.file_path,
        offense.cop_name,
        offense.line
      )

      if corrected_content && corrected_content != original_content
        File.write(offense.file_path, corrected_content)
        { status: :corrected }
      else
        { status: :skipped }
      end
    end

    def apply_single_correction(file_path, cop_name, target_line)
      config_store = RuboCop::ConfigStore.new
      config = config_store.for_file(file_path)

      # Get the specific cop
      cop_class = RuboCop::Cop::Registry.global.find_by_cop_name(cop_name)
      return nil unless cop_class

      registry = RuboCop::Cop::Registry.new([cop_class])
      team = RuboCop::Cop::Team.mobilize(registry, config, autocorrect: true)

      source = RuboCop::ProcessedSource.from_file(file_path, config.target_ruby_version)
      result = team.investigate(source)

      # Find the specific offense at the target line
      target_offense = result.offenses.find do |o|
        o.line == target_line && o.cop_name == cop_name
      end

      return nil unless target_offense&.corrector

      # Apply just this one corrector
      target_offense.corrector.rewrite
    end

    def disable_line(offense)
      lines = File.readlines(offense.file_path)
      line_index = offense.line - 1
      current_line = lines[line_index]

      if current_line.include?("rubocop:disable") && current_line.include?(offense.cop_name)
        # Already disabled - don't add duplicate
        { status: :disabled }
      elsif current_line.include?("rubocop:disable")
        # Already has a disable directive - append this cop to it
        lines[line_index] = current_line.sub(
          /(# rubocop:disable [^\n]+)/,
          "\\1, #{offense.cop_name}"
        )
        File.write(offense.file_path, lines.join)
        { status: :disabled }
      elsif current_line.strip.start_with?('#')
        # Comment-only line - wrap with disable/enable
        lines.insert(line_index, "# rubocop:disable #{offense.cop_name}\n")
        lines.insert(line_index + 2, "# rubocop:enable #{offense.cop_name}\n")
        File.write(offense.file_path, lines.join)
        { status: :disabled }
      else
        lines[line_index] = current_line.chomp + " # rubocop:disable #{offense.cop_name}\n"
        File.write(offense.file_path, lines.join)
        { status: :disabled }
      end
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
