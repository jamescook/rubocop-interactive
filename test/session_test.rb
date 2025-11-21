# frozen_string_literal: true

require_relative 'test_helper'

class SessionTest < Minitest::Test

  def test_parses_offenses_from_json
    ui = FakeUI.new

    session = RubocopInteractive::Session.new(fixture_json, ui: ui)

    assert_equal 17, session.offenses.size
    assert_equal 'Style/StringLiterals', session.offenses.first.cop_name
  end

  def test_runs_through_all_offenses
    # Use skip to progress through all offenses without modifying files
    responses = Array.new(17, :skip)
    ui = FakeUI.new(responses: responses)

    session = RubocopInteractive::Session.new(fixture_json, ui: ui)
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

      session = RubocopInteractive::Session.new(json_data, ui: ui)
      stats = session.run

      assert stats[:corrected] >= 1, "Should have corrected at least 1 offense"
    end
  end

  def test_quit_stops_early
    responses = [:skip, :skip, :quit]
    ui = FakeUI.new(responses: responses)

    session = RubocopInteractive::Session.new(fixture_json, ui: ui)
    session.run

    assert_equal 3, ui.prompts_shown # Only 3 prompts before quit
  end

  def test_next_navigates_forward
    responses = [:next, :next, :quit]
    ui = FakeUI.new(responses: responses)

    session = RubocopInteractive::Session.new(fixture_json, ui: ui)
    session.run

    # Should show offense 1, then 2, then 3
    assert_equal 3, ui.offenses_shown.size
    assert_equal 'Style/StringLiterals', ui.offenses_shown[0].cop_name
  end

  def test_next_at_end_beeps_and_stays
    # Navigate to near the end, then try to go past
    responses = Array.new(16, :skip) + [:next, :quit]
    ui = FakeUI.new(responses: responses)

    session = RubocopInteractive::Session.new(fixture_json, ui: ui)
    session.run

    # Should show 17 offenses + 1 more prompt after beeping at boundary
    assert_equal 18, ui.prompts_shown
  end

  def test_prev_navigates_backward
    responses = [:next, :next, :prev, :quit]
    ui = FakeUI.new(responses: responses)

    session = RubocopInteractive::Session.new(fixture_json, ui: ui)
    session.run

    # Should show: offense 1, offense 2, offense 3, offense 2 again
    assert_equal 4, ui.offenses_shown.size
  end

  def test_prev_at_start_beeps_and_stays
    responses = [:prev, :quit]
    ui = FakeUI.new(responses: responses)

    session = RubocopInteractive::Session.new(fixture_json, ui: ui)
    session.run

    # Should show offense 1 twice (once initially, once after beeping)
    assert_equal 2, ui.prompts_shown
  end

  def test_open_editor_with_valid_editor
    # Mock editor launcher
    editor_launcher = Object.new
    def editor_launcher.launch(_file, _line)
      true
    end

    responses = [:open_editor, :quit]
    ui = FakeUI.new(responses: responses)

    session = RubocopInteractive::Session.new(fixture_json, ui: ui, editor_launcher: editor_launcher)
    session.run

    # Should have prompted twice (once for open_editor, once for quit)
    assert_equal 2, ui.prompts_shown
  end

  def test_open_editor_without_editor_shows_error
    # Mock editor launcher that returns false
    editor_launcher = Object.new
    def editor_launcher.launch(_file, _line)
      false
    end
    def editor_launcher.error
      :no_editor
    end

    error_shown = false
    ui = FakeUI.new(responses: [:open_editor, :quit])
    ui.define_singleton_method(:show_no_editor_error) do
      error_shown = true
    end

    session = RubocopInteractive::Session.new(fixture_json, ui: ui, editor_launcher: editor_launcher)
    session.run

    assert error_shown, "Should have shown no editor error"
    assert_equal 2, ui.prompts_shown
  end
end
