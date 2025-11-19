# frozen_string_literal: true

module RubocopInteractive
  # Manages the interactive session, iterating through offenses
  class Session
    attr_reader :stats

    def initialize(json, ui: UI.new, server: Server.new)
      @ui = ui
      @server = server
      @all_offenses = parse_all_offenses(json)
      @offense_states = {}  # offense.object_id => :pending/:corrected/:disabled
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
        state = @offense_states[offense.object_id] || :pending

        if needs_redraw
          @ui.show_offense(offense, index: index, total: total, state: state)
        end
        needs_redraw = true

        action = @ui.prompt_for_action(offense, state: state)

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
        end

        # Other actions (autocorrect, disable)
        result = Actions.perform(action, offense, server: @server)
        if result
          track_result(result)
          @offense_states[offense.object_id] = result
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
  end
end
