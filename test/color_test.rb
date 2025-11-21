# frozen_string_literal: true

require_relative 'test_helper'

class ColorTest < Minitest::Test
  def test_red_wraps_text_in_red_ansi_codes
    result = RubocopInteractive::Color.red('hello')
    assert_equal "\e[31mhello\e[0m", result
  end

  def test_red_bold_wraps_text_in_bold_red_ansi_codes
    result = RubocopInteractive::Color.red('hello', bold: true)
    assert_equal "\e[1;31mhello\e[0m", result
  end

  def test_green_wraps_text_in_green_ansi_codes
    result = RubocopInteractive::Color.green('hello')
    assert_equal "\e[32mhello\e[0m", result
  end

  def test_yellow_wraps_text_in_yellow_ansi_codes
    result = RubocopInteractive::Color.yellow('hello')
    assert_equal "\e[33mhello\e[0m", result
  end

  def test_blue_wraps_text_in_blue_ansi_codes
    result = RubocopInteractive::Color.blue('hello')
    assert_equal "\e[34mhello\e[0m", result
  end

  def test_magenta_wraps_text_in_magenta_ansi_codes
    result = RubocopInteractive::Color.magenta('hello')
    assert_equal "\e[35mhello\e[0m", result
  end

  def test_cyan_wraps_text_in_cyan_ansi_codes
    result = RubocopInteractive::Color.cyan('hello')
    assert_equal "\e[36mhello\e[0m", result
  end

  def test_dim_wraps_text_in_dim_ansi_codes
    result = RubocopInteractive::Color.dim('hello')
    assert_equal "\e[2mhello\e[0m", result
  end

  def test_bold_wraps_text_in_bold_ansi_codes
    result = RubocopInteractive::Color.bold('hello')
    assert_equal "\e[1mhello\e[0m", result
  end

  def test_colorize_returns_text_unchanged_when_color_is_nil
    result = RubocopInteractive::Color.colorize('hello', nil)
    assert_equal 'hello', result
  end

  def test_colorize_supports_x11_color_names
    # Set COLORTERM to ensure truecolor support
    original_colorterm = ENV['COLORTERM']
    ENV['COLORTERM'] = 'truecolor'

    # Test a few X11 colors
    result = RubocopInteractive::Color.colorize('hello', :aqua)
    assert_match(/\e\[38;2;0;255;255m.*\e\[0m/, result)
  ensure
    ENV['COLORTERM'] = original_colorterm
  end

  def test_colorize_returns_text_unchanged_for_unknown_color
    result = RubocopInteractive::Color.colorize('hello', :nonexistent)
    assert_equal 'hello', result
  end

  def test_colorize_uses_ansi256_for_x11_colors_without_truecolor
    # Save original env
    original_colorterm = ENV['COLORTERM']
    ENV.delete('COLORTERM')

    # X11 color should use 256-color fallback
    result = RubocopInteractive::Color.colorize('hello', :aqua)
    # Should have 256-color code format: \e[38;5;NNNm
    assert_match(/\e\[38;5;\d+mhello\e\[0m/, result)
  ensure
    ENV['COLORTERM'] = original_colorterm if original_colorterm
  end

  def test_colorize_uses_truecolor_for_x11_colors_with_truecolor_env
    # Set truecolor env
    original_colorterm = ENV['COLORTERM']
    ENV['COLORTERM'] = 'truecolor'

    # X11 color should use RGB truecolor
    result = RubocopInteractive::Color.colorize('hello', :aqua)
    # Should have truecolor format: \e[38;2;R;G;Bm
    assert_match(/\e\[38;2;\d+;\d+;\d+mhello\e\[0m/, result)
  ensure
    ENV['COLORTERM'] = original_colorterm if original_colorterm
  end
end
