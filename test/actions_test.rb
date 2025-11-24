# frozen_string_literal: true

require_relative 'test_helper'

class ActionsTest < Minitest::Test

  def setup
    @offense_data = {
      'cop_name' => 'Style/StringLiterals',
      'message' => 'Prefer single-quoted strings',
      'severity' => 'convention',
      'correctable' => true,
      'location' => { 'start_line' => 6, 'start_column' => 7, 'length' => 15 }
    }
  end

  def test_autocorrect_fixes_only_target_offense
    with_temp_fixture do |dir|
      file_path = File.join(dir, 'bad_code.rb')

      # Target the first StringLiterals offense on line 6
      offense = RubocopInteractive::Offense.new(file_path: file_path, data: @offense_data)

      result = RubocopInteractive::Actions.perform(:autocorrect, offense)

      assert_equal :corrected, result[:status]

      corrected_content = File.read(file_path)

      # Line 6 should be fixed (double quotes -> single quotes)
      corrected_lines = corrected_content.lines
      assert_match(/'double quotes'/, corrected_lines[5])

      # Line 15 should still have double quotes (not fixed)
      assert_match(/"test"/, corrected_lines[14])
    end
  end

  def test_disable_line_adds_comment
    with_temp_fixture do |dir|
      file_path = File.join(dir, 'bad_code.rb')
      @offense_data['location']['start_line'] = 6
      offense = RubocopInteractive::Offense.new(file_path: file_path, data: @offense_data)

      result = RubocopInteractive::Actions.perform(:disable_line, offense)

      assert_equal :disabled, result[:status]

      content = File.read(file_path)

      assert_match(/rubocop:disable Style\/StringLiterals/, content)
    end
  end

  def test_disable_file_adds_comments_at_top_and_bottom
    with_temp_fixture do |dir|
      file_path = File.join(dir, 'bad_code.rb')
      offense = RubocopInteractive::Offense.new(file_path: file_path, data: @offense_data)

      result = RubocopInteractive::Actions.perform(:disable_file, offense)

      assert_equal :disabled, result[:status]

      lines = File.readlines(file_path)
      assert_match(/rubocop:disable Style\/StringLiterals/, lines.first)
      assert_match(%r{rubocop:enable Style/StringLiterals}, lines.last)
    end
  end

  def test_disable_line_wraps_comment_only_lines
    # When a line is comment-only, wrap with disable/enable to avoid
    # "# comment # rubocop:disable" syntax which confuses RuboCop.
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'comment_only.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        # This is a comment-only line
        x = 1
      RUBY

      offense_data = {
        'cop_name' => 'Style/CommentAnnotation',
        'message' => 'Annotation comment',
        'severity' => 'convention',
        'correctable' => false,
        'location' => { 'start_line' => 3, 'start_column' => 1, 'length' => 1 }
      }

      offense = RubocopInteractive::Offense.new(file_path: file_path, data: offense_data)

      result = RubocopInteractive::Actions.perform(:disable_line, offense)

      assert_equal :disabled, result[:status]

      lines = File.readlines(file_path)

      # Should wrap the comment-only line with disable/enable
      assert_match(/rubocop:disable Style\/CommentAnnotation/, lines[2])
      assert_match(/# This is a comment-only line/, lines[3])
      assert_match(/rubocop:enable Style\/CommentAnnotation/, lines[4])
    end
  end

  def test_disable_line_appends_to_existing_disable
    # When a line already has a rubocop:disable, append the new cop to it
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'existing_disable.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        x = 1 # rubocop:disable Lint/UselessAssignment
      RUBY

      offense_data = {
        'cop_name' => 'Style/Something',
        'message' => 'Some issue',
        'severity' => 'convention',
        'correctable' => false,
        'location' => { 'start_line' => 3, 'start_column' => 1, 'length' => 1 }
      }

      offense = RubocopInteractive::Offense.new(file_path: file_path, data: offense_data)

      result = RubocopInteractive::Actions.perform(:disable_line, offense)

      assert_equal :disabled, result[:status]

      content = File.read(file_path)

      # Should append to existing disable directive
      assert_match(/rubocop:disable Lint\/UselessAssignment, Style\/Something/, content)
    end
  end

  def test_autocorrect_with_existing_rubocop_disable_comment
    # Regression test: autocorrecting a file with rubocop:disable comments
    # used to fail with "undefined method 'disabled' for nil" because
    # ProcessedSource.registry was not set
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'with_disable.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        def foo
          x = "test"  # rubocop:disable Lint/UselessAssignment
        end
      RUBY

      offense_data = {
        'cop_name' => 'Style/StringLiterals',
        'message' => 'Prefer single-quoted strings',
        'severity' => 'convention',
        'correctable' => true,
        'location' => { 'start_line' => 4, 'start_column' => 7, 'length' => 6 }
      }

      offense = RubocopInteractive::Offense.new(file_path: file_path, data: offense_data)

      result = RubocopInteractive::Actions.perform(:autocorrect, offense)

      assert_equal :corrected, result[:status]

      corrected_content = File.read(file_path)
      assert_match(/'test'/, corrected_content)
    end
  end
end
