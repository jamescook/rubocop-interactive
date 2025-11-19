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
      '?' => :help,
      "\u0003" => :interrupt  # Ctrl+C
    }.freeze

    # Arrow key escape sequences
    ARROW_LEFT = "\e[D"
    ARROW_RIGHT = "\e[C"
    ARROW_UP = "\e[A"
    ARROW_DOWN = "\e[B"

    def initialize(input: nil, output: $stdout, confirm_patch: false, template: 'default')
      # Use TTY for input when stdin is a pipe
      @input = input || (File.open('/dev/tty') rescue $stdin)
      @output = output
      @confirm_patch = confirm_patch
      @last_interrupt = nil
      @renderer = TemplateRenderer.new(template_name: template)
    end

    def show_summary(total:)
      puts "Found #{total} offense(s) to review"
      puts '-' * 40
    end

    def show_offense(offense, index:, total:, state: :pending)
      context = build_template_context(offense, index: index, total: total, state: state)
      output = @renderer.render(context)

      # Print everything except the prompt (last line)
      lines = output.lines
      prompt_line = lines.pop
      puts
      lines.each { |line| print line }

      # Store prompt for later use
      @current_prompt = prompt_line
    end

    def prompt_for_action(offense, state: :pending)
      prompt_text = (@current_prompt || build_default_prompt(offense, state: state)).chomp
      error_msg = nil

      loop do
        # Clear line and reprint prompt
        clear_line
        print prompt_text
        print Color.red(" #{error_msg}") if error_msg

        input = read_input
        error_msg = nil  # Clear error for next iteration

        # Handle navigation (arrow keys return symbols)
        if input == :prev || input == :next
          puts  # Move to new line
          return input
        end

        action = ACTIONS[input]

        if action == :help
          puts  # Move to new line before help
          show_help(offense)
          next
        end

        if action == :interrupt
          if @last_interrupt && (Time.now - @last_interrupt) < 1.0
            puts "\nExiting..."
            return :quit
          else
            @last_interrupt = Time.now
            error_msg = "Press Ctrl+C again quickly to exit"
            next
          end
        end

        if action
          puts  # Move to new line after valid action
          return action
        end

        # Show error inline
        error_msg = "Unknown: #{input.inspect}"
      end
    end

    def show_stats(stats)
      restore_cursor
      puts
      puts '-' * 40
      puts 'Summary:'
      puts "  Corrected: #{stats[:corrected]}"
      puts "  Skipped:   #{stats[:skipped]}"
      puts "  Disabled:  #{stats[:disabled]}"
    end

    private

    def restore_cursor
      print "\e[?25h"  # Show terminal cursor again
    end

    def puts(msg = '')
      @output.puts(msg)
    end

    def print(msg)
      @output.print(msg)
    end

    def read_input
      char = @input.getch

      # Handle escape sequences (arrow keys)
      if char == "\e"
        # Read the rest of the escape sequence
        seq = char + @input.getch + @input.getch
        case seq
        when ARROW_LEFT, ARROW_UP then return :prev
        when ARROW_RIGHT, ARROW_DOWN then return :next
        else return seq
        end
      end

      char
    end

    def clear_line
      # Move cursor to beginning of line and clear it
      print "\r\e[K"
    end

    def build_default_prompt(offense, state: :pending)
      options = []

      # Only show autocorrect if pending and correctable
      if state == :pending && offense.correctable?
        options << (@confirm_patch ? '[a]pply' : '[a]utocorrect')
      end

      options << '[s]kip'
      options << '[d]isable line' if state == :pending
      options << '[D]isable file' if state == :pending
      options << '[q]uit'
      options << '[?]help'
      options << '[</>] nav'

      options.join(' ') + ' > '
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

    def build_template_context(offense, index:, total:, state: :pending)
      patch_lines = nil
      patch_start_line = nil

      if @confirm_patch && offense.correctable?
        patch_data = PatchGenerator.generate(offense)
        if patch_data
          patch_lines = patch_data[:lines].lines
          patch_start_line = patch_data[:start_line]
        else
          patch_lines = build_code_context_lines(offense)
          patch_start_line = [offense.line - 1, 1].max
        end
      else
        patch_lines = build_code_context_lines(offense)
        patch_start_line = [offense.line - 1, 1].max
      end

      TemplateContext.new(
        total_offenses: total,
        offense_number: index + 1,
        cop_name: offense.cop_name,
        message: offense.message,
        file_path: offense.file_path,
        line: offense.line,
        column: offense.column,
        correctable: state == :pending && offense.correctable?,
        state: state,
        patch_lines: patch_lines,
        patch_start_line: patch_start_line
      )
    end

    def build_code_context_lines(offense)
      return [] unless File.exist?(offense.file_path)

      lines = File.readlines(offense.file_path)
      start_line = [offense.line - 2, 0].max
      end_line = [offense.line + 1, lines.size - 1].min

      (start_line..end_line).map do |i|
        line_num = i + 1
        prefix = line_num == offense.line ? '> ' : '  '
        "#{prefix}#{line_num.to_s.rjust(4)}: #{lines[i]}"
      end
    end
  end
end
