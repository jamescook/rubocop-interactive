# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'

class UITest < Minitest::Test

  def setup
    @output = StringIO.new
  end

  def test_prompt_for_action_shows_help_on_question_mark
    offense = create_offense

    # Simulate: press '?', then 's' to skip
    input = StringIO.new("?s")
    ui = RubocopInteractive::UI.new(input: input, output: @output, colorizer: RubocopInteractive::NoopColorizer)

    action = ui.prompt_for_action(offense)

    # Should show help text
    output_text = @output.string
    assert_includes output_text, 'Actions:'
    assert_includes output_text, 'Autocorrect this offense'
    assert_includes output_text, 'Skip this offense'
    assert_includes output_text, 'Disable cop for this line'
    assert_includes output_text, 'Quit'

    # Should eventually return :skip after showing help
    assert_equal :skip, action
  end

  def test_prompt_for_action_returns_show_patch
    offense = create_offense

    input = StringIO.new("p")
    ui = RubocopInteractive::UI.new(input: input, output: @output, colorizer: RubocopInteractive::NoopColorizer)

    action = ui.prompt_for_action(offense)

    assert_equal :show_patch, action
  end

  def test_show_patch_displays_patch_for_correctable_offense
    with_temp_fixture do |dir|
      file_path = File.join(dir, 'bad_code.rb')

      offense_data = {
        'cop_name' => 'Style/StringLiterals',
        'message' => 'Prefer single-quoted strings',
        'severity' => 'convention',
        'correctable' => true,
        'location' => { 'start_line' => 6, 'start_column' => 7, 'length' => 15 }
      }

      offense = RubocopInteractive::Offense.new(file_path: file_path, data: offense_data)
      ui = RubocopInteractive::UI.new(output: @output, colorizer: RubocopInteractive::NoopColorizer)

      ui.show_patch(offense)

      output_text = @output.string

      # Should contain patch elements
      assert_includes output_text, 'double quotes'
      # Should show removed and added lines
      assert_match(/["']double quotes["']/, output_text)
    end
  end

  def test_show_patch_does_nothing_for_non_correctable_offense
    offense_data = {
      'cop_name' => 'Naming/MethodName',
      'message' => 'Use snake_case',
      'severity' => 'convention',
      'correctable' => false,
      'location' => { 'start_line' => 1, 'start_column' => 1, 'length' => 5 }
    }

    offense = RubocopInteractive::Offense.new(
      file_path: 'test.rb',
      data: offense_data
    )

    ui = RubocopInteractive::UI.new(output: @output, colorizer: RubocopInteractive::NoopColorizer)
    ui.show_patch(offense)

    # Should produce no output
    assert_empty @output.string
  end

  def test_prompt_for_action_handles_unknown_input
    offense = create_offense

    # Simulate: press 'x' (unknown), then 's' to skip
    input = StringIO.new("xs")
    ui = RubocopInteractive::UI.new(input: input, output: @output, colorizer: RubocopInteractive::NoopColorizer)

    action = ui.prompt_for_action(offense)

    # Should show error for unknown input
    output_text = @output.string
    assert_includes output_text, 'Unknown'

    # Should eventually return :skip
    assert_equal :skip, action
  end

  def test_prompt_for_action_returns_navigation_actions
    offense = create_offense

    # Test left arrow (prev)
    input = StringIO.new("\e[D")
    ui = RubocopInteractive::UI.new(input: input, output: @output, colorizer: RubocopInteractive::NoopColorizer)
    assert_equal :prev, ui.prompt_for_action(offense)

    # Test right arrow (next)
    @output.truncate(0)
    @output.rewind
    input = StringIO.new("\e[C")
    ui = RubocopInteractive::UI.new(input: input, output: @output, colorizer: RubocopInteractive::NoopColorizer)
    assert_equal :next, ui.prompt_for_action(offense)
  end

  def test_show_unsafe_error_displays_message_and_beeps
    ui = RubocopInteractive::UI.new(output: @output, colorizer: RubocopInteractive::NoopColorizer)
    ui.show_unsafe_error

    output_text = @output.string
    assert_includes output_text, "Press 'A'"
    assert_includes output_text, 'unsafe autocorrect'
  end

  def test_interrupt_requires_double_ctrl_c_to_quit
    offense = create_offense

    # First Ctrl+C - should show warning
    input = StringIO.new("\u0003s")
    ui = RubocopInteractive::UI.new(input: input, output: @output, colorizer: RubocopInteractive::NoopColorizer)

    action = ui.prompt_for_action(offense)

    # Should show warning and return :skip (not quit)
    output_text = @output.string
    assert_includes output_text, 'Press Ctrl+C again'
    assert_equal :skip, action
  end

  def test_double_interrupt_quits
    offense = create_offense

    # Two Ctrl+C in quick succession - should quit
    # Note: The actual double-press timing logic is hard to test in unit tests
    # This tests the code path, but the real-world behavior depends on timing
    input = StringIO.new("\u0003\u0003")
    ui = RubocopInteractive::UI.new(input: input, output: @output, colorizer: RubocopInteractive::NoopColorizer)

    action = ui.prompt_for_action(offense)

    # Should eventually quit (after seeing first interrupt, second triggers quit)
    assert_equal :quit, action
  end

  def test_confirm_correct_all_with_yes
    offense = create_offense

    # Simulate 'y' response
    input = StringIO.new("y")
    ui = RubocopInteractive::UI.new(input: input, output: @output, colorizer: RubocopInteractive::NoopColorizer)

    result = ui.confirm_correct_all(offense)

    assert_equal true, result
    output_text = @output.string
    assert_includes output_text, 'Correct ALL remaining instances'
    assert_includes output_text, offense.cop_name
  end

  def test_confirm_correct_all_with_no
    offense = create_offense

    # Simulate 'n' response
    input = StringIO.new("n")
    ui = RubocopInteractive::UI.new(input: input, output: @output, colorizer: RubocopInteractive::NoopColorizer)

    result = ui.confirm_correct_all(offense)

    assert_equal false, result
  end

  def test_confirm_correct_all_accepts_skip_as_no
    offense = create_offense

    # Simulate 's' response (should be treated as 'no')
    input = StringIO.new("s")
    ui = RubocopInteractive::UI.new(input: input, output: @output, colorizer: RubocopInteractive::NoopColorizer)

    result = ui.confirm_correct_all(offense)

    assert_equal false, result
  end

  def test_confirm_correct_all_shows_error_for_invalid_input
    offense = create_offense

    # Simulate invalid input 'x', then 'n'
    input = StringIO.new("xn")
    ui = RubocopInteractive::UI.new(input: input, output: @output, colorizer: RubocopInteractive::NoopColorizer)

    result = ui.confirm_correct_all(offense)

    assert_equal false, result
    output_text = @output.string
    assert_includes output_text, '(y/n)'
  end

  private

  def create_offense(correctable: true)
    offense_data = {
      'cop_name' => 'Style/StringLiterals',
      'message' => 'Test message',
      'severity' => 'convention',
      'correctable' => correctable,
      'location' => { 'start_line' => 1, 'start_column' => 1, 'length' => 5 }
    }

    RubocopInteractive::Offense.new(
      file_path: 'test.rb',
      data: offense_data
    )
  end
end
