# frozen_string_literal: true

module RubocopInteractive
  # Configuration for rubocop-interactive
  Config = Struct.new(:rubocop_binary, :debug_preserve_temp) do
    def initialize
      super('rubocop', false)
    end
  end

  @config = Config.new

  class << self
    attr_accessor :config
  end
end
