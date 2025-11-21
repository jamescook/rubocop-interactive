# frozen_string_literal: true

require 'io/console'

module RubocopInteractive
  # Wrapper to record keypresses for test development
  class RecordingInput
    attr_reader :keypresses

    def initialize(input)
      @input = input
      @keypresses = []
    end

    def getch
      char = @input.getch
      @keypresses << char if char
      char
    end
  end

  # Handles terminal UI - can be replaced with a mock for testing
  class UI
    attr_reader :recording_input

    ACTIONS = {
      'a' => :autocorrect_safe,
      'A' => :autocorrect_unsafe,
      'L' => :correct_all,
      's' => :skip, # Skip moves to next, exits on last
      'd' => :disable_line,
      'D' => :disable_file,
      'p' => :show_patch,
      'e' => :open_editor,
      'q' => :quit,
      '?' => :help,
      "\u0003" => :interrupt # Ctrl+C
    }.freeze

    def initialize(input: nil, output: $stdout, confirm_patch: false, template: 'default', ansi: true, colorizer: nil, summary_on_exit: false, record_keypresses: false)
      # Use TTY for input when stdin is a pipe
      input ||= (File.open('/dev/tty') rescue $stdin)

      # Wrap input with recorder if requested
      if record_keypresses
        @recording_input = RecordingInput.new(input)
        @input = @recording_input
      else
        @input = input
      end

      @output = output
      @confirm_patch = confirm_patch
      @summary_on_exit = summary_on_exit
      @last_interrupt = nil
      @colorizer = colorizer || (ansi ? Color : NoopColorizer)
      @renderer = TemplateRenderer.new(template_name: template)
    end

    def show_summary(total:)
      puts "Found #{total} offense(s) to review"
      puts '-' * 40
    end

    def show_offense(offense, index:, total:, state: :pending, cop_count: nil)
      context = build_template_context(offense, index: index, total: total, state: state, cop_count: cop_count)
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
        error_msg = nil # Clear error for next iteration

        # Handle navigation (arrow keys return symbols)
        if input == :prev || input == :next
          return input
        end

        action = ACTIONS[input]

        if action == :help
          echo_input(input)
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

        # Handle correct_all with confirmation
        if action == :correct_all
          echo_input(input)
          if confirm_correct_all(offense)
            return action
          else
            # User cancelled, stay on current offense
            next
          end
        end

        if action
          echo_input(input)
          return action
        end

        # Show error inline
        error_msg = "Unknown: #{input.inspect}"
      end
    end

    def show_stats(stats)
      return unless @summary_on_exit

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

    def show_no_editor_error
      puts
      puts @colorizer.red("No $EDITOR environment variable defined")
      beep
    end

    def confirm_correct_all(offense)
      puts "Correct ALL remaining instances of #{@colorizer.yellow(offense.cop_name)}?"
      print "Are you sure? [[y]es / [n]o]: "

      loop do
        input = read_input
        case input
        when 'y', 'Y'
          puts @colorizer.cyan(@colorizer.bold('y'))
          return true
        when 'n', 'N', 's', 'q' # n, s(skip), q(quit) all mean no
          puts @colorizer.cyan(@colorizer.bold('n'))
          return false
        else
          clear_line
          print "Are you sure? [[y]es / [n]o]: #{@colorizer.red('(y/n)')}: "
        end
      end
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

    def echo_input(input)
      print "#{@colorizer.cyan(@colorizer.bold(input))}\n"
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
      options << '[e]dit'
      options << '[q]uit'
      options << '[?]help'
      options << '[</>] nav'

      options.join(' ') + ' > '
    end

    def show_help(offense)
      puts
      puts 'Actions:'
      if offense.correctable?
        if offense.safe_autocorrect?
          puts '  a - Autocorrect this offense'
        else
          puts '  A - Autocorrect this offense (unsafe)'
        end
        puts '  p - Show patch preview'
        puts '  L - Correct ALL remaining instances of this cop'
      end
      puts '  s - Skip this offense'
      puts '  d - Disable cop for this line'
      puts '  D - Disable cop for entire file'
      puts '  e - Open in $EDITOR'
      puts '  </> or arrow keys - Navigate between offenses'
      puts '  q - Quit'
      puts '  ? - Show this help'
      puts
    end

    def build_template_context(offense, index:, total:, state: :pending, cop_count: nil)
      TemplateContext.new(
        total_offenses: total,
        offense_number: index + 1,
        cop_name: offense.cop_name,
        cop_count: cop_count,
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
  end
end
