# frozen_string_literal: true

require_relative 'test_helper'

class TemplateContextTest < Minitest::Test
  def test_cop_color_is_deterministic
    context = RubocopInteractive::TemplateContext.new

    # Same cop name should always return same color
    color1 = context.cop_color('Style/StringLiterals')
    color2 = context.cop_color('Style/StringLiterals')

    assert_equal color1, color2, 'Same cop name should return same color'
  end

  def test_cop_color_returns_valid_x11_color
    context = RubocopInteractive::TemplateContext.new

    color = context.cop_color('Layout/TrailingWhitespace')

    # Should return a symbol that exists in the X11 color table
    assert RubocopInteractive::Color::X11.key?(color),
           "cop_color should return a valid X11 color, got: #{color}"
  end

  def test_cop_color_maps_different_cops_to_colors
    context = RubocopInteractive::TemplateContext.new

    # Test a variety of cop names
    cops = [
      'Style/StringLiterals',
      'Layout/TrailingWhitespace',
      'Lint/UselessAssignment',
      'Metrics/MethodLength',
      'Naming/VariableName'
    ]

    colors = cops.map { |cop| context.cop_color(cop) }

    # All colors should be valid X11 colors
    colors.each do |color|
      assert RubocopInteractive::Color::X11.key?(color),
             "Expected valid X11 color, got: #{color}"
    end

    # Should have some variety (not all the same color)
    # With 5 cops and 10 colors, very unlikely all map to same color
    assert colors.uniq.size > 1, 'Expected different cops to map to different colors'
  end

  def test_cop_color_can_be_used_with_colorizer
    context = RubocopInteractive::TemplateContext.new(
      cop_name: 'Style/StringLiterals'
    )

    # Should be able to use the color with the color helper
    color_name = context.cop_color(context.cop_name)
    colored_text = context.color(context.cop_name, color_name)

    # Should return colored text (with ANSI codes)
    assert colored_text.include?("\e["), 'Expected ANSI color codes in output'
    assert colored_text.include?('Style/StringLiterals'), 'Expected cop name in output'
  end
end
