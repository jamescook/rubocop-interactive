# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
require 'fileutils'
require 'stringio'
require_relative '../../lib/rubocop_interactive'

# E2E Test Maintenance Guide:
# These tests depend on the exact offense sequence in fixtures/comprehensive.rb.
#
# To regenerate keypresses after modifying the fixture:
#
# 1. Run interactively with recording enabled:
#      bin/rubocop-interactive --record test/e2e/fixtures/comprehensive.rb
#
# 2. Manually perform the desired actions (autocorrect, skip, disable, etc.)
#
# 3. Review the generated keystroke_record_TIMESTAMP.log file
#
# 4. Update the test's keypresses string and expected stats
#
# Note: The --record flag is undocumented and only for test development.
# It captures all keypresses and saves them to a timestamped log file.

# Debug wrapper to track consumed input
class DebugInput
  attr_reader :consumed

  def initialize(io)
    @io = io
    @consumed = []
  end

  def getch
    char = @io.getch
    @consumed << char if char
    $stderr.puts "DEBUG: Read char: #{char.inspect}" if ENV['DEBUG_INPUT']
    char
  end
end

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
  FIXTURE_PATH = File.expand_path('fixtures/comprehensive.rb', __dir__)
  WORK_DIR = File.expand_path('../../tmp/e2e_work', __dir__)

  def setup
    # Create a working copy so we don't modify the fixture
    FileUtils.mkdir_p(WORK_DIR)
    @work_file = File.join(WORK_DIR, 'comprehensive.rb')
    FileUtils.cp(FIXTURE_PATH, @work_file)

    # Backup the original fixture in case test modifies it
    @fixture_backup = FIXTURE_PATH + '.backup'
    FileUtils.cp(FIXTURE_PATH, @fixture_backup)
  end

  def teardown
    # Restore fixture from backup
    if File.exist?(@fixture_backup)
      FileUtils.mv(@fixture_backup, FIXTURE_PATH)
    end

    FileUtils.rm_rf(WORK_DIR)
  end

  def test_comprehensive_all_keystrokes
    json = run_rubocop_json
    offenses = json['files'][0]['offenses']

    assert_equal 14, offenses.size, "Expected exactly 14 offenses in comprehensive.rb"

    # Test ALL keystrokes based on manual session:
    # 'a' - autocorrect EmptyLineAfterMagicComment [rescan: 14→13]
    # 'p' - try patch on MethodParameterName (not correctable, re-prompts)
    # 'd' - disable MethodParameterName [rescan: 13→11]
    # 'p' - show patch for RedundantReturn
    # 'a' - autocorrect RedundantReturn [rescan: 11→10]
    # 'p' - show patch for ExtraSpacing
    # 'a' - autocorrect ExtraSpacing [rescan: 10→9]
    # 'p' - show patch for IfUnlessModifier
    # 'a' - autocorrect IfUnlessModifier [rescan: 9→7]
    # 'd' - disable EmptyLineAfterGuardClause [rescan: 7→6]
    # 'A' - unsafe autocorrect NumericPredicate [rescan: 6→5]
    # 'p' - try patch on MethodName (not correctable, re-prompts)
    # 's' - skip MethodName
    # 'p' - show patch for ExtraSpacing
    # 'a' - autocorrect ExtraSpacing [rescan: 5→4]
    # 'p' - show patch for CommentedKeyword
    # 'A' - unsafe autocorrect CommentedKeyword [rescan: 4→4]
    # 's' - skip MethodName
    # 'p' - show patch for StringLiterals
    # 'L' 'y' - correct ALL StringLiterals [rescan: 4→2]
    # 's' - skip final MethodName [exit at last offense]
    #
    # Expected: 5 corrections, 3 disabled
    # (Some keypress mismatches due to unsafe offenses requiring 'A' instead of 'a')
    keypresses = "apdpapapadadApspaApspLysq"

    input = StringIO.new(keypresses)
    output = StringIO.new

    # Debug wrapper to show what's being read
    input_debug = DebugInput.new(input)

    ui = RubocopInteractive::UI.new(
      input: input_debug,
      output: output,
      confirm_patch: false,
      template: 'test',
      colorizer: RubocopInteractive::NoopColorizer
    )

    # Run with timeout
    stats = nil
    thread = Thread.new do
      stats = RubocopInteractive.start!(json.to_json, ui: ui)
    end

    unless thread.join(10) # 10 second timeout
      thread.kill
      puts "\n=== TIMEOUT DEBUG ==="
      puts "Keypresses consumed: #{input_debug.consumed.inspect}"
      puts "Last 500 chars of output:"
      puts output.string[-500..-1]
      flunk "Test timed out after 10 seconds. Consumed #{input_debug.consumed.size} keypresses."
    end

    # Verify exact counts
    assert_equal 5, stats[:corrected], "Should have corrected exactly 5 offenses"
    assert_equal 3, stats[:disabled], "Should have disabled exactly 3 offenses"

    # Verify file still has valid syntax
    assert run_sample, "File should still have valid syntax after corrections"
  end

  private

  def run_sample
    system("ruby -c #{@work_file} > /dev/null 2>&1")
  end

  def run_rubocop_json
    json_string = RubocopInteractive.run_rubocop_on_files([@work_file])
    JSON.parse(json_string)
  end
end
