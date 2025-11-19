# Calculator with intentional RuboCop violations for E2E testing
# Missing frozen_string_literal comment (Style/FrozenStringLiteralComment)

class Calculator
  # Clean method - should not be touched
  def initialize
    @history = []
    @precision = 2
  end

  # Clean method - proper style
  def clear_history
    @history.clear
    true
  end

  # Violation: Style/StringLiterals (double quotes)
  # Violation: Style/RedundantReturn
  def add(a, b)
    result = a + b
    @history.push("add: #{a} + #{b} = #{result}")
    return result
  end

  # Violation: Layout/SpaceAroundOperators
  # Violation: Style/RedundantReturn
  def subtract(a, b)
    result=a-b
    @history.push("subtract: #{a} - #{b} = #{result}")
    return result
  end

  # Violation: Layout/TrailingWhitespace (there's trailing space after 'result')
  # Violation: Style/RedundantReturn
  def multiply(a, b)
    result = a * b
    @history.push("multiply: #{a} * #{b} = #{result}")
    return result
  end

  # Violation: Layout/MultilineMethodCallIndentation
  # Violation: Style/RedundantReturn
  def divide(a, b)
    raise ArgumentError, 'Cannot divide by zero' if b.zero?

    result = (a.to_f / b).round(@precision)
    @history.push("divide: #{a} / #{b} = #{result}")
        return result
  end

  # Violation: Metrics/MethodLength (too many lines - NOT autocorrectable)
  # Violation: Metrics/AbcSize (complexity - NOT autocorrectable)
  def calculate_expression(expression)
    tokens = expression.split
    return nil if tokens.empty?

    result = tokens[0].to_f
    i = 1

    while i < tokens.length
      operator = tokens[i]
      operand = tokens[i + 1].to_f

      case operator
      when '+'
        result = add(result, operand)
      when '-'
        result = subtract(result, operand)
      when '*'
        result = multiply(result, operand)
      when '/'
        result = divide(result, operand)
      else
        raise ArgumentError, "Unknown operator: #{operator}"
      end

      i += 2
    end

    result
  end

  # Violation: Layout/FirstArrayElementIndentation
  # Violation: Style/WordArray
  def supported_operations
    [
    "addition",
      "subtraction",
    "multiplication",
      "division"
    ]
  end

  # Violation: Naming/MethodParameterName (short param name - NOT autocorrectable)
  def power(x, n)
    result = x**n
    @history.push("power: #{x} ^ #{n} = #{result}")
    result
  end

  # Clean method
  def history
    @history.dup
  end

  # Violation: Style/MultilineBlockChain
  def history_summary
    @history
      .map { |entry| entry.split(':').first }
      .group_by { |op| op }
      .transform_values { |v| v.count }
  end

  # Violation: Layout/EmptyLinesAroundMethodBody
  def reset

    @history = []
    @precision = 2

  end

  # Violation: Style/GuardClause
  def set_precision(value)
    if value >= 0 && value <= 10
      @precision = value
    end
  end

  # Clean method - proper style throughout
  def format_result(value)
    if value.is_a?(Float)
      value.round(@precision).to_s
    else
      value.to_s
    end
  end
end

# Test harness - this runs when the file is executed directly
if __FILE__ == $PROGRAM_NAME
  calc = Calculator.new

  # Basic operations
  puts "Testing basic operations..."
  raise "add failed" unless calc.add(2, 3) == 5
  raise "subtract failed" unless calc.subtract(10, 4) == 6
  raise "multiply failed" unless calc.multiply(3, 4) == 12
  raise "divide failed" unless calc.divide(10, 4) == 2.5

  # Edge cases
  puts "Testing edge cases..."
  raise "negative add failed" unless calc.add(-5, 3) == -2
  raise "zero multiply failed" unless calc.multiply(0, 100) == 0

  # Power function
  puts "Testing power..."
  raise "power failed" unless calc.power(2, 3) == 8

  # Expression parsing
  puts "Testing expressions..."
  raise "expression failed" unless calc.calculate_expression("2 + 3 * 4") == 20

  # History
  puts "Testing history..."
  raise "history empty" if calc.history.empty?

  # Division by zero
  puts "Testing division by zero..."
  begin
    calc.divide(1, 0)
    raise "should have raised"
  rescue ArgumentError
    # expected
  end

  puts "All tests passed!"
  exit 0
end
