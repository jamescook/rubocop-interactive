# frozen_string_literal: true

module DiffAssertionHelper
  # Parse a diff string into structured lines
  # Each line is { type: :context/:added/:removed, content: "..." }
  def parse_diff(diff_string)
    diff_string.lines.map do |line|
      case line[0]
      when ' '
        { type: :context, content: line[1..] || "\n" }
      when '+'
        { type: :added, content: line[1..] || "\n" }
      when '-'
        { type: :removed, content: line[1..] || "\n" }
      else
        # Shouldn't happen, but treat as context
        { type: :context, content: line }
      end
    end
  end

  # Assert that a diff does NOT contain a specific change (added/removed line)
  # This is more semantic than refute_match - it checks the diff structure
  def refute_diff_contains(diff_string, content_pattern, message = nil)
    parsed = parse_diff(diff_string)

    # Find any added or removed lines matching the pattern
    changes = parsed.select { |line| line[:type] == :added || line[:type] == :removed }
    matching = changes.select { |line| line[:content] =~ content_pattern }

    if matching.any?
      flunk <<~MSG
        #{message}
        Expected diff to NOT contain changes matching #{content_pattern.inspect}
        But found #{matching.size} matching change(s):
        #{matching.map { |m| "  #{m[:type] == :added ? '+' : '-'}#{m[:content].inspect}" }.join("\n")}

        Full diff:
        #{format_diff(parsed)}
      MSG
    end
  end

  # Assert that two diffs are semantically equal
  # Compares the structure (context/added/removed) and content
  def assert_diff_equal(expected, actual, message = nil)
    expected_lines = parse_diff(expected)
    actual_lines = parse_diff(actual)

    # Compare counts first for better error messages
    unless expected_lines.size == actual_lines.size
      flunk <<~MSG
        #{message}
        Different number of lines:
        Expected #{expected_lines.size} lines, got #{actual_lines.size}

        Expected:
        #{format_diff(expected_lines)}

        Actual:
        #{format_diff(actual_lines)}
      MSG
    end

    # Compare each line
    expected_lines.zip(actual_lines).each_with_index do |(exp, act), idx|
      unless exp[:type] == act[:type] && exp[:content] == act[:content]
        flunk <<~MSG
          #{message}
          Diff mismatch at line #{idx + 1}:
          Expected (#{exp[:type]}): #{exp[:content].inspect}
          Actual   (#{act[:type]}): #{act[:content].inspect}

          Full expected:
          #{format_diff(expected_lines)}

          Full actual:
          #{format_diff(actual_lines)}
        MSG
      end
    end
  end

  private

  def format_diff(parsed_lines)
    parsed_lines.map.with_index do |line, idx|
      prefix = case line[:type]
               when :context then ' '
               when :added then '+'
               when :removed then '-'
               end
      "#{idx + 1}: #{prefix}#{line[:content].inspect}"
    end.join("\n")
  end
end
