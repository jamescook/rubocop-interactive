# frozen_string_literal: true

# Fake UI for testing - returns predetermined responses
class FakeUI
  attr_reader :prompts_shown, :offenses_shown

  def initialize(responses: [])
    @responses = responses.dup
    @prompts_shown = 0
    @offenses_shown = []
  end

  def show_loading(source:, files: nil)
    # no-op
  end

  def show_summary(total:)
    # no-op
  end

  def show_offense(offense, **_)
    @offenses_shown << offense
  end

  def update_offense_state(offense, **_)
    # Track that we updated the state (for testing purposes, just track like show_offense)
    @offenses_shown << offense
  end

  def prompt_for_action(_offense, **_)
    @prompts_shown += 1
    action = @responses.shift || :skip

    # If action is correct_all, consume the next response as confirmation
    if action == :correct_all
      confirmation = @responses.shift
      # If confirmation is not yes, return skip instead
      return :skip unless confirmation == :confirm_yes
    end

    action
  end

  def show_stats(_stats)
    # no-op
  end

  def beep
    # no-op
  end

  def beeped?
    false
  end
end
