# frozen_string_literal: true

# This file intentionally contains a method with high ABC size for testing purposes
class RubeGoldbergMachine
  def overly_complex_method(input)
    # Assignment (A) - lots of variable assignments
    a = input[:first]
    b = input[:second]
    c = input[:third]
    d = input[:fourth]
    e = input[:fifth]

    # Branch (B) - multiple method calls and branches
    result1 = process_first(a) if a
    result2 = process_second(b) if b
    result3 = process_third(c) if c
    result4 = process_fourth(d) if d
    result5 = process_fifth(e) if e

    # Condition (C) - conditional logic
    if result1 && result2
      combined = combine_results(result1, result2)
    elsif result3 || result4
      combined = alternative_combine(result3, result4)
    else
      combined = default_value
    end

    # More branches
    final = transform(combined) if combined
    final = fallback if final.nil?
    final = sanitize(final) unless final.empty?

    # More assignments
    output = {}
    output[:status] = final[:status]
    output[:message] = final[:message]
    output[:data] = final[:data]
    output[:metadata] = final[:metadata]

    output
  end

  private

  def process_first(val); { status: :ok, value: val }; end
  def process_second(val); { status: :ok, value: val }; end
  def process_third(val); { status: :ok, value: val }; end
  def process_fourth(val); { status: :ok, value: val }; end
  def process_fifth(val); { status: :ok, value: val }; end
  def combine_results(a, b); { status: :ok, message: 'combined' }; end
  def alternative_combine(a, b); { status: :ok, message: 'alt' }; end
  def default_value; { status: :default, message: 'none' }; end
  def transform(val); val; end
  def fallback; { status: :fallback, message: 'fallback', data: nil, metadata: nil }; end
  def sanitize(val); val; end
end
