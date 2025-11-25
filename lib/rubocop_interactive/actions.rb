# frozen_string_literal: true

require 'rubocop'
require 'stringio'
require_relative 'temp_file'

module RubocopInteractive
  # Performs actions on offenses (autocorrect, skip, disable)
  module Actions # rubocop:disable Metrics/ModuleLength
    module_function

    def perform(action, offense)
      case action
      when :autocorrect
        autocorrect(offense)
      when :correct_all
        correct_all(offense)
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

    def correct_all(offenses)
      # Takes an array of offenses of the same cop type
      # Autocorrects each one individually (not all instances in files)
      return { status: :skipped } if offenses.empty?

      # Process offenses in reverse order (last line first) to preserve line numbers
      # as we make corrections
      offenses.sort_by(&:line).reverse_each do |offense|
        autocorrect(offense)
      end

      { status: :corrected }
    end

    def autocorrect(offense)
      original_content = File.read(offense.file_path)

      # Debug: preserve temp file state before correction
      # :nocov:
      if RubocopInteractive.config.debug_preserve_temp
        debug_file = "#{offense.file_path}.debug-before-#{Time.now.to_i}"
        File.write(debug_file, original_content)
        warn "Debug: saved file state to #{debug_file}"
      end
      # :nocov:

      # Use RuboCop's internal corrector API to fix just this one offense
      corrected_content = apply_single_correction(
        offense.file_path,
        offense.cop_name,
        offense.line
      )

      if corrected_content && corrected_content != original_content
        # Debug: preserve corrected content
        # :nocov:
        if RubocopInteractive.config.debug_preserve_temp
          debug_file = "#{offense.file_path}.debug-after-#{Time.now.to_i}"
          File.write(debug_file, corrected_content)
          warn "Debug: saved corrected content to #{debug_file}"
        end
        # :nocov:

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

      # Pass options to Registry.new to prevent nil registry methods
      options = { autocorrect: true }
      registry = RuboCop::Cop::Registry.new([cop_class], options)
      team = RuboCop::Cop::Team.mobilize(registry, config, options)

      source = RuboCop::ProcessedSource.from_file(file_path, config.target_ruby_version)
      # Set registry and config on the processed source so CommentConfig can access them
      source.registry = registry
      source.config = config

      # Capture errors during investigation
      result = begin
        team.investigate(source)
      rescue => e
        warn "Error during investigation: #{e.class}: #{e.message}" if RubocopInteractive.config.debug_preserve_temp
        warn e.backtrace.first(5).join("\n") if RubocopInteractive.config.debug_preserve_temp
        return nil
      end

      # Find the specific offense at the target line
      target_offense = result.offenses.find do |o|
        o.line == target_line && o.cop_name == cop_name
      end

      if RubocopInteractive.config.debug_preserve_temp
        warn "Debug: Found #{result.offenses.size} offenses, looking for #{cop_name} at line #{target_line}"
        warn "Debug: Target offense: #{target_offense.inspect}"
      end

      return nil unless target_offense&.corrector

      # Apply just this one corrector
      target_offense.corrector.rewrite
    end

    def disable_line(offense)
      lines = File.readlines(offense.file_path)
      line_index = offense.line - 1
      current_line = lines[line_index]

      # Check if line has an actual rubocop:disable comment (not just the text in a string/regex)
      disable_pattern = /(# rubocop:disable [^\n]+)/
      existing_disable = current_line.match(disable_pattern)

      if existing_disable && current_line.include?(offense.cop_name)
        # Already disabled for this cop - don't add duplicate
        { status: :disabled }
      elsif existing_disable
        # Already has a disable directive - append this cop to it
        lines[line_index] = current_line.sub(
          disable_pattern,
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
        # Normal line - append disable comment
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
