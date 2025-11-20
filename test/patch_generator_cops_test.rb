# frozen_string_literal: true

require_relative 'test_helper'

# Tests for patch generation with various RuboCop cops that have
# interesting or complex autocorrect behavior
class PatchGeneratorCopsTest < Minitest::Test
  def test_style_if_unless_modifier_multiline_to_oneline
    # Style/IfUnlessModifier converts multi-line if to single line
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        def example
          if condition
            do_something
          end
        end
      RUBY

      offense = build_offense(
        file_path: file_path,
        cop_name: 'Style/IfUnlessModifier',
        line: 4
      )

      result = RubocopInteractive::PatchGenerator.generate(offense)

      assert result, "Should generate patch for Style/IfUnlessModifier"
      # Should show multi-line if being replaced with modifier form
      assert_match(/-\s*if condition/, result[:lines], "Should show if being removed")
      assert_match(/\+.*do_something if condition/, result[:lines], "Should show modifier form")
    end
  end

  def test_style_guard_clause
    # Style/GuardClause converts if-block at end of method to guard clause
    # NOTE: Autocorrect works in most cases except with if-else statements
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      # Use the official bad example from RuboCop docs
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        def test
          if something
            work
          end
        end

        def other_method
          'keeps file valid'
        end
      RUBY

      offense = build_offense(
        file_path: file_path,
        cop_name: 'Style/GuardClause',
        line: 4
      )

      result = RubocopInteractive::PatchGenerator.generate(offense)

      assert result, "Should generate patch for Style/GuardClause"
      # Should convert to: return unless something; work
      # or: work if something
      assert_match(/unless|if/, result[:lines], "Should show guard clause form")
    end
  end

  def test_style_hash_transform_values
    # Style/HashTransformValues converts each_with_object to transform_values
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        hash.each_with_object({}) { |(k, v), h| h[k] = v.upcase }
      RUBY

      offense = build_offense(
        file_path: file_path,
        cop_name: 'Style/HashTransformValues',
        line: 3
      )

      result = RubocopInteractive::PatchGenerator.generate(offense)

      assert result, "Should generate patch for Style/HashTransformValues"
      assert_match(/transform_values/, result[:lines], "Should show transform_values")
    end
  end

  def test_style_hash_transform_keys
    # Style/HashTransformKeys converts map.to_h to transform_keys
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        hash.map { |k, v| [k.to_s, v] }.to_h
      RUBY

      offense = build_offense(
        file_path: file_path,
        cop_name: 'Style/HashTransformKeys',
        line: 3
      )

      result = RubocopInteractive::PatchGenerator.generate(offense)

      assert result, "Should generate patch for Style/HashTransformKeys"
      assert_match(/transform_keys/, result[:lines], "Should show transform_keys")
    end
  end

  def test_layout_space_around_operators
    # Layout/SpaceAroundOperators adds spaces around operators
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        x=1+2*3
      RUBY

      offense = build_offense(
        file_path: file_path,
        cop_name: 'Layout/SpaceAroundOperators',
        line: 3
      )

      result = RubocopInteractive::PatchGenerator.generate(offense)

      assert result, "Should generate patch for Layout/SpaceAroundOperators"
      # Should add spaces around operators
      assert_match(/\+.*=\s+1\s+/, result[:lines], "Should show spaces around =")
    end
  end

  def test_style_redundant_return
    # Style/RedundantReturn removes unnecessary return
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        def example
          return 42
        end
      RUBY

      offense = build_offense(
        file_path: file_path,
        cop_name: 'Style/RedundantReturn',
        line: 4
      )

      result = RubocopInteractive::PatchGenerator.generate(offense)

      assert result, "Should generate patch for Style/RedundantReturn"
      assert_match(/-.*return 42/, result[:lines], "Should show return being removed")
      assert_match(/\+\s+42/, result[:lines], "Should show just the value")
    end
  end

  def test_style_frozen_string_literal_comment
    # Style/FrozenStringLiteralComment adds the magic comment (unsafe)
    # Uses official example from RuboCop docs
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      File.write(file_path, <<~RUBY)
        module Bar
          # ...
        end
      RUBY

      offense = build_offense(
        file_path: file_path,
        cop_name: 'Style/FrozenStringLiteralComment',
        line: 1
      )

      result = RubocopInteractive::PatchGenerator.generate(offense)

      assert result, "Should generate patch for Style/FrozenStringLiteralComment"
      assert_match(/frozen_string_literal.*true/, result[:lines], "Should add frozen string literal comment")
    end
  end

  def test_layout_trailing_whitespace
    # Layout/TrailingWhitespace removes trailing spaces
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      # Note: trailing spaces after "hello"
      File.write(file_path, "# frozen_string_literal: true\n\ndef example   \n  'hello'\nend\n")

      offense = build_offense(
        file_path: file_path,
        cop_name: 'Layout/TrailingWhitespace',
        line: 3
      )

      result = RubocopInteractive::PatchGenerator.generate(offense)

      assert result, "Should generate patch for Layout/TrailingWhitespace"
      assert_match(/-def example\s+\n/, result[:lines], "Should show line with trailing spaces")
      assert_match(/\+def example\n/, result[:lines], "Should show line without trailing spaces")
    end
  end

  def test_style_symbol_array
    # Style/SymbolArray converts array of symbols to %i[]
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        [:foo, :bar, :baz]
      RUBY

      offense = build_offense(
        file_path: file_path,
        cop_name: 'Style/SymbolArray',
        line: 3
      )

      result = RubocopInteractive::PatchGenerator.generate(offense)

      assert result, "Should generate patch for Style/SymbolArray"
      assert_match(/%i/, result[:lines], "Should show %i array syntax")
    end
  end

  def test_style_word_array
    # Style/WordArray converts array of strings to %w[]
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        ['foo', 'bar', 'baz']
      RUBY

      offense = build_offense(
        file_path: file_path,
        cop_name: 'Style/WordArray',
        line: 3
      )

      result = RubocopInteractive::PatchGenerator.generate(offense)

      assert result, "Should generate patch for Style/WordArray"
      assert_match(/%w/, result[:lines], "Should show %w array syntax")
    end
  end

  def test_naming_method_name
    # Naming/MethodName - this is NOT correctable
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        def BadMethodName
          'hello'
        end
      RUBY

      offense = build_offense(
        file_path: file_path,
        cop_name: 'Naming/MethodName',
        line: 3,
        correctable: false
      )

      result = RubocopInteractive::PatchGenerator.generate(offense)

      assert_nil result, "Should not generate patch for non-correctable cop"
    end
  end

  def test_layout_empty_lines_around_method_body
    # Layout/EmptyLinesAroundMethodBody removes extra blank lines
    Dir.mktmpdir do |dir|
      file_path = File.join(dir, 'test.rb')
      File.write(file_path, <<~RUBY)
        # frozen_string_literal: true

        def example

          'hello'

        end
      RUBY

      offense = build_offense(
        file_path: file_path,
        cop_name: 'Layout/EmptyLinesAroundMethodBody',
        line: 4
      )

      result = RubocopInteractive::PatchGenerator.generate(offense)

      assert result, "Should generate patch for Layout/EmptyLinesAroundMethodBody"
      # Should remove blank line
      assert_match(/-\n/, result[:lines], "Should show blank line being removed")
    end
  end

  private

  def build_offense(file_path:, cop_name:, line:, correctable: true)
    RubocopInteractive::Offense.new(
      file_path: file_path,
      data: {
        'cop_name' => cop_name,
        'message' => 'Test message',
        'severity' => 'convention',
        'correctable' => correctable,
        'location' => {
          'start_line' => line,
          'start_column' => 1,
          'length' => 1
        }
      }
    )
  end
end
