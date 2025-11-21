# frozen_string_literal: true

require_relative 'test_helper'

class TemplateRendererTest < Minitest::Test
  def setup
    @context = RubocopInteractive::TemplateContext.new(
      total_offenses: 10,
      offense_number: 3,
      cop_name: 'Layout/SpaceAroundOperators',
      message: 'Missing space around operator',
      file_path: 'test.rb',
      line: 42,
      column: 10,
      correctable: true,
      safe_autocorrect: true,
      state: :pending,
      colorizer: RubocopInteractive::NoopColorizer,
      patch_lines: ["-  x=1\n", "+  x = 1\n"]
    )
  end

  def test_renders_default_template
    renderer = RubocopInteractive::TemplateRenderer.new(template_name: 'default')
    output = renderer.render(@context)

    assert_includes output, '[3/10]'
    assert_includes output, 'Layout/SpaceAroundOperators'
    assert_includes output, 'Missing space around operator'
    assert_includes output, 'test.rb:42:10'
    assert_includes output, '[a]pply'
  end

  def test_renders_compact_template
    renderer = RubocopInteractive::TemplateRenderer.new(template_name: 'compact')
    output = renderer.render(@context)

    assert_includes output, '[3/10]'
    assert_includes output, 'Layout/SpaceAroundOperators'
    assert_includes output, 'test.rb:42:10'
  end

  def test_raises_for_missing_template
    assert_raises RubocopInteractive::Error do
      RubocopInteractive::TemplateRenderer.new(template_name: 'nonexistent')
    end
  end
end
