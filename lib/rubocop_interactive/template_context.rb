# frozen_string_literal: true

require 'erb'

module RubocopInteractive
  # Provides context and helpers for ERB templates
  class TemplateContext
    attr_accessor :total_offenses, :offense_number, :cop_name, :cop_count, :message,
                  :file_path, :line, :column, :length, :patch_lines, :patch_start_line,
                  :correctable, :safe_autocorrect, :available_actions, :state, :active,
                  :colorizer, :source, :files

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

      renderer = PatchRenderer.new(
        patch_lines: patch_lines,
        patch_start_line: patch_start_line,
        colorizer: colorizer
      )

      renderer.render(
        old_color: old_color,
        new_color: new_color,
        context_color: context_color,
        inline: inline,
        merge: merge,
        show_spaces: show_spaces,
        line_numbers: line_numbers
      )
    end

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

      "#{Color::ITALIC}#{text}#{Color::RESET}"
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
      options << '[e]dit'
      options << '[q]uit'
      options << '[?]help'
      options << '[←/→] nav'
      options
    end
  end
end
