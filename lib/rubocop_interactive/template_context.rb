# frozen_string_literal: true

require 'erb'

module RubocopInteractive
  # Provides context and helpers for ERB templates
  class TemplateContext
    attr_accessor :total_offenses, :offense_number, :cop_name, :message,
                  :file_path, :line, :column, :patch_lines, :patch_start_line,
                  :correctable, :available_actions, :state

    def initialize(attrs = {})
      attrs.each { |k, v| send("#{k}=", v) }
      @available_actions = []
    end

    def binding_for_erb
      binding
    end

    # Helper: file:line:column
    def location
      "#{file_path}:#{line}:#{column}"
    end

    # Helper: horizontal separator
    def separator(char: '-', width: 40)
      char * width
    end

    # Helper: render patch with colors
    # inline: true highlights only changed characters within lines
    # merge: true shows old/new as single merged line (requires inline: true)
    # show_spaces: character to use for visible spaces in diffs (e.g., '█' or '·')
    # line_numbers: true to show line numbers
    def patch(old_color: :red, new_color: :green, context_color: nil, inline: false, merge: false, show_spaces: nil, line_numbers: false)
      return '' unless patch_lines

      if inline
        render_inline_diff(old_color: old_color, new_color: new_color, context_color: context_color, merge: merge, show_spaces: show_spaces, line_numbers: line_numbers)
      else
        render_line_diff(old_color: old_color, new_color: new_color, context_color: context_color)
      end
    end

    private

    def render_line_diff(old_color:, new_color:, context_color:)
      patch_lines.map do |patch_line|
        if patch_line.start_with?('-')
          Color.colorize(patch_line, old_color)
        elsif patch_line.start_with?('+')
          Color.colorize(patch_line, new_color)
        elsif context_color
          Color.colorize(patch_line, context_color)
        else
          patch_line
        end
      end.join
    end

    def render_inline_diff(old_color:, new_color:, context_color:, merge: false, show_spaces: nil, line_numbers: false)
      require 'diff/lcs'

      result = []
      i = 0
      current_line = patch_start_line || 1

      while i < patch_lines.size
        line = patch_lines[i]
        line_num_str = line_numbers ? format('%4d ', current_line) : ''

        if line.start_with?('-') && i + 1 < patch_lines.size && patch_lines[i + 1].start_with?('+')
          # Pair of old/new lines - do inline diff
          old_line = line[1..].chomp  # Remove leading -
          new_line = patch_lines[i + 1][1..].chomp  # Remove leading +

          if merge
            # Single merged line with strikethrough-style display
            merged = inline_merge(old_line, new_line, old_color, new_color, show_spaces: show_spaces)
            result << "#{line_num_str}#{merged}\n"
          else
            # Two separate lines with inline highlighting
            old_highlighted, new_highlighted = inline_highlight(old_line, new_line, old_color, new_color)
            result << "#{line_num_str}-#{old_highlighted}\n"
            result << "#{line_num_str}+#{new_highlighted}\n"
          end
          current_line += 1
          i += 2
        elsif line.start_with?('-')
          result << "#{line_num_str}#{Color.colorize(line, old_color)}"
          current_line += 1
          i += 1
        elsif line.start_with?('+')
          # Added lines don't increment line number (they're inserted)
          add_line_str = line_numbers ? '     ' : ''
          result << "#{add_line_str}#{Color.colorize(line, new_color)}"
          i += 1
        elsif context_color
          result << "#{line_num_str}#{apply_context_color(line, context_color)}"
          current_line += 1
          i += 1
        else
          result << "#{line_num_str}#{line}"
          current_line += 1
          i += 1
        end
      end

      result.join
    end

    def apply_context_color(text, color)
      if color == :dim
        Color.dim(text)
      else
        Color.colorize(text, color)
      end
    end

    def inline_highlight(old_str, new_str, old_color, new_color)
      diffs = Diff::LCS.sdiff(old_str.chars, new_str.chars)

      old_result = []
      new_result = []

      diffs.each do |change|
        case change.action
        when '='
          # Unchanged - show in dim base color
          old_result << Color.colorize(change.old_element, old_color)
          new_result << Color.colorize(change.new_element, new_color)
        when '!'
          # Changed - bold highlight
          old_result << Color.colorize(change.old_element, old_color, bold: true)
          new_result << Color.colorize(change.new_element, new_color, bold: true)
        when '-'
          # Deleted - bold highlight
          old_result << Color.colorize(change.old_element, old_color, bold: true)
        when '+'
          # Added - bold highlight
          new_result << Color.colorize(change.new_element, new_color, bold: true)
        end
      end

      [old_result.join, new_result.join]
    end

    def inline_merge(old_str, new_str, old_color, new_color, show_spaces: nil)
      diffs = Diff::LCS.sdiff(old_str.chars, new_str.chars)

      result = []

      diffs.each do |change|
        case change.action
        when '='
          # Unchanged
          result << change.old_element
        when '!'
          # Changed - show old crossed out, then new
          old_char = show_spaces && change.old_element == ' ' ? show_spaces : change.old_element
          new_char = show_spaces && change.new_element == ' ' ? show_spaces : change.new_element
          result << Color.colorize(old_char, old_color, bold: true)
          result << Color.colorize(new_char, new_color, bold: true)
        when '-'
          # Deleted
          char = show_spaces && change.old_element == ' ' ? show_spaces : change.old_element
          result << Color.colorize(char, old_color, bold: true)
        when '+'
          # Added
          char = show_spaces && change.new_element == ' ' ? show_spaces : change.new_element
          result << Color.colorize(char, new_color, bold: true)
        end
      end

      result.join
    end

    public

    # Helper: render command palette
    def prompt(cursor: "\u2588", blink: true)
      options = build_prompt_options
      cursor_str = format_cursor(cursor, blink: blink)
      "#{options.join(' ')} #{cursor_str} "
    end

    # Helper: format cursor with optional blink
    def cursor(char: "\u2588", blink: true)
      format_cursor(char, blink: blink)
    end

    private

    def format_cursor(char, blink: true)
      return char unless $stdout.tty?

      hide_cursor = "\e[?25l"  # Hide terminal cursor
      # Note: ANSI blink (\e[5m) is ignored by most modern terminals
      # so we just show a static cursor
      "#{hide_cursor}#{char}"
    end

    public

    # Helper: colored text
    def color(text, color_name, bold: false)
      Color.colorize(text, color_name, bold: bold)
    end

    # Helper: bold text
    def bold(text)
      Color.bold(text)
    end

    # Helper: dim text
    def dim(text)
      Color.dim(text)
    end

    # Helper: italic text
    def italic(text)
      return text unless $stdout.tty?

      "\e[3m#{text}\e[0m"
    end

    # Helper: state indicator for offense
    def state_indicator
      case state
      when :corrected then Color.green('[CORRECTED]')
      when :disabled then Color.yellow('[DISABLED]')
      when :skipped then Color.dim('[SKIPPED]')
      else ''
      end
    end

    private

    def build_prompt_options
      options = []

      if correctable && state == :pending
        options << '[a]pply'
      end

      options << '[s]kip'
      options << '[d]isable line' if state == :pending
      options << '[D]isable file' if state == :pending
      options << '[q]uit'
      options << '[?]help'
      options << '[</>] nav'
      options
    end
  end
end
