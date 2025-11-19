# frozen_string_literal: true

module RubocopInteractive
  # Terminal color support with ANSI and X11 color names
  module Color
    # Basic ANSI colors (foreground)
    ANSI = {
      black: 30, red: 31, green: 32, yellow: 33,
      blue: 34, magenta: 35, cyan: 36, white: 37
    }.freeze

    # X11 color names -> RGB (from Rainbow gem)
    X11 = {
      aqua: [0, 255, 255],
      aquamarine: [127, 255, 212],
      mediumaquamarine: [102, 205, 170],
      azure: [240, 255, 255],
      beige: [245, 245, 220],
      bisque: [255, 228, 196],
      blanchedalmond: [255, 235, 205],
      darkblue: [0, 0, 139],
      lightblue: [173, 216, 230],
      mediumblue: [0, 0, 205],
      aliceblue: [240, 248, 255],
      cadetblue: [95, 158, 160],
      dodgerblue: [30, 144, 255],
      midnightblue: [25, 25, 112],
      navyblue: [0, 0, 128],
      powderblue: [176, 224, 230],
      royalblue: [65, 105, 225],
      skyblue: [135, 206, 235],
      deepskyblue: [0, 191, 255],
      lightskyblue: [135, 206, 250],
      slateblue: [106, 90, 205],
      darkslateblue: [72, 61, 139],
      mediumslateblue: [123, 104, 238],
      steelblue: [70, 130, 180],
      lightsteelblue: [176, 196, 222],
      brown: [165, 42, 42],
      rosybrown: [188, 143, 143],
      saddlebrown: [139, 69, 19],
      sandybrown: [244, 164, 96],
      burlywood: [222, 184, 135],
      chartreuse: [127, 255, 0],
      chocolate: [210, 105, 30],
      coral: [255, 127, 80],
      lightcoral: [240, 128, 128],
      cornflower: [100, 149, 237],
      cornsilk: [255, 248, 220],
      crimson: [220, 20, 60],
      darkcyan: [0, 139, 139],
      lightcyan: [224, 255, 255],
      firebrick: [178, 34, 34],
      fuchsia: [255, 0, 255],
      gainsboro: [220, 220, 220],
      gold: [255, 215, 0],
      goldenrod: [218, 165, 32],
      darkgoldenrod: [184, 134, 11],
      lightgoldenrod: [250, 250, 210],
      palegoldenrod: [238, 232, 170],
      gray: [190, 190, 190],
      darkgray: [169, 169, 169],
      dimgray: [105, 105, 105],
      lightgray: [211, 211, 211],
      slategray: [112, 128, 144],
      lightslategray: [119, 136, 153],
      webgray: [128, 128, 128],
      darkgreen: [0, 100, 0],
      lightgreen: [144, 238, 144],
      palegreen: [152, 251, 152],
      darkolivegreen: [85, 107, 47],
      yellowgreen: [154, 205, 50],
      forestgreen: [34, 139, 34],
      lawngreen: [124, 252, 0],
      limegreen: [50, 205, 50],
      seagreen: [46, 139, 87],
      darkseagreen: [143, 188, 143],
      lightseagreen: [32, 178, 170],
      mediumseagreen: [60, 179, 113],
      springgreen: [0, 255, 127],
      mediumspringgreen: [0, 250, 154],
      webgreen: [0, 128, 0],
      honeydew: [240, 255, 240],
      indianred: [205, 92, 92],
      indigo: [75, 0, 130],
      ivory: [255, 255, 240],
      khaki: [240, 230, 140],
      darkkhaki: [189, 183, 107],
      lavender: [230, 230, 250],
      lavenderblush: [255, 240, 245],
      lemonchiffon: [255, 250, 205],
      lime: [0, 255, 0],
      linen: [250, 240, 230],
      darkmagenta: [139, 0, 139],
      maroon: [176, 48, 96],
      webmaroon: [127, 0, 0],
      mintcream: [245, 255, 250],
      mistyrose: [255, 228, 225],
      moccasin: [255, 228, 181],
      oldlace: [253, 245, 230],
      olive: [128, 128, 0],
      olivedrab: [107, 142, 35],
      orange: [255, 165, 0],
      darkorange: [255, 140, 0],
      orchid: [218, 112, 214],
      darkorchid: [153, 50, 204],
      mediumorchid: [186, 85, 211],
      papayawhip: [255, 239, 213],
      peachpuff: [255, 218, 185],
      peru: [205, 133, 63],
      pink: [255, 192, 203],
      deeppink: [255, 20, 147],
      lightpink: [255, 182, 193],
      hotpink: [255, 105, 180],
      plum: [221, 160, 221],
      purple: [160, 32, 240],
      mediumpurple: [147, 112, 219],
      rebeccapurple: [102, 51, 153],
      webpurple: [127, 0, 127],
      darkred: [139, 0, 0],
      orangered: [255, 69, 0],
      mediumvioletred: [199, 21, 133],
      palevioletred: [219, 112, 147],
      salmon: [250, 128, 114],
      darksalmon: [233, 150, 122],
      lightsalmon: [255, 160, 122],
      seashell: [255, 245, 238],
      sienna: [160, 82, 45],
      silver: [192, 192, 192],
      darkslategray: [47, 79, 79],
      snow: [255, 250, 250],
      tan: [210, 180, 140],
      teal: [0, 128, 128],
      thistle: [216, 191, 216],
      tomato: [255, 99, 71],
      turquoise: [64, 224, 208],
      darkturquoise: [0, 206, 209],
      mediumturquoise: [72, 209, 204],
      paleturquoise: [175, 238, 238],
      violet: [238, 130, 238],
      darkviolet: [148, 0, 211],
      blueviolet: [138, 43, 226],
      wheat: [245, 222, 179],
      antiquewhite: [250, 235, 215],
      floralwhite: [255, 250, 240],
      ghostwhite: [248, 248, 255],
      navajowhite: [255, 222, 173],
      whitesmoke: [245, 245, 245],
      lightyellow: [255, 255, 224],
      greenyellow: [173, 255, 47]
    }.freeze

    class << self
      def colorize(text, color, bold: false)
        return text unless color
        return text unless $stdout.tty?

        code = color_code(color)
        return text unless code

        bold_prefix = bold ? '1;' : ''
        "\e[#{bold_prefix}#{code}m#{text}\e[0m"
      end

      # Convenience methods
      def red(text, bold: false)
        colorize(text, :red, bold: bold)
      end

      def green(text, bold: false)
        colorize(text, :green, bold: bold)
      end

      def yellow(text, bold: false)
        colorize(text, :yellow, bold: bold)
      end

      def blue(text, bold: false)
        colorize(text, :blue, bold: bold)
      end

      def cyan(text, bold: false)
        colorize(text, :cyan, bold: bold)
      end

      def magenta(text, bold: false)
        colorize(text, :magenta, bold: bold)
      end

      def bold(text)
        return text unless $stdout.tty?

        "\e[1m#{text}\e[0m"
      end

      def dim(text)
        return text unless $stdout.tty?

        "\e[2m#{text}\e[0m"
      end

      private

      def color_code(color)
        color = color.to_sym

        # Check basic ANSI first
        return ANSI[color] if ANSI.key?(color)

        # Check X11 colors
        if X11.key?(color)
          r, g, b = X11[color]
          return "38;2;#{r};#{g};#{b}" if truecolor?

          return ansi256(r, g, b)
        end

        nil
      end

      def truecolor?
        ENV['COLORTERM'] == 'truecolor' || ENV['COLORTERM'] == '24bit'
      end

      def ansi256(r, g, b)
        # Convert RGB to 256-color palette
        # 216 color cube: 6x6x6
        if r == g && g == b
          # Grayscale
          gray = ((r - 8) / 247.0 * 24).round
          gray = [[gray, 0].max, 23].min
          "38;5;#{232 + gray}"
        else
          # Color cube
          ri = (r / 255.0 * 5).round
          gi = (g / 255.0 * 5).round
          bi = (b / 255.0 * 5).round
          "38;5;#{16 + 36 * ri + 6 * gi + bi}"
        end
      end
    end
  end
end
