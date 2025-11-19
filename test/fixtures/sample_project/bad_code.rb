# frozen_string_literal: true

# This file has intentional RuboCop offenses for testing

def hello_world
  x = "double quotes"   # Style/StringLiterals
  y = 1+2               # Layout/SpaceAroundOperators
  if x
    puts y              # Style/IfUnlessModifier (could be one-liner)
  end

  array = [1,2,3]       # Layout/SpaceAfterComma
  hash = {a:1, b:2}     # Layout/SpaceAfterColon

  unused = "test"       # Lint/UselessAssignment
end

class SomeClass
  def BAR              # Naming/MethodName
    "baz"
  end
end
