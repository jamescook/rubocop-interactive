# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../lib/rubocop_interactive/editor_launcher'

class EditorLauncherTest < Minitest::Test
  def test_launch_fails_when_no_editor_env_var
    launcher = RubocopInteractive::EditorLauncher.new

    with_env('EDITOR' => nil) do
      result = launcher.launch('/tmp/test.rb', 10)
      assert_equal false, result, "Should return false when EDITOR not set"
      assert_equal :no_editor, launcher.error
    end
  end

  def test_launch_with_vim
    launcher = RubocopInteractive::EditorLauncher.new

    with_env('EDITOR' => 'vim') do
      # Mock system call
      launcher.define_singleton_method(:system) do |cmd|
        @last_command = cmd
        true
      end

      result = launcher.launch('/tmp/test.rb', 10)

      assert result, "Should return true on success"
      assert_equal 'vim +10 /tmp/test.rb', launcher.instance_variable_get(:@last_command)
    end
  end

  def test_launch_with_nvim
    launcher = RubocopInteractive::EditorLauncher.new

    with_env('EDITOR' => 'nvim') do
      launcher.define_singleton_method(:system) do |cmd|
        @last_command = cmd
        true
      end

      result = launcher.launch('/tmp/test.rb', 10)

      assert result
      assert_equal 'nvim +10 /tmp/test.rb', launcher.instance_variable_get(:@last_command)
    end
  end

  def test_launch_escapes_file_paths_with_spaces
    launcher = RubocopInteractive::EditorLauncher.new

    with_env('EDITOR' => 'vim') do
      launcher.define_singleton_method(:system) do |cmd|
        @last_command = cmd
        true
      end

      launcher.launch('/tmp/test file.rb', 10)

      assert_match(/vim \+10 .*test\\ file\.rb/, launcher.instance_variable_get(:@last_command))
    end
  end

  def test_launch_with_unknown_editor_opens_without_line_number
    launcher = RubocopInteractive::EditorLauncher.new

    with_env('EDITOR' => 'unknown-editor') do
      launcher.define_singleton_method(:system) do |cmd|
        @last_command = cmd
        true
      end

      launcher.launch('/tmp/test.rb', 10)

      # Unknown editor should open file without line number
      assert_equal 'unknown-editor /tmp/test.rb', launcher.instance_variable_get(:@last_command)
    end
  end

  private

  def with_env(vars)
    original = {}
    vars.each do |key, value|
      original[key] = ENV[key]
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
    yield
  ensure
    original.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end
end
