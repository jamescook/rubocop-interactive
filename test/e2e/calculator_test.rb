# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
require 'fileutils'
require 'stringio'
require_relative '../../lib/rubocop_interactive'

# Custom IO that reads TUI output and decides what key to press
class SmartTestInput
  def initialize(strategy: :safe_autocorrect)
    @strategy = strategy
    @buffer = []
    @output_buffer = ""
  end

  def set_output(output_io)
    @output_io = output_io
  end

  def getch
    return @buffer.shift unless @buffer.empty?

    # Read new output since last check
    new_output = @output_io.string[@output_buffer.length..]
    @output_buffer = @output_io.string.dup

    # Find and parse JSON lines from test template
    new_output.each_line do |line|
      line = line.strip
      next if line.empty? || !line.start_with?('{')

      data = JSON.parse(line)
      next unless data['offense_number'] # Skip non-offense JSON

      key = case @strategy
            when :safe_autocorrect
              (data['correctable'] && data['safe']) ? 'a' : 's'
            when :unsafe_autocorrect
              data['correctable'] ? (data['safe'] ? 'a' : 'A') : 's'
            when :skip_all
              's'
            end

      return key
    end

    raise "SmartTestInput: No offense JSON found in output. Buffer length: #{@output_buffer.length}, new output: #{new_output.inspect[0..200]}"
  end
end

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

    # 3. Run with SmartTestInput that reads output to decide actions
    output = StringIO.new
    input = SmartTestInput.new(strategy: :safe_autocorrect)
    input.set_output(output)

    ui = RubocopInteractive::UI.new(
      input: input,
      output: output,
      confirm_patch: false,
      template: 'test',
      colorizer: RubocopInteractive::NoopColorizer
    )

    stats = RubocopInteractive.start!(json.to_json, ui: ui)

    # 4. Verify stats
    assert stats[:corrected] > 0, "Should have made some corrections"

    # 5. Verify calculator still works after corrections
    assert run_calculator, "Calculator should work after corrections"

    # 6. Verify fewer offenses remain
    new_json = run_rubocop_json
    new_offenses = new_json['files'][0]['offenses']
    new_total = new_offenses.size

    # Should have significantly fewer offenses
    assert new_total < total, "Should have fewer offenses after corrections"

    # Most correctable offenses should be fixed
    remaining_correctable = new_offenses.count { |o| o['correctable'] }
    assert remaining_correctable < correctable / 2,
           "At least half of correctable offenses should be fixed, #{remaining_correctable} of #{correctable} remaining"
  end

  def test_navigation_and_mixed_actions
    # Test that we can navigate and perform different actions
    json = run_rubocop_json

    # Navigate forward 3, back 2, then process remaining
    # This tests that navigation doesn't break the flow
    output = StringIO.new
    input = SmartTestInput.new(strategy: :safe_autocorrect)
    input.set_output(output)

    # Pre-buffer navigation keys: right 3, left 2
    3.times { input.instance_variable_get(:@buffer) << "\e" << "[" << "C" }
    2.times { input.instance_variable_get(:@buffer) << "\e" << "[" << "D" }

    ui = RubocopInteractive::UI.new(
      input: input,
      output: output,
      confirm_patch: false,
      template: 'test',
      colorizer: RubocopInteractive::NoopColorizer
    )

    stats = RubocopInteractive.start!(json.to_json, ui: ui)

    # We skipped offense 0, so should have made some corrections
    assert stats[:corrected] > 0, "Should have made corrections"

    # Calculator should still work
    assert run_calculator, "Calculator should work after partial corrections"
  end

  def test_autocorrect_all
    json = run_rubocop_json

    # Use unsafe_autocorrect strategy to fix everything possible
    output = StringIO.new
    input = SmartTestInput.new(strategy: :unsafe_autocorrect)
    input.set_output(output)

    ui = RubocopInteractive::UI.new(
      input: input,
      output: output,
      confirm_patch: false,
      template: 'test',
      colorizer: RubocopInteractive::NoopColorizer
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

    # Use a custom input that disables the first non-correctable offense
    output = StringIO.new
    input = SmartTestInput.new(strategy: :safe_autocorrect)
    input.set_output(output)

    # Override getch to disable first non-correctable, then quit
    disabled_one = false
    input.define_singleton_method(:getch) do
      return @buffer.shift unless @buffer.empty?

      new_output = @output_io.string[@output_buffer.length..]
      @output_buffer = @output_io.string.dup

      new_output.each_line do |line|
        line = line.strip
        next if line.empty? || !line.start_with?('{')

        data = JSON.parse(line)
        next unless data['offense_number']

        if !data['correctable'] && !disabled_one
          disabled_one = true
          @buffer << 'q'  # Quit after disabling
          return 'd'      # Disable this one
        elsif data['correctable'] && data['safe']
          return 'a'
        else
          return 's'
        end
      end

      raise "SmartTestInput: No offense JSON found"
    end

    ui = RubocopInteractive::UI.new(
      input: input,
      output: output,
      confirm_patch: false,
      template: 'test',
      colorizer: RubocopInteractive::NoopColorizer
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

    # Process first 3 offenses then quit - use simple StringIO with known keys
    # First 3 offenses: check what they are and send appropriate keys
    offenses = json['files'][0]['offenses']
    input_keys = offenses[0..2].map do |o|
      (o['correctable'] && o.fetch('safe_autocorrect', true)) ? 'a' : 's'
    end
    input_keys << 'q'

    input = StringIO.new(input_keys.join)
    output = StringIO.new

    ui = RubocopInteractive::UI.new(
      input: input,
      output: output,
      confirm_patch: false,
      summary_on_exit: true
      # Use default template to test output format
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
