# frozen_string_literal: true

require 'erb'

module RubocopInteractive
  # Provides context and helpers for ERB templates
  class TemplateContext
    attr_accessor :total_offenses, :offense_number, :cop_name, :cop_count, :message,
                  :file_path, :line, :column, :length, :patch_lines, :patch_start_line,
                  :correctable, :safe_autocorrect, :available_actions, :state, :active,
                  :colorizer

    def initialize(attrs = {})
      attrs.each { |k, v| send("#{k}=", v) }
      @available_actions = []
      @colorizer ||= Color
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
          colorizer.colorize(patch_line, old_color)
        elsif patch_line.start_with?('+')
          colorizer.colorize(patch_line, new_color)
        elsif context_color
          colorizer.colorize(patch_line, context_color)
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
          old_line = line[1..].chomp # Remove leading -
          new_line = patch_lines[i + 1][1..].chomp # Remove leading +

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
          result << "#{line_num_str}#{colorizer.colorize(line, old_color)}"
          current_line += 1
          i += 1
        elsif line.start_with?('+')
          # Added lines don't increment line number (they're inserted)
          add_line_str = line_numbers ? '     ' : ''
          result << "#{add_line_str}#{colorizer.colorize(line, new_color)}"
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
        colorizer.dim(text)
      else
        colorizer.colorize(text, color)
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
          old_result << colorizer.colorize(change.old_element, old_color)
          new_result << colorizer.colorize(change.new_element, new_color)
        when '!'
          # Changed - bold highlight
          old_result << colorizer.colorize(change.old_element, old_color, bold: true)
          new_result << colorizer.colorize(change.new_element, new_color, bold: true)
        when '-'
          # Deleted - bold highlight
          old_result << colorizer.colorize(change.old_element, old_color, bold: true)
        when '+'
          # Added - bold highlight
          new_result << colorizer.colorize(change.new_element, new_color, bold: true)
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
          result << colorizer.colorize(old_char, old_color, bold: true)
          result << colorizer.colorize(new_char, new_color, bold: true)
        when '-'
          # Deleted
          char = show_spaces && change.old_element == ' ' ? show_spaces : change.old_element
          result << colorizer.colorize(char, old_color, bold: true)
        when '+'
          # Added
          char = show_spaces && change.new_element == ' ' ? show_spaces : change.new_element
          result << colorizer.colorize(char, new_color, bold: true)
        end
      end

      result.join
    end

    public

    # Helper: render command palette (default implementation)
    def prompt
      default_prompt
    end

    # Helper: default prompt implementation
    def default_prompt
      options = build_prompt_options
      "#{options.join(' ')} "
    end

    # Predicate helpers for building custom prompts in templates

    def can_autocorrect?
      correctable && state == :pending
    end

    def can_disable?
      state == :pending
    end

    def is_pending?
      state == :pending
    end

    def is_safe_autocorrect?
      safe_autocorrect
    end

    # Helper: colored text
    def color(text, color_name, bold: false)
      colorizer.colorize(text, color_name, bold: bold)
    end

    # Helper: bold text
    def bold(text)
      colorizer.bold(text)
    end

    # Helper: dim text
    def dim(text)
      colorizer.dim(text)
    end

    def yellow(text)
      colorizer.yellow(text)
    end

    # Helper: italic text
    def italic(text)
      return text unless $stdout.tty?

      "#{ANSI::ITALIC}#{text}#{ANSI::RESET}"
    end

    # Helper: state indicator for offense
    def state_indicator
      case state
      when :corrected then colorizer.green('[CORRECTED]')
      when :disabled then colorizer.yellow('[DISABLED]')
      else ''
      end
    end

    # Helper: show the offense line with caret indicator below
    def offense_highlight
      return '' unless file_path && File.exist?(file_path)

      lines = File.readlines(file_path)
      return '' if line > lines.size

      source_line = lines[line - 1].chomp

      # Build caret indicator
      # Cap caret length at 80 to avoid printing hundreds of carets for multi-line offenses
      caret_length = length || 1
      caret_col = column || 1

      if caret_length > 80
        remaining = caret_length - 80
        carets = colorizer.yellow('^' * 80 + " [#{remaining} more characters]")
      else
        carets = colorizer.yellow('^' * caret_length)
      end

      caret_line = ' ' * (caret_col - 1) + carets

      "#{source_line}\n#{caret_line}"
    end

    private

    def build_prompt_options
      options = []

      if correctable && state == :pending
        if safe_autocorrect
          options << '[a]pply'
        else
          options << colorizer.yellow('[A]pply unsafe')
        end
        options << '[p]atch'
        options << '[L] correct all'
      end

      options << '[s]kip'
      options << '[d]isable line' if state == :pending
      options << '[D]isable file' if state == :pending
      options << '[q]uit'
      options << '[?]help'
      options << '[←/→] nav'
      options
    end
  end
end
