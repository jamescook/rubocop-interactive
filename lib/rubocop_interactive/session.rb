# frozen_string_literal: true

module RubocopInteractive
  # Manages the interactive session, iterating through offenses
  class Session
    attr_reader :stats

    def initialize(json, ui: UI.new, server: Server.new)
      @ui = ui
      @server = server
      @all_offenses = parse_all_offenses(json)
      @offense_states = {}  # offense.object_id => :pending/:corrected/:skipped/:disabled
      @stats = { corrected: 0, skipped: 0, disabled: 0 }
    end

    def offenses
      @all_offenses
    end

    def run
      total = @all_offenses.size
      @ui.show_summary(total: total)

      index = 0
      while index >= 0 && index < @all_offenses.size
        offense = @all_offenses[index]
        state = @offense_states[offense.object_id] || :pending

        @ui.show_offense(offense, index: index, total: total, state: state)

        action = @ui.prompt_for_action(offense, state: state)

        case action
        when :prev
          index = index - 1
          index = @all_offenses.size - 1 if index < 0  # Wrap to end
          next
        when :next
          index = index + 1
          index = 0 if index >= @all_offenses.size  # Wrap to start
          next
        when :quit
          @ui.show_stats(@stats)
          return @stats
        end

        result = Actions.perform(action, offense, server: @server)
        track_result(result)
        @offense_states[offense.object_id] = result if result != :skipped || state == :pending

        # Move to next offense after action (unless already at end)
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
      when :skipped then @stats[:skipped] += 1
      when :disabled then @stats[:disabled] += 1
      end
    end
  end
end
