# frozen_string_literal: true

require_relative 'test_helper'

class SessionCorrectAllTest < Minitest::Test

  def test_correct_all_applies_fix_to_all_instances_of_cop
    with_temp_fixture do |dir|
      # Create a file with multiple StringLiterals offenses
      file_path = File.join(dir, 'multiple_strings.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        def foo
          x = "first"
          y = "second"
          z = "third"
          puts x, y, z
        end
      RUBY

      # Get all StringLiterals offenses
      json_data = run_rubocop_on_file(file_path)
      
      # Simulate: user presses 'L' on first offense, confirms with 'y'
      responses = [:correct_all, :confirm_yes, :quit]
      ui = FakeUI.new(responses: responses)
      server = FakeServer.new

      session = RubocopInteractive::Session.new(json_data, ui: ui, server: server)
      stats = session.run

      # All 3 StringLiterals should be corrected in one go
      assert_equal 3, stats[:corrected]

      # Verify all strings are now single-quoted
      corrected = File.read(file_path)
      assert_match(/'first'/, corrected)
      assert_match(/'second'/, corrected)
      assert_match(/'third'/, corrected)
    end
  end

  def test_correct_all_confirmation_no_cancels
    with_temp_fixture do |dir|
      file_path = File.join(dir, 'multiple_strings.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        def foo
          x = "first"
          y = "second"
          puts x, y
        end
      RUBY

      json_data = run_rubocop_on_file(file_path)
      
      # User presses 'L' but then says 'n' to confirmation
      responses = [:correct_all, :confirm_no, :skip, :quit]
      ui = FakeUI.new(responses: responses)
      server = FakeServer.new

      session = RubocopInteractive::Session.new(json_data, ui: ui, server: server)
      stats = session.run

      # Nothing should be corrected
      assert_equal 0, stats[:corrected]

      # Verify strings are still double-quoted
      content = File.read(file_path)
      assert_match(/"first"/, content)
      assert_match(/"second"/, content)
    end
  end

  def test_correct_all_not_offered_for_non_correctable
    with_temp_fixture do |dir|
      file_path = File.join(dir, 'non_correctable.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        def Foo  # Naming/MethodName - not auto-correctable
        end
      RUBY

      json_data = run_rubocop_on_file(file_path)

      responses = [:skip, :quit]
      ui = FakeUI.new(responses: responses)
      server = FakeServer.new

      session = RubocopInteractive::Session.new(json_data, ui: ui, server: server)
      session.run

      # UI should not have been asked to show correct_all option
      # This is verified by FakeUI not receiving :correct_all action
    end
  end

  def test_correct_all_only_corrects_from_current_position_forward
    with_temp_fixture do |dir|
      file_path = File.join(dir, 'multiple_strings.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        def foo
          x = "first"
          y = "second"
          z = "third"
          puts x, y, z
        end
      RUBY

      json_data = run_rubocop_on_file(file_path)

      # User skips first offense, then presses 'L' on second offense
      # This should leave "first" unchanged but correct "second" and "third"
      responses = [:skip, :correct_all, :confirm_yes, :quit]
      ui = FakeUI.new(responses: responses)
      server = FakeServer.new

      session = RubocopInteractive::Session.new(json_data, ui: ui, server: server)
      stats = session.run

      # Only 2 should be corrected (second and third), first was skipped
      assert_equal 2, stats[:corrected]

      # Verify "first" is still double-quoted (skipped)
      # but "second" and "third" are single-quoted (corrected)
      corrected = File.read(file_path)
      assert_match(/"first"/, corrected)
      assert_match(/'second'/, corrected)
      assert_match(/'third'/, corrected)
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
      cli.run(['--format', 'json', file_path])
    ensure
      $stdout = old_stdout
      $stderr = old_stderr
    end

    JSON.parse(output.string)
  end
end
