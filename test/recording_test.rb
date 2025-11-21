# frozen_string_literal: true

require_relative 'test_helper'

class RecordingTest < Minitest::Test
  def test_recording_input_captures_keypresses
    input = StringIO.new("abc123")
    recorder = RubocopInteractive::RecordingInput.new(input)

    assert_equal 'a', recorder.getch
    assert_equal 'b', recorder.getch
    assert_equal 'c', recorder.getch

    assert_equal ['a', 'b', 'c'], recorder.keypresses
  end

  def test_ui_with_record_keypresses_enabled
    with_temp_fixture do |dir|
      file_path = File.join(dir, 'test.rb')
      File.write(file_path, <<~RUBY)
        def foo
          return 42
        end
      RUBY

      json_data = run_rubocop_on_file(file_path)

      # Use simple keypresses: skip then quit
      input = StringIO.new("sq")
      output = StringIO.new

      ui = RubocopInteractive::UI.new(
        input: input,
        output: output,
        record_keypresses: true,
        colorizer: RubocopInteractive::NoopColorizer
      )

      RubocopInteractive::Session.new(json_data, ui: ui).run

      # Verify keypresses were recorded
      assert ui.recording_input, "Should have recording_input when record_keypresses is true"
      assert_equal ['s', 'q'], ui.recording_input.keypresses
    end
  end

  private

  def run_rubocop_on_file(file_path)
    require 'rubocop'
    require 'stringio'

    output = StringIO.new
    old_stdout = $stdout
    old_stderr = $stderr
    $stdout = output
    $stderr = StringIO.new

    begin
      cli = RuboCop::CLI.new
      cli.run(['--format', 'json', '--cache', 'false', file_path])
    ensure
      $stdout = old_stdout
      $stderr = old_stderr
    end

    JSON.parse(output.string)
  end
end
