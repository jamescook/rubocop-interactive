# frozen_string_literal: true

module RubocopInteractive
  # Wraps a single RuboCop offense from JSON
  class Offense
    attr_reader :file_path, :cop_name, :message, :severity, :correctable,
                :line, :column, :length

    def initialize(file_path:, data:)
      @file_path = file_path
      @cop_name = data['cop_name']
      @message = data['message']
      @severity = data['severity']
      @correctable = data['correctable']
      @line = data.dig('location', 'start_line')
      @column = data.dig('location', 'start_column')
      @length = data.dig('location', 'length')
    end

    def correctable?
      @correctable
    end

    def location
      "#{file_path}:#{line}:#{column}"
    end

    def to_s
      "[#{severity}] #{cop_name}: #{message} (#{location})"
    end
  end
end
