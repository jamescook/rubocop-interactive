# frozen_string_literal: true

require 'fileutils'
require 'securerandom'

module RubocopInteractive
  # Manages temp files in project directory
  #
  # We create temp files in the project directory (not system /tmp) because:
  # 1. RuboCop's config lookup walks up from the file's directory. If we used /tmp,
  #    RuboCop wouldn't find the project's .rubocop.yml and would use defaults instead.
  # 2. Supports --debug-preserve-temp flag to keep files for debugging
  #
  # Ruby's built-in Tempfile would auto-delete and use system temp dir, which doesn't work for our needs.
  module TempFile
    TEMP_DIR = '.rubocop-interactive-tmp'

    module_function

    def create(content, extension: '.rb')
      ensure_temp_dir!

      filename = "#{SecureRandom.hex(8)}#{extension}"
      path = File.join(TEMP_DIR, filename)

      File.write(path, content)
      path
    end

    def delete(path)
      File.unlink(path) if File.exist?(path)
    end

    def cleanup!
      FileUtils.rm_rf(TEMP_DIR) if Dir.exist?(TEMP_DIR)
    end

    def ensure_temp_dir!
      FileUtils.mkdir_p(TEMP_DIR) unless Dir.exist?(TEMP_DIR)
    end
  end
end
