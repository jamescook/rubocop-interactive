# frozen_string_literal: true

require_relative 'test_helper'

class SessionTest < Minitest::Test

  def test_parses_offenses_from_json
    ui = FakeUI.new
    server = FakeServer.new

    session = RubocopInteractive::Session.new(fixture_json, ui: ui, server: server)

    assert_equal 17, session.offenses.size
    assert_equal 'Style/StringLiterals', session.offenses.first.cop_name
  end

  def test_runs_through_all_offenses
    # Use skip to progress through all offenses without modifying files
    responses = Array.new(17, :skip)
    ui = FakeUI.new(responses: responses)
    server = FakeServer.new

    session = RubocopInteractive::Session.new(fixture_json, ui: ui, server: server)
    session.run

    assert_equal 17, ui.prompts_shown
  end

  def test_tracks_autocorrect_stats
    with_temp_fixture do |dir|
      # Update fixture JSON to use temp dir paths
      json_data = JSON.parse(fixture_json)
      json_data['files'].each do |file|
        file['path'] = File.join(dir, File.basename(file['path']))
      end

      # Try to autocorrect, then skip remaining
      # With single-offense correction, counts may vary due to rescanning
      responses = [:autocorrect] + Array.new(50, :skip)
      ui = FakeUI.new(responses: responses)
      server = FakeServer.new

      session = RubocopInteractive::Session.new(json_data, ui: ui, server: server)
      stats = session.run

      assert stats[:corrected] >= 1, "Should have corrected at least 1 offense"
    end
  end

  def test_quit_stops_early
    responses = [:skip, :skip, :quit]
    ui = FakeUI.new(responses: responses)
    server = FakeServer.new

    session = RubocopInteractive::Session.new(fixture_json, ui: ui, server: server)
    session.run

    assert_equal 3, ui.prompts_shown # Only 3 prompts before quit
  end
end
