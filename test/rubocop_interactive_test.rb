# frozen_string_literal: true

require_relative 'test_helper'

class RubocopInteractiveTest < Minitest::Test
  def test_start_with_stdin
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        def foo
          x = "double quotes"
        end
      RUBY

      # Generate JSON that would come from rubocop
      json = generate_rubocop_json(file_path)

      # Mock stdin with the JSON
      stdin_io = StringIO.new(json)

      # Use FakeUI to skip all offenses
      ui = FakeUI.new(responses: [:skip])

      stats = RubocopInteractive.start!(
        stdin_io,
        ui: ui,
        confirm_patch: false,
        template: 'default',
        summary_on_exit: false
      )

      assert_kind_of Hash, stats
      assert stats.key?(:corrected)
      assert stats.key?(:disabled)
    end
  end

  def test_start_with_files
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        def foo
          x = "double quotes"
        end
      RUBY

      # Use FakeUI to skip all offenses
      ui = FakeUI.new(responses: [:skip])

      stats = RubocopInteractive.start!(
        [file_path],
        ui: ui,
        confirm_patch: false,
        template: 'default',
        summary_on_exit: false
      )

      assert_kind_of Hash, stats
      assert stats.key?(:corrected)
      assert stats.key?(:disabled)
    end
  end

  private

  def generate_rubocop_json(file_path)
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

    output.string
  end
end
