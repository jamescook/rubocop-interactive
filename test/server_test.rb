# frozen_string_literal: true

require_relative 'test_helper'

class ServerTest < Minitest::Test
  def setup
    # Point to our fake rubocop for testing
    @original_binary = RubocopInteractive.config.rubocop_binary
    RubocopInteractive.config.rubocop_binary = File.expand_path('bin/fake-rubocop', __dir__)
  end

  def teardown
    # Restore original config
    RubocopInteractive.config.rubocop_binary = @original_binary
  end

  def test_running_checks_server_status
    server = RubocopInteractive::Server.new

    # Should call fake-rubocop --server-status, which exits 0
    assert server.running?
  end

  def test_ensure_running_starts_server_if_not_running
    server = RubocopInteractive::Server.new

    # Mock running? to return false first, then true
    def server.running?
      @running_call_count ||= 0
      @running_call_count += 1
      @running_call_count > 1
    end

    server.ensure_running!
    # Should have called start! which waits for running? to return true
  end

  def test_stop_calls_stop_server
    server = RubocopInteractive::Server.new
    server.instance_variable_set(:@started, true)

    # Should call fake-rubocop --stop-server
    server.stop!

    refute server.instance_variable_get(:@started)
  end

  def test_uses_configured_rubocop_binary
    server = RubocopInteractive::Server.new

    # Verify it's using our fake binary
    assert_equal File.expand_path('bin/fake-rubocop', __dir__),
                 server.send(:rubocop_binary)
  end
end
