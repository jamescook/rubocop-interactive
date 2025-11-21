# frozen_string_literal: true

require 'io/console'

module RubocopInteractive
  # Handles terminal UI - can be replaced with a mock for testing
  class UI
    ACTIONS = {
      'a' => :autocorrect_safe,
      'A' => :autocorrect_unsafe,
      's' => :skip,  # Skip moves to next, exits on last
      'd' => :disable_line,
      'D' => :disable_file,
      'p' => :show_patch,
      'q' => :quit,
      '?' => :help,
      "\u0003" => :interrupt  # Ctrl+C
    }.freeze

    def initialize(input: nil, output: $stdout, confirm_patch: false, template: 'default', ansi: true, colorizer: nil)
      # Use TTY for input when stdin is a pipe
      @input = input || (File.open('/dev/tty') rescue $stdin)
      @output = output
      @confirm_patch = confirm_patch
      @last_interrupt = nil
      @colorizer = colorizer || (ansi ? Color : NoopColorizer)
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
        print @colorizer.red(" #{error_msg}") if error_msg

        input = read_input
        error_msg = nil  # Clear error for next iteration

        # Handle navigation (arrow keys return symbols)
        if input == :prev || input == :next
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
          print "#{input}\n"  # Echo the keypress and move to new line
          return action
        end

        # Show error inline
        error_msg = "Unknown: #{input.inspect}"
      end
    end

    def show_stats(stats)
      puts
      puts '-' * 40
      puts 'Summary:'
      puts "  Corrected: #{stats[:corrected]}"
      puts "  Disabled:  #{stats[:disabled]}"
    end

    def beep
      print @colorizer::BELL
    end

    def show_unsafe_error
      # Clear line and show error - will be cleared on next prompt
      clear_line
      print @colorizer.yellow("Press 'A' (capital) for unsafe autocorrect")
      beep
    end

    def show_patch(offense)
      return unless offense.correctable?

      patch_data = PatchGenerator.generate(offense)
      return unless patch_data

      # Build a context just for rendering the patch
      context = TemplateContext.new(
        patch_lines: patch_data[:lines].lines,
        patch_start_line: patch_data[:start_line],
        colorizer: @colorizer
      )

      puts
      puts context.patch(
        old_color: :red,
        new_color: :green,
        context_color: :dim,
        inline: false,
        merge: false,
        line_numbers: true
      )
    end

    private

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
        when ANSI::ARROW_LEFT, ANSI::ARROW_UP then return :prev
        when ANSI::ARROW_RIGHT, ANSI::ARROW_DOWN then return :next
        else return seq
        end
      end

      char
    end

    def clear_line
      print @colorizer::CLEAR_LINE
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
      TemplateContext.new(
        total_offenses: total,
        offense_number: index + 1,
        cop_name: offense.cop_name,
        message: offense.message,
        file_path: offense.file_path,
        line: offense.line,
        column: offense.column,
        length: offense.length,
        correctable: state == :pending && offense.correctable?,
        safe_autocorrect: offense.safe_autocorrect?,
        state: state,
        colorizer: @colorizer
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
