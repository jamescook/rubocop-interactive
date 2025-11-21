# Missing frozen_string_literal - safe correctable

class Calculator
  def add(x, y)
    return x + y  # RedundantReturn - safe correctable
  end

  def check_positive(num)
    if num > 0  # GuardClause - unsafe correctable (changes semantics)
      return true
    end
    false
  end

  def Foo  # MethodName - NOT correctable
    42
  end

  def bar
    puts "hello"  # StringLiterals - safe correctable (for correct-all test)
    puts "world"  # StringLiterals - safe correctable (for correct-all test)
  end
end
