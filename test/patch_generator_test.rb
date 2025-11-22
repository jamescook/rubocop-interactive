# frozen_string_literal: true

require_relative 'test_helper'

class PatchGeneratorTest < Minitest::Test
  include DiffAssertionHelper
  def test_generate_with_string_literals_offense
    # Create a temp file with double-quoted string that should be single-quoted
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        def foo
          x = "double quotes"
          x
        end
      RUBY

      # Create an offense like RuboCop would report
      offense = RubocopInteractive::Offense.new(
        file_path: file_path,
        data: {
          'cop_name' => 'Style/StringLiterals',
          'message' => "Prefer single-quoted strings when you don't need string interpolation or special symbols.",
          'severity' => 'convention',
          'correctable' => true,
          'location' => {
            'start_line' => 4,
            'start_column' => 7,
            'length' => 15
          }
        }
      )

      result = RubocopInteractive::PatchGenerator.generate(offense)

      assert result, "Should generate a patch for Style/StringLiterals"
      assert_equal 2, result[:start_line]

      expected_diff = <<~DIFF

         def foo
        -  x = "double quotes"
        +  x = 'double quotes'
           x
         end
      DIFF

      assert_diff_equal expected_diff, result[:lines]
    end
  end

  def test_generate_with_bad_code_fixture
    # Use the actual bad_code.rb fixture - Style/StringLiterals on line 6
    file_path = File.expand_path('fixtures/sample_project/bad_code.rb', __dir__)

    offense = RubocopInteractive::Offense.new(
      file_path: file_path,
      data: {
        'cop_name' => 'Style/StringLiterals',
        'message' => "Prefer single-quoted strings when you don't need string interpolation or special symbols.",
        'severity' => 'convention',
        'correctable' => true,
        'location' => {
          'start_line' => 6,
          'start_column' => 7,
          'length' => 15
        }
      }
    )

    result = RubocopInteractive::PatchGenerator.generate(offense)

    assert result, "Should generate a patch for Style/StringLiterals in bad_code.rb"
    assert_equal 4, result[:start_line]

    expected_diff = <<~DIFF
 
       def hello_world
      -  x = "double quotes"   # Style/StringLiterals
      +  x = 'double quotes'   # Style/StringLiterals
         y = 1+2               # Layout/SpaceAroundOperators
         if x
    DIFF

    assert_diff_equal expected_diff, result[:lines]
  end

  def test_generate_useless_assignment_only_shows_target_line
    # Lint/UselessAssignment on line 15 for 'unused'
    # Should not show line 12's array as a change (different cop)
    file_path = File.expand_path('fixtures/sample_project/bad_code.rb', __dir__)

    offense = RubocopInteractive::Offense.new(
      file_path: file_path,
      data: {
        'cop_name' => 'Lint/UselessAssignment',
        'message' => 'Useless assignment to variable - `unused`.',
        'severity' => 'warning',
        'correctable' => true,
        'location' => {
          'start_line' => 15,
          'start_column' => 3,
          'length' => 6
        }
      }
    )

    result = RubocopInteractive::PatchGenerator.generate(offense)

    assert result, "Should generate a patch for Lint/UselessAssignment"
    assert_equal 14, result[:start_line]

    expected_diff = <<~DIFF
 
        -  unused = "test"       # Lint/UselessAssignment
        +  "test"       # Lint/UselessAssignment
         end

    DIFF

    assert_diff_equal expected_diff, result[:lines]

    # Verify line 13's hash is NOT shown as a change (only as context)
    refute_diff_contains result[:lines], /hash\s*=.*{a:1/, "Should not show hash assignment as a change"
  end

  def test_generate_with_added_line_after_target
    # Regression test for Layout/EmptyLineAfterMagicComment
    # When an offense inserts a line AFTER the target line
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true
        # Some comment
        def foo
        end
      RUBY

      # The offense is on line 2 (after which we need to insert a blank line)
      offense = RubocopInteractive::Offense.new(
        file_path: file_path,
        data: {
          'cop_name' => 'Layout/EmptyLineAfterMagicComment',
          'message' => 'Add an empty line after magic comments.',
          'severity' => 'convention',
          'correctable' => true,
          'location' => {
            'start_line' => 2,
            'start_column' => 1,
            'length' => 1
          }
        }
      )

      result = RubocopInteractive::PatchGenerator.generate(offense)

      assert result, "Should find the added line affecting line 2"
      assert_equal 1, result[:start_line]

      expected_diff = <<~DIFF
         # frozen_string_literal: true
        +
         # Some comment
         def foo
      DIFF

      assert_diff_equal expected_diff, result[:lines]
    end
  end

  def test_generate_one_line_becomes_multiple
    # Regression test for Style/CommentedKeyword
    # When one line is changed and additional lines are added (CHANGED + ADDED)
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        def Foo # comment
          42
        end
      RUBY

      # The offense is on line 3
      offense = RubocopInteractive::Offense.new(
        file_path: file_path,
        data: {
          'cop_name' => 'Style/CommentedKeyword',
          'message' => 'Do not place comments on the same line as the def keyword.',
          'severity' => 'convention',
          'correctable' => true,
          'location' => {
            'start_line' => 3,
            'start_column' => 9,
            'length' => 9
          }
        }
      )

      result = RubocopInteractive::PatchGenerator.generate(offense)

      assert result, "Should find the change on line 3"
      assert_equal 1, result[:start_line]

      expected_diff = <<~DIFF
         # frozen_string_literal: true

        -def Foo # comment
        +# comment
        +def Foo
           42
         end
      DIFF

      assert_diff_equal expected_diff, result[:lines]
    end
  end

  def test_generate_returns_nil_for_non_correctable_offense
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      File.write(file_path, "x = 1\n")

      offense = RubocopInteractive::Offense.new(
        file_path: file_path,
        data: {
          'cop_name' => 'Style/FakeNonCorrectableCop',
          'message' => 'This is not correctable',
          'severity' => 'convention',
          'correctable' => false,
          'location' => {
            'start_line' => 1,
            'start_column' => 1,
            'length' => 1
          }
        }
      )

      result = RubocopInteractive::PatchGenerator.generate(offense)

      assert_nil result, "Should return nil for non-correctable offense"
    end
  end

  def test_generate_returns_nil_when_no_changes_made
    # If autocorrect produces no changes (edge case), should return nil
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      # Write code that's already correct
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        def foo
          x = 'single quotes'
          x
        end
      RUBY

      offense = RubocopInteractive::Offense.new(
        file_path: file_path,
        data: {
          'cop_name' => 'Style/StringLiterals',
          'message' => 'Already correct',
          'severity' => 'convention',
          'correctable' => true,
          'location' => {
            'start_line' => 4,
            'start_column' => 7,
            'length' => 15
          }
        }
      )

      result = RubocopInteractive::PatchGenerator.generate(offense)

      # Should return nil because autocorrect produces no changes
      assert_nil result, "Should return nil when no changes are made"
    end
  end

  def test_generate_shows_context_lines
    # Verify that context lines are included around the change
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        def foo
          before_line
          x = "double quotes"
          after_line
        end
      RUBY

      offense = RubocopInteractive::Offense.new(
        file_path: file_path,
        data: {
          'cop_name' => 'Style/StringLiterals',
          'message' => 'Use single quotes',
          'severity' => 'convention',
          'correctable' => true,
          'location' => {
            'start_line' => 5,
            'start_column' => 7,
            'length' => 15
          }
        }
      )

      result = RubocopInteractive::PatchGenerator.generate(offense)

      assert result, "Should generate a patch"
      assert_equal 3, result[:start_line]

      expected_diff = <<~DIFF
         def foo
           before_line
        -  x = "double quotes"
        +  x = 'double quotes'
           after_line
         end
      DIFF

      assert_diff_equal expected_diff, result[:lines]
    end
  end

  def test_generate_stops_context_at_other_changes
    # When there are multiple consecutive offenses, context should stop at other changes
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        def foo
          x = "line 4"
          y = "line 5"
          z = "line 6"
        end
      RUBY

      # Target the middle offense (line 5)
      offense = RubocopInteractive::Offense.new(
        file_path: file_path,
        data: {
          'cop_name' => 'Style/StringLiterals',
          'message' => 'Use single quotes',
          'severity' => 'convention',
          'correctable' => true,
          'location' => {
            'start_line' => 5,
            'start_column' => 7,
            'length' => 10
          }
        }
      )

      result = RubocopInteractive::PatchGenerator.generate(offense)

      assert result, "Should generate a patch"
      assert_equal 5, result[:start_line]

      # Should only show line 5's change, not lines 4 or 6
      expected_diff = <<~DIFF
        -  y = "line 5"
        +  y = 'line 5'
      DIFF

      assert_diff_equal expected_diff, result[:lines]

      # Verify we don't see the other changes (only context lines, not +/- changes)
      refute_diff_contains result[:lines], /line 4/, "Should not include line 4 as a change"
      refute_diff_contains result[:lines], /line 6/, "Should not include line 6 as a change"
    end
  end
end
