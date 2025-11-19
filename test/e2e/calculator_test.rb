# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
require 'fileutils'
require 'stringio'
require_relative '../../lib/rubocop_interactive'

class CalculatorE2ETest < Minitest::Test
  FIXTURE_PATH = File.expand_path('fixtures/calculator.rb', __dir__)
  WORK_DIR = File.expand_path('../../tmp/e2e_work', __dir__)

  def setup
    # Create a working copy so we don't modify the fixture
    FileUtils.mkdir_p(WORK_DIR)
    @work_file = File.join(WORK_DIR, 'calculator.rb')
    FileUtils.cp(FIXTURE_PATH, @work_file)
  end

  def teardown
    FileUtils.rm_rf(WORK_DIR)
  end

  def test_calculator_works_before_corrections
    # Sanity check - calculator should work with bad style
    result = run_calculator
    assert result, "Calculator should pass all tests before corrections"
  end

  def test_full_interactive_session
    # 1. Verify calculator works before
    assert run_calculator, "Calculator should work before corrections"

    # 2. Get offense count and breakdown
    json = run_rubocop_json
    offenses = json['files'][0]['offenses']
    total = offenses.size
    correctable = offenses.count { |o| o['correctable'] }
    non_correctable = total - correctable

    assert total > 20, "Expected many offenses, got #{total}"
    assert correctable > 10, "Expected many correctable offenses"
    assert non_correctable > 5, "Expected some non-correctable offenses"

    # 3. Build input sequence: 'A' for correctable (works for safe and unsafe), 's' for non-correctable
    # We need to match the order rubocop reports them
    input_sequence = offenses.map { |o| o['correctable'] ? 'A' : 's' }.join

    # 4. Run rubocop-interactive with simulated input
    input = StringIO.new(input_sequence)
    output = StringIO.new

    ui = RubocopInteractive::UI.new(
      input: input,
      output: output,
      confirm_patch: false
    )

    stats = RubocopInteractive.start!(json.to_json, ui: ui)

    # 5. Verify stats - some corrections may fix multiple offenses at once
    # so stats[:corrected] counts 'a' presses, not total offenses fixed
    assert stats[:corrected] > 0, "Should have made some corrections"
    assert stats[:corrected] <= correctable, "Can't correct more than available"

    # 6. Verify calculator still works after corrections
    assert run_calculator, "Calculator should work after corrections"

    # 7. Verify fewer offenses remain
    new_json = run_rubocop_json
    new_offenses = new_json['files'][0]['offenses']
    new_total = new_offenses.size

    # Should have significantly fewer offenses
    assert new_total < total, "Should have fewer offenses after corrections"

    # Most correctable offenses should be fixed
    # Note: Some may remain due to line number shifts after earlier corrections
    # (e.g., adding frozen_string_literal shifts all subsequent lines)
    # Users can run the tool multiple times to catch these
    remaining_correctable = new_offenses.count { |o| o['correctable'] }
    assert remaining_correctable < correctable / 2,
           "At least half of correctable offenses should be fixed, #{remaining_correctable} of #{correctable} remaining"
  end

  def test_navigation_and_mixed_actions
    # Test that we can navigate and perform different actions
    json = run_rubocop_json
    offenses = json['files'][0]['offenses']
    total = offenses.size

    # Navigate forward 3, back 2, then process remaining
    # This tests that navigation doesn't break the flow
    input_keys = []

    # Arrow right 3 times (skip first 3 without acting)
    3.times { input_keys << "\e[C" }  # Right arrow

    # Arrow left 2 times (go back)
    2.times { input_keys << "\e[D" }  # Left arrow

    # Now we're on offense 2 (0-indexed: 1)
    # Process remaining offenses with 'A' or 's'
    # We need to handle offense 1 through end
    (1...total).each do |i|
      input_keys << (offenses[i]['correctable'] ? 'A' : 's')
    end

    input = StringIO.new(input_keys.join)
    output = StringIO.new

    ui = RubocopInteractive::UI.new(
      input: input,
      output: output,
      confirm_patch: false
    )

    stats = RubocopInteractive.start!(json.to_json, ui: ui)

    # We skipped offense 0, so should have made some corrections
    # (exact count varies due to multi-offense fixes)
    assert stats[:corrected] > 0, "Should have made corrections"

    # Calculator should still work
    assert run_calculator, "Calculator should work after partial corrections"
  end

  def test_autocorrect_all
    json = run_rubocop_json
    offenses = json['files'][0]['offenses']
    initial_count = offenses.size

    # Press 'A' for every offense - this will autocorrect correctable ones
    # (both safe and unsafe) and skip non-correctable ones
    # Use way more than needed to ensure we don't run out
    input_keys = 'A' * (initial_count * 2)

    input = StringIO.new(input_keys)
    output = StringIO.new

    ui = RubocopInteractive::UI.new(
      input: input,
      output: output,
      confirm_patch: false
    )

    stats = RubocopInteractive.start!(json.to_json, ui: ui)

    # Should have made corrections
    assert stats[:corrected] > 0, "Should have corrected at least 1 offense"

    # Calculator should still work
    assert run_calculator, "Calculator should work after autocorrecting all"

    # Should have no correctable offenses remaining
    new_json = run_rubocop_json
    new_offenses = new_json['files'][0]['offenses']
    remaining_correctable = new_offenses.count { |o| o['correctable'] }
    assert_equal 0, remaining_correctable, "No correctable offenses should remain"
  end

  def test_disable_line_action
    json = run_rubocop_json
    offenses = json['files'][0]['offenses']

    # Find first non-correctable offense and disable it
    first_non_correctable_idx = offenses.index { |o| !o['correctable'] }
    assert first_non_correctable_idx, "Should have non-correctable offenses"

    # Skip to the non-correctable, disable it, then quit
    input_keys = []
    (0...first_non_correctable_idx).each do |i|
      input_keys << (offenses[i]['correctable'] ? 'A' : 's')
    end
    input_keys << 'd'  # Disable line
    input_keys << 'q'  # Quit

    input = StringIO.new(input_keys.join)
    output = StringIO.new

    ui = RubocopInteractive::UI.new(
      input: input,
      output: output,
      confirm_patch: false
    )

    stats = RubocopInteractive.start!(json.to_json, ui: ui)

    assert_equal 1, stats[:disabled], "Should have disabled 1 offense"

    # Calculator should still work
    assert run_calculator, "Calculator should work after disabling"

    # Verify the disable comment was added
    content = File.read(@work_file)
    assert_match(/rubocop:disable/, content, "Should have rubocop:disable comment")
  end

  def test_output_contains_expected_elements
    json = run_rubocop_json
    offenses = json['files'][0]['offenses']

    # Just process first 3 offenses
    input_keys = offenses[0..2].map { |o| o['correctable'] ? 'a' : 's' }
    input_keys << 'q'

    input = StringIO.new(input_keys.join)
    output = StringIO.new

    ui = RubocopInteractive::UI.new(
      input: input,
      output: output,
      confirm_patch: false
    )

    RubocopInteractive.start!(json.to_json, ui: ui)

    output_str = output.string

    # Verify output contains expected elements
    assert_match(/Found \d+ offense/, output_str, "Should show offense count")
    assert_match(/\[\d+\/\d+\]/, output_str, "Should show progress indicator")
    assert_match(/Summary:/, output_str, "Should show summary")
    assert_match(/Corrected:/, output_str, "Should show corrected count")
  end

  private

  def run_calculator
    system("ruby #{@work_file} > /dev/null 2>&1")
  end

  def run_rubocop_json
    json_output = `rubocop #{@work_file} --format json 2>/dev/null`
    JSON.parse(json_output)
  end
end
