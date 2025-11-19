# frozen_string_literal: true

module RubocopInteractive
  # ANSI escape sequences for terminal control
  module ANSI
    # Text formatting
    RESET = "\e[0m"
    BOLD = "\e[1m"
    DIM = "\e[2m"
    ITALIC = "\e[3m"

    # Cursor and line control
    CLEAR_LINE = "\r\e[K"
    BELL = "\a"

    # Arrow key input sequences
    ARROW_UP = "\e[A"
    ARROW_DOWN = "\e[B"
    ARROW_RIGHT = "\e[C"
    ARROW_LEFT = "\e[D"
  end
end
