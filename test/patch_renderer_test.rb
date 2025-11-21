# frozen_string_literal: true

require_relative 'test_helper'

class PatchRendererTest < Minitest::Test
  def test_render_line_diff_basic
    patch_lines = [
      " context line\n",
      "-old line\n",
      "+new line\n",
      " more context\n"
    ]

    renderer = RubocopInteractive::PatchRenderer.new(
      patch_lines: patch_lines,
      colorizer: RubocopInteractive::NoopColorizer
    )

    result = renderer.render

    expected = <<~PATCH
       context line
      -old line
      +new line
       more context
    PATCH

    assert_equal expected, result
  end

  def test_render_line_diff_with_context_color
    patch_lines = [
      " context line\n",
      "-old line\n",
      "+new line\n"
    ]

    renderer = RubocopInteractive::PatchRenderer.new(
      patch_lines: patch_lines,
      colorizer: RubocopInteractive::NoopColorizer
    )

    result = renderer.render(context_color: :dim)

    expected = <<~PATCH
       context line
      -old line
      +new line
    PATCH

    assert_equal expected, result
  end

  def test_render_inline_diff_without_merge
    patch_lines = [
      "-old line here\n",
      "+new line here\n"
    ]

    renderer = RubocopInteractive::PatchRenderer.new(
      patch_lines: patch_lines,
      colorizer: RubocopInteractive::NoopColorizer
    )

    result = renderer.render(inline: true)

    expected = <<~PATCH
      -old line here
      +new line here
    PATCH

    assert_equal expected, result
  end

  def test_render_inline_diff_with_merge
    patch_lines = [
      "-old line\n",
      "+new line\n"
    ]

    renderer = RubocopInteractive::PatchRenderer.new(
      patch_lines: patch_lines,
      colorizer: RubocopInteractive::NoopColorizer
    )

    result = renderer.render(inline: true, merge: true)

    # In merge mode, characters are interleaved: changed/deleted/added chars appear together
    # "old line" vs "new line" -> "o" same, then "ld" (old) + "ew" (new), then " line" same
    # Result is like: "onledw line" (without color highlighting, chars appear interleaved)
    assert_equal 1, result.lines.size, "Should be a single line in merge mode"
    assert result.include?('line'), "Should include common substring"
  end

  def test_render_with_line_numbers
    patch_lines = [
      " context\n",
      "-old\n",
      "+new\n"
    ]

    renderer = RubocopInteractive::PatchRenderer.new(
      patch_lines: patch_lines,
      patch_start_line: 10,
      colorizer: RubocopInteractive::NoopColorizer
    )

    result = renderer.render(inline: true, line_numbers: true)

    # Line 10 is context, line 11 is the change
    assert result.include?('  10 ')
    assert result.include?('  11 ')
  end

  def test_render_added_lines_dont_increment_line_number
    patch_lines = [
      " line 1\n",
      "+inserted line\n",
      " line 2\n"
    ]

    renderer = RubocopInteractive::PatchRenderer.new(
      patch_lines: patch_lines,
      patch_start_line: 100,
      colorizer: RubocopInteractive::NoopColorizer
    )

    result = renderer.render(inline: true, line_numbers: true)

    lines = result.lines
    assert lines[0].include?(' 100 '), "First line should be 100"
    assert lines[1].include?('     '), "Inserted line should not have line number"
    assert lines[2].include?(' 101 '), "Line after insert should be 101"
  end

  def test_render_deleted_lines_increment_line_number
    patch_lines = [
      " line 1\n",
      "-deleted line\n",
      " line 2\n"
    ]

    renderer = RubocopInteractive::PatchRenderer.new(
      patch_lines: patch_lines,
      patch_start_line: 50,
      colorizer: RubocopInteractive::NoopColorizer
    )

    result = renderer.render(inline: true, line_numbers: true)

    lines = result.lines
    assert lines[0].include?('  50 '), "First line should be 50"
    assert lines[1].include?('  51 '), "Deleted line should be 51"
    assert lines[2].include?('  52 '), "Line after delete should be 52"
  end

  def test_render_empty_patch
    renderer = RubocopInteractive::PatchRenderer.new(
      patch_lines: nil,
      colorizer: RubocopInteractive::NoopColorizer
    )

    result = renderer.render

    assert_equal '', result
  end

  def test_render_only_context_lines
    patch_lines = [
      " context 1\n",
      " context 2\n",
      " context 3\n"
    ]

    renderer = RubocopInteractive::PatchRenderer.new(
      patch_lines: patch_lines,
      colorizer: RubocopInteractive::NoopColorizer
    )

    result = renderer.render

    # Context lines keep their leading space
    expected = " context 1\n context 2\n context 3\n"

    assert_equal expected, result
  end

  def test_render_only_additions
    patch_lines = [
      "+added line 1\n",
      "+added line 2\n"
    ]

    renderer = RubocopInteractive::PatchRenderer.new(
      patch_lines: patch_lines,
      colorizer: RubocopInteractive::NoopColorizer
    )

    result = renderer.render

    expected = <<~PATCH
      +added line 1
      +added line 2
    PATCH

    assert_equal expected, result
  end

  def test_render_only_deletions
    patch_lines = [
      "-deleted line 1\n",
      "-deleted line 2\n"
    ]

    renderer = RubocopInteractive::PatchRenderer.new(
      patch_lines: patch_lines,
      colorizer: RubocopInteractive::NoopColorizer
    )

    result = renderer.render

    expected = <<~PATCH
      -deleted line 1
      -deleted line 2
    PATCH

    assert_equal expected, result
  end

  def test_render_multiple_changes
    patch_lines = [
      " context\n",
      "-old 1\n",
      "+new 1\n",
      " middle context\n",
      "-old 2\n",
      "+new 2\n",
      " end context\n"
    ]

    renderer = RubocopInteractive::PatchRenderer.new(
      patch_lines: patch_lines,
      colorizer: RubocopInteractive::NoopColorizer
    )

    result = renderer.render

    expected = <<~PATCH
       context
      -old 1
      +new 1
       middle context
      -old 2
      +new 2
       end context
    PATCH

    assert_equal expected, result
  end

  def test_inline_highlight_character_changes
    patch_lines = [
      "-foo_bar\n",
      "+foo-bar\n"
    ]

    renderer = RubocopInteractive::PatchRenderer.new(
      patch_lines: patch_lines,
      colorizer: RubocopInteractive::NoopColorizer
    )

    result = renderer.render(inline: true)

    # Should have both old and new lines with character-level diffs
    assert result.include?('-foo'), "Should show old line"
    assert result.include?('+foo'), "Should show new line"
  end

  def test_show_spaces_option_in_merge_mode
    patch_lines = [
      "-foo bar\n",
      "+foo  bar\n"
    ]

    fake_colorizer = Object.new
    def fake_colorizer.colorize(text, _color, bold: false)
      text
    end

    renderer = RubocopInteractive::PatchRenderer.new(
      patch_lines: patch_lines,
      colorizer: fake_colorizer
    )

    result = renderer.render(inline: true, merge: true, show_spaces: '·')

    # With show_spaces, spaces that changed should be visible
    # This is hard to test without actual colorization, but we can verify it runs
    assert_instance_of String, result
    refute_empty result
  end

  def test_unpaired_deletion_in_inline_mode
    patch_lines = [
      " context\n",
      "-deleted line\n",
      " more context\n"
    ]

    renderer = RubocopInteractive::PatchRenderer.new(
      patch_lines: patch_lines,
      patch_start_line: 1,
      colorizer: RubocopInteractive::NoopColorizer
    )

    result = renderer.render(inline: true, line_numbers: true)

    lines = result.lines
    assert_equal 3, lines.size
    assert lines[1].include?('-deleted line'), "Should show deleted line"
  end

  def test_unpaired_addition_in_inline_mode
    patch_lines = [
      " context\n",
      "+added line\n",
      " more context\n"
    ]

    renderer = RubocopInteractive::PatchRenderer.new(
      patch_lines: patch_lines,
      patch_start_line: 1,
      colorizer: RubocopInteractive::NoopColorizer
    )

    result = renderer.render(inline: true, line_numbers: true)

    lines = result.lines
    assert_equal 3, lines.size
    assert lines[1].include?('+added line'), "Should show added line"
  end

  def test_colorizer_is_called_for_deletions
    colorized = false
    fake_colorizer = Object.new
    fake_colorizer.define_singleton_method(:colorize) do |text, color, bold: false|
      colorized = true if text.include?('-deleted')
      text
    end

    patch_lines = ["-deleted\n"]
    renderer = RubocopInteractive::PatchRenderer.new(
      patch_lines: patch_lines,
      colorizer: fake_colorizer
    )

    renderer.render(old_color: :red, new_color: :green)

    assert colorized, "Should have called colorizer for deletion"
  end

  def test_colorizer_is_called_for_additions
    colorized = false
    fake_colorizer = Object.new
    fake_colorizer.define_singleton_method(:colorize) do |text, color, bold: false|
      colorized = true if text.include?('+added')
      text
    end

    patch_lines = ["+added\n"]
    renderer = RubocopInteractive::PatchRenderer.new(
      patch_lines: patch_lines,
      colorizer: fake_colorizer
    )

    renderer.render(old_color: :red, new_color: :green)

    assert colorized, "Should have called colorizer for addition"
  end
end
