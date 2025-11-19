# frozen_string_literal: true

require 'erb'

module RubocopInteractive
  # Renders ERB templates with a given context
  class TemplateRenderer
    DEFAULT_TEMPLATES_PATH = File.expand_path('../templates', __dir__)
    USER_TEMPLATES_PATH = File.expand_path('~/.config/rubocop-interactive/templates')

    def initialize(template_name: 'default')
      @template_name = template_name
      @template = load_template
    end

    def render(context)
      @template.result(context.binding_for_erb)
    end

    private

    def load_template
      path = find_template_path
      raise Error, "Template not found: #{@template_name}" unless path

      ERB.new(File.read(path), trim_mode: '-')
    end

    def find_template_path
      # Check if it's an absolute path
      return @template_name if File.exist?(@template_name)

      # Check user templates first
      user_path = File.join(USER_TEMPLATES_PATH, "#{@template_name}.erb")
      return user_path if File.exist?(user_path)

      # Fall back to built-in templates
      default_path = File.join(DEFAULT_TEMPLATES_PATH, "#{@template_name}.erb")
      return default_path if File.exist?(default_path)

      nil
    end
  end
end
