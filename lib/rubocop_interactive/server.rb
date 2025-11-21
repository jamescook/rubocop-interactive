# frozen_string_literal: true

module RubocopInteractive
  # Manages RuboCop server for fast autocorrection
  class Server
    SLEEP_TIME = 0.1
    PATIENCE = 10

    def initialize
      @started = false
    end

    def ensure_running!
      return if running?

      start!
    end

    def running?
      # Check if rubocop server is running
      system("#{rubocop_binary} --server-status", out: File::NULL, err: File::NULL)
    end

    def start!
      return if running?

      # Start server in background
      pid = spawn("#{rubocop_binary} --start-server", out: File::NULL, err: File::NULL)
      Process.detach(pid)

      # Wait for server to be ready
      PATIENCE.times do
        break if running?

        sleep SLEEP_TIME
      end

      @started = true
    end

    def stop!
      return unless @started

      system("#{rubocop_binary} --stop-server", out: File::NULL, err: File::NULL)
      @started = false
    end

    private

    def rubocop_binary
      RubocopInteractive.config.rubocop_binary
    end
  end
end
