# frozen_string_literal: true

module RubocopInteractive
  # Manages the interactive session, iterating through offenses
  class Session
    attr_reader :stats

    def initialize(json, ui: UI.new, server: Server.new)
      @ui = ui
      @server = server
      @all_offenses = parse_all_offenses(json)
      @stats = { corrected: 0, disabled: 0 }
    end

    def offenses
      @all_offenses
    end

    def run
      total = @all_offenses.size
      @ui.show_summary(total: total)

      index = 0
      needs_redraw = true
      while index >= 0 && index < @all_offenses.size
        offense = @all_offenses[index]

        if needs_redraw
          @ui.show_offense(offense, index: index, total: @all_offenses.size, state: :pending)
        end
        needs_redraw = true

        action = @ui.prompt_for_action(offense, state: :pending)

        # Navigation (arrow keys) - stop at boundaries, don't exit
        case action
        when :prev
          if index == 0
            @ui.beep
            needs_redraw = false
          else
            index -= 1
          end
          next
        when :next
          if index >= @all_offenses.size - 1
            @ui.beep
            needs_redraw = false
          else
            index += 1
          end
          next
        when :quit
          @ui.show_stats(@stats)
          return @stats
        when :skip
          # Skip is an action - exits on last offense
          if index >= @all_offenses.size - 1
            @ui.show_stats(@stats)
            return @stats
          end
          index += 1
          next
        when :show_patch
          @ui.show_patch(offense)
          needs_redraw = false
          next
        end

        # Handle autocorrect with safe/unsafe validation
        if action == :autocorrect_safe || action == :autocorrect_unsafe
          if !offense.correctable?
            # Can't autocorrect non-correctable offense - beep and stay
            @ui.beep
            needs_redraw = false
            next
          elsif action == :autocorrect_safe && !offense.safe_autocorrect?
            # User pressed 'a' but this is unsafe - show error and retry
            @ui.show_unsafe_error
            needs_redraw = false
            next
          end
          action = :autocorrect
        end

        # Other actions (autocorrect, disable)
        result = Actions.perform(action, offense, server: @server)
        if result
          track_result(result[:status])

          # Re-scan file to get fresh offense list
          # This handles: fixes that resolve multiple offenses, or introduce new ones
          rescan_file(offense.file_path)

          # Exit if no offenses remain
          if @all_offenses.empty?
            @ui.show_stats(@stats)
            return @stats
          end

          # Clamp index to valid range (in case we removed more than we added)
          index = [index, @all_offenses.size - 1].min

          # If correction was skipped (no change), move to next offense to avoid infinite loop
          if result[:status] == :skipped
            if index >= @all_offenses.size - 1
              @ui.show_stats(@stats)
              return @stats
            end
            index += 1
          end
          next
        end

        # Exit on last offense, otherwise move to next
        if index >= @all_offenses.size - 1
          @ui.show_stats(@stats)
          return @stats
        end
        index += 1
      end

      @ui.show_stats(@stats)
      @stats
    end

    private

    def parse_all_offenses(json)
      data = json.is_a?(String) ? JSON.parse(json) : json

      offenses = []
      data['files'].each do |file|
        file_path = file['path']
        file['offenses'].each do |offense_data|
          offenses << Offense.new(file_path: file_path, data: offense_data)
        end
      end
      offenses
    end

    def track_result(result)
      case result
      when :corrected then @stats[:corrected] += 1
      when :disabled then @stats[:disabled] += 1
      end
    end

    def rescan_file(file_path)
      # Re-run rubocop on the file to get fresh offenses (in-process for speed)
      json_output = run_rubocop_json(file_path)
      return if json_output.empty?

      fresh_data = JSON.parse(json_output)
      return unless fresh_data['files']&.any?

      file_data = fresh_data['files'][0]
      fresh_offenses = (file_data['offenses'] || []).map do |offense_data|
        Offense.new(file_path: file_path, data: offense_data)
      end

      # Find where this file's offenses start and end in our list
      first_index = @all_offenses.index { |o| o.file_path == file_path }
      return unless first_index # No offenses for this file (shouldn't happen)

      # Remove old offenses for this file
      @all_offenses.reject! { |o| o.file_path == file_path }

      # Insert fresh offenses at the original position
      # Use first_index since current_index may now be invalid after reject!
      insert_at = [first_index, @all_offenses.size].min
      fresh_offenses.each_with_index do |offense, i|
        @all_offenses.insert(insert_at + i, offense)
      end
    end

    def run_rubocop_json(file_path)
      require 'rubocop'
      require 'stringio'

      # Capture JSON output from rubocop
      output = StringIO.new
      old_stdout = $stdout
      old_stderr = $stderr
      $stdout = output
      $stderr = StringIO.new

      cli = RuboCop::CLI.new
      cli.run(['--format', 'json', file_path])

      output.string
    ensure
      $stdout = old_stdout
      $stderr = old_stderr
    end
  end
end
