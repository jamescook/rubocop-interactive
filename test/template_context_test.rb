# frozen_string_literal: true

require_relative 'test_helper'

class TemplateContextTest < Minitest::Test
  def setup
    @context = RubocopInteractive::TemplateContext.new(
      total_offenses: 17,
      offense_number: 1,
      cop_name: 'Style/StringLiterals',
      message: 'Prefer single-quoted strings',
      file_path: 'bad_code.rb',
      line: 6,
      column: 7,
      correctable: true,
      state: :pending,
      colorizer: RubocopInteractive::NoopColorizer,
      patch_lines: [
        " def hello_world\n",
        "-  x = \"double quotes\"\n",
        "+  x = 'double quotes'\n",
        "   y = 1+2\n"
      ]
    )
  end

  def test_location_helper
    assert_equal 'bad_code.rb:6:7', @context.location
  end

  def test_separator_helper
    assert_equal '----------', @context.separator(width: 10)
    assert_equal '=====', @context.separator(char: '=', width: 5)
  end

  def test_patch_helper_returns_colored_output
    output = @context.patch(old_color: :red, new_color: :green)

    # Should contain the patch lines
    assert_includes output, 'def hello_world'
    assert_includes output, 'double quotes'
  end

  def test_patch_helper_with_no_patch_lines
    @context.patch_lines = nil
    assert_equal '', @context.patch
  end

  def test_prompt_helper_for_correctable
    @context.correctable = true
    @context.safe_autocorrect = true
    prompt = @context.prompt

    assert_includes prompt, '[a]pply'
    assert_includes prompt, '[s]kip'
    assert_includes prompt, '[q]uit'
  end

  def test_state_indicator_pending
    @context.state = :pending
    assert_equal '', @context.state_indicator
  end

  def test_state_indicator_corrected
    @context.state = :corrected
    assert_includes @context.state_indicator, '[CORRECTED]'
  end

  def test_state_indicator_disabled
    @context.state = :disabled
    assert_includes @context.state_indicator, '[DISABLED]'
  end

  def test_patch_inline_merge
    @context.patch_lines = ["-  foo = 1\n", "+  bar = 1\n"]
    @context.patch_start_line = 5

    result = @context.patch(old_color: :red, new_color: :green, inline: true, merge: true)

    # Should merge into single line - characters are interleaved at change points
    # foo -> bar means f->b, o->a, o->r, so output is "fboaor"
    assert_includes result, 'f'
    assert_includes result, 'b'
    assert_includes result, ' = 1'  # unchanged part
  end

  def test_patch_inline_merge_with_show_spaces
    @context.patch_lines = ["-[1,2]\n", "+[1, 2]\n"]
    @context.patch_start_line = 1

    result = @context.patch(old_color: :red, new_color: :green, inline: true, merge: true, show_spaces: '█')

    # Added space should be shown as block
    assert_includes result, '█'
  end

  def test_patch_with_line_numbers
    @context.patch_lines = [" context\n", "-old\n", "+new\n"]
    @context.patch_start_line = 10

    result = @context.patch(old_color: :red, new_color: :green, inline: true, merge: true, line_numbers: true)

    # Should contain line numbers
    assert_includes result, '10'
    assert_includes result, '11'
  end

  def test_patch_context_color_dim
    @context.patch_lines = [" context line\n", "-changed\n", "+new\n"]
    @context.patch_start_line = 1

    result = @context.patch(old_color: :red, new_color: :green, context_color: :dim, inline: true, merge: true)

    # Context line should be present
    assert_includes result, 'context line'
  end

  def test_inline_merge_deletion_only
    @context.patch_lines = ["-  array = [1,2,3]\n", "+  [1,2,3]\n"]
    @context.patch_start_line = 1

    result = @context.patch(old_color: :red, new_color: :green, inline: true, merge: true)

    # Should show both deleted "array = " and kept "[1,2,3]"
    assert_includes result, 'array'
    assert_includes result, '[1,2,3]'
  end

  def test_offense_highlight_truncates_long_carets
    # Create a temp file for testing
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'long_method.rb')
      File.write(file_path, <<~RUBY)
        def very_long_method
          # Method body spans many lines
        end
      RUBY

      # Create context with a very long length (like a multi-line method offense)
      context = RubocopInteractive::TemplateContext.new(
        file_path: file_path,
        line: 1,
        column: 1,
        length: 1200,  # Very long offense
        colorizer: RubocopInteractive::NoopColorizer
      )

      highlight = context.offense_highlight

      # Should contain carets but truncated
      assert_includes highlight, '^' * 80
      assert_includes highlight, '[1120 more characters]'
      refute_includes highlight, '^' * 100  # Should not have more than 80 carets
    end
  end

  def test_offense_highlight_short_carets_not_truncated
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'short.rb')
      File.write(file_path, "x = 1\n")

      context = RubocopInteractive::TemplateContext.new(
        file_path: file_path,
        line: 1,
        column: 1,
        length: 5,  # Short offense
        colorizer: RubocopInteractive::NoopColorizer
      )

      highlight = context.offense_highlight

      # Should have exactly 5 carets, no truncation message
      assert_includes highlight, '^^^^^'
      refute_includes highlight, 'more characters'
    end
  end
end
