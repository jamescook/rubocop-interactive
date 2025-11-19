# frozen_string_literal: true

module RubocopInteractive
  # Manages RuboCop server for fast autocorrection
  class Server
    def initialize
      @started = false
    end

    def ensure_running!
      return if running?

      start!
    end

    def running?
      # Check if rubocop server is running
      system('rubocop --server-status', out: File::NULL, err: File::NULL)
    end

    def start!
      return if running?

      # Start server in background
      pid = spawn('rubocop --start-server', out: File::NULL, err: File::NULL)
      Process.detach(pid)

      # Wait for server to be ready
      10.times do
        break if running?
        sleep 0.1
      end

      @started = true
    end

    def stop!
      return unless @started

      system('rubocop --stop-server', out: File::NULL, err: File::NULL)
      @started = false
    end

    def autocorrect(file:, cop:, line:)
      # Use rubocop to autocorrect just this one offense
      # The --only flag limits to the specific cop
      system(
        'rubocop',
        '--autocorrect',
        '--only', cop,
        file,
        out: File::NULL,
        err: File::NULL
      )
    end
  end
end
