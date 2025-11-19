# frozen_string_literal: true

module RubocopInteractive
  # Manages the interactive session, iterating through offenses
  class Session
    attr_reader :stats

    def initialize(json, ui: UI.new, server: Server.new)
      @ui = ui
      @server = server
      @offenses_by_file = parse_offenses_by_file(json)
      @stats = { corrected: 0, skipped: 0, disabled: 0 }
    end

    def offenses
      @offenses_by_file.values.flatten
    end

    def run
      total = offenses.size
      @ui.show_summary(total: total)

      index = 0
      @offenses_by_file.each do |file_path, file_offenses|
        while file_offenses.any?
          offense = file_offenses.shift
          @ui.show_offense(offense, index: index, total: total)

          action = @ui.prompt_for_action(offense)
          result = Actions.perform(action, offense, server: @server)

          track_result(result)

          if result == :quit
            @ui.show_stats(@stats)
            return @stats
          end

          # If we modified the file, re-scan to get fresh line numbers
          if result == :corrected || result == :disabled
            file_offenses = refresh_offenses_for_file(file_path)
            @offenses_by_file[file_path] = file_offenses
          end

          index += 1
        end
      end

      @ui.show_stats(@stats)
      @stats
    end

    private

    def parse_offenses_by_file(json)
      data = json.is_a?(String) ? JSON.parse(json) : json

      offenses_by_file = {}
      data['files'].each do |file|
        file_path = file['path']
        offenses_by_file[file_path] = file['offenses'].map do |offense_data|
          Offense.new(file_path: file_path, data: offense_data)
        end
      end
      offenses_by_file
    end

    def refresh_offenses_for_file(file_path)
      # Re-run rubocop on just this file to get fresh offenses
      json_output = `rubocop --format json "#{file_path}" 2>/dev/null`
      return [] if json_output.empty?

      data = JSON.parse(json_output)
      file_data = data['files'].first
      return [] unless file_data

      file_data['offenses'].map do |offense_data|
        Offense.new(file_path: file_path, data: offense_data)
      end
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
