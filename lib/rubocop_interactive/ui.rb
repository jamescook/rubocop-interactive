# frozen_string_literal: true

require 'io/console'

module RubocopInteractive
  # Handles terminal UI - can be replaced with a mock for testing
  class UI
    ACTIONS = {
      'a' => :autocorrect,
      's' => :skip,
      'd' => :disable_line,
      'D' => :disable_file,
      'q' => :quit,
      '?' => :help
    }.freeze

    def initialize(input: $stdin, output: $stdout)
      @input = input
      @output = output
    end

    def show_summary(total:)
      puts "Found #{total} offense(s) to review"
      puts '-' * 40
    end

    def show_offense(offense, index:, total:)
      puts
      puts "[#{index + 1}/#{total}] #{offense.cop_name}"
      puts "  #{offense.message}"
      puts "  #{offense.location}"
      puts
      show_code_context(offense)
    end

    def prompt_for_action(offense)
      loop do
        print_prompt(offense)
        input = read_input

        action = ACTIONS[input]

        if action == :help
          show_help(offense)
          next
        end

        return action if action

        puts "Unknown action: #{input.inspect}. Press '?' for help."
      end
    end

    def show_stats(stats)
      puts
      puts '-' * 40
      puts 'Summary:'
      puts "  Corrected: #{stats[:corrected]}"
      puts "  Skipped:   #{stats[:skipped]}"
      puts "  Disabled:  #{stats[:disabled]}"
    end

    private

    def puts(msg = '')
      @output.puts(msg)
    end

    def print(msg)
      @output.print(msg)
    end

    def read_input
      @input.getch
    end

    def print_prompt(offense)
      options = ['[a]utocorrect', '[s]kip', '[d]isable line', '[D]isable file', '[q]uit', '[?]help']
      options.delete('[a]utocorrect') unless offense.correctable?
      print options.join(' ') + ' > '
    end

    def show_help(offense)
      puts
      puts 'Actions:'
      puts '  a - Autocorrect this offense' if offense.correctable?
      puts '  s - Skip this offense'
      puts '  d - Disable cop for this line'
      puts '  D - Disable cop for entire file'
      puts '  q - Quit'
      puts
    end

    def show_code_context(offense)
      return unless File.exist?(offense.file_path)

      lines = File.readlines(offense.file_path)
      start_line = [offense.line - 2, 0].max
      end_line = [offense.line + 1, lines.size - 1].min

      (start_line..end_line).each do |i|
        line_num = i + 1
        prefix = line_num == offense.line ? '> ' : '  '
        puts "#{prefix}#{line_num.to_s.rjust(4)}: #{lines[i]}"
      end
    end
  end
end
