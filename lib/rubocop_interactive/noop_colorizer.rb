# frozen_string_literal: true

module RubocopInteractive
  # No-op colorizer - returns text without ANSI codes
  # Useful for testing or environments that don't support ANSI
  module NoopColorizer
    module_function

    def colorize(text, _color, **_)
      text
    end

    def red(text, **_)
      text
    end

    def green(text, **_)
      text
    end

    def yellow(text, **_)
      text
    end

    def blue(text, **_)
      text
    end

    def magenta(text, **_)
      text
    end

    def cyan(text, **_)
      text
    end

    def dim(text)
      text
    end

    def bold(text)
      text
    end

    # ANSI constants as empty strings (no-ops)
    CLEAR_LINE = ''
    BELL = ''
    ARROW_LEFT = "\e[D"
    ARROW_RIGHT = "\e[C"
    ARROW_UP = "\e[A"
    ARROW_DOWN = "\e[B"
  end
end
