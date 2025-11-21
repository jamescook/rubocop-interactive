# frozen_string_literal: true

require 'diff/lcs'

module RubocopInteractive
  # Renders patch data with various visualization options using Diff::LCS callbacks
  class PatchRenderer
    # Callback handler for character-level diff highlighting
    class CharacterHighlightCallbacks
      attr_reader :old_result, :new_result

      def initialize(colorizer:, old_color:, new_color:)
        @colorizer = colorizer
        @old_color = old_color
        @new_color = new_color
        @old_result = []
        @new_result = []
      end

      def match(event)
        # Unchanged - show in base color
        @old_result << @colorizer.colorize(event.old_element, @old_color)
        @new_result << @colorizer.colorize(event.new_element, @new_color)
      end

      def discard_a(event)
        # Deleted - bold highlight
        @old_result << @colorizer.colorize(event.old_element, @old_color, bold: true)
      end

      def discard_b(event)
        # Added - bold highlight
        @new_result << @colorizer.colorize(event.new_element, @new_color, bold: true)
      end

      def change(event)
        # Changed - bold highlight both
        @old_result << @colorizer.colorize(event.old_element, @old_color, bold: true)
        @new_result << @colorizer.colorize(event.new_element, @new_color, bold: true)
      end
    end

    # Callback handler for merged character-level diffs
    class CharacterMergeCallbacks
      attr_reader :result

      def initialize(colorizer:, old_color:, new_color:, show_spaces: nil)
        @colorizer = colorizer
        @old_color = old_color
        @new_color = new_color
        @show_spaces = show_spaces
        @result = []
      end

      def match(event)
        # Unchanged
        @result << event.old_element
      end

      def discard_a(event)
        # Deleted
        char = @show_spaces && event.old_element == ' ' ? @show_spaces : event.old_element
        @result << @colorizer.colorize(char, @old_color, bold: true)
      end

      def discard_b(event)
        # Added
        char = @show_spaces && event.new_element == ' ' ? @show_spaces : event.new_element
        @result << @colorizer.colorize(char, @new_color, bold: true)
      end

      def change(event)
        # Changed - show old then new
        old_char = @show_spaces && event.old_element == ' ' ? @show_spaces : event.old_element
        new_char = @show_spaces && event.new_element == ' ' ? @show_spaces : event.new_element
        @result << @colorizer.colorize(old_char, @old_color, bold: true)
        @result << @colorizer.colorize(new_char, @new_color, bold: true)
      end
    end

    def initialize(patch_lines:, patch_start_line: 1, colorizer: Color)
      @patch_lines = patch_lines
      @patch_start_line = patch_start_line
      @colorizer = colorizer
    end

    def render(old_color: :red, new_color: :green, context_color: nil, inline: false, merge: false, show_spaces: nil, line_numbers: false)
      return '' unless @patch_lines

      if inline
        render_inline_diff(old_color: old_color, new_color: new_color, context_color: context_color, merge: merge, show_spaces: show_spaces, line_numbers: line_numbers)
      else
        render_line_diff(old_color: old_color, new_color: new_color, context_color: context_color)
      end
    end

    private

    def render_line_diff(old_color:, new_color:, context_color:)
      @patch_lines.map do |patch_line|
        if patch_line.start_with?('-')
          @colorizer.colorize(patch_line, old_color)
        elsif patch_line.start_with?('+')
          @colorizer.colorize(patch_line, new_color)
        elsif context_color
          @colorizer.colorize(patch_line, context_color)
        else
          patch_line
        end
      end.join
    end

    def render_inline_diff(old_color:, new_color:, context_color:, merge: false, show_spaces: nil, line_numbers: false)
      result = []
      i = 0
      current_line = @patch_start_line || 1

      while i < @patch_lines.size
        line = @patch_lines[i]
        line_num_str = line_numbers ? format('%4d ', current_line) : ''

        if line.start_with?('-') && i + 1 < @patch_lines.size && @patch_lines[i + 1].start_with?('+')
          # Pair of old/new lines - do inline diff
          old_line = line[1..].chomp # Remove leading -
          new_line = @patch_lines[i + 1][1..].chomp # Remove leading +

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
          result << "#{line_num_str}#{@colorizer.colorize(line, old_color)}"
          current_line += 1
          i += 1
        elsif line.start_with?('+')
          # Added lines don't increment line number (they're inserted)
          add_line_str = line_numbers ? '     ' : ''
          result << "#{add_line_str}#{@colorizer.colorize(line, new_color)}"
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
        @colorizer.dim(text)
      else
        @colorizer.colorize(text, color)
      end
    end

    def inline_highlight(old_str, new_str, old_color, new_color)
      callbacks = CharacterHighlightCallbacks.new(
        colorizer: @colorizer,
        old_color: old_color,
        new_color: new_color
      )

      Diff::LCS.traverse_sequences(old_str.chars, new_str.chars, callbacks)

      [callbacks.old_result.join, callbacks.new_result.join]
    end

    def inline_merge(old_str, new_str, old_color, new_color, show_spaces: nil)
      callbacks = CharacterMergeCallbacks.new(
        colorizer: @colorizer,
        old_color: old_color,
        new_color: new_color,
        show_spaces: show_spaces
      )

      Diff::LCS.traverse_sequences(old_str.chars, new_str.chars, callbacks)

      callbacks.result.join
    end
  end
end
