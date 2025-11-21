# frozen_string_literal: true

require 'shellwords'

module RubocopInteractive
  # Launches an external editor to view/edit a file at a specific line
  class EditorLauncher
    attr_reader :error

    def launch(file_path, line_number)
      editor = ENV['EDITOR']

      unless editor
        @error = :no_editor
        return false
      end

      command = build_command(editor, file_path, line_number)
      system(command)
    end

    private

    def build_command(editor, file_path, line_number)
      escaped_path = Shellwords.escape(file_path)

      case editor
      when /n?vim$/
        "#{editor} +#{line_number} #{escaped_path}"
      else
        # Fallback: open without line number for unknown editors
        "#{editor} #{escaped_path}"
      end
    end
  end
end
