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

    def create(content, extension: '.rb', basename: nil)
      if basename
        # Create isolated directory to preserve original filename (for cops checking patterns)
        # e.g., "actions_test.rb" stays as "actions_test.rb" in its own temp dir
        subdir = File.join(TEMP_DIR, SecureRandom.hex(8))
        FileUtils.mkdir_p(subdir)

        # Copy .rubocop.yml to temp dir so RuboCop uses project config
        # RuboCop walks up from the file's directory to find config.
        # Without this, it won't load plugins (like rubocop-minitest) or project settings,
        # causing cops to either not run (e.g., Minitest/EmptyLineBeforeAssertionMethods)
        # or use incorrect defaults.
        if File.exist?('.rubocop.yml')
          FileUtils.cp('.rubocop.yml', subdir)
        end

        filename = "#{basename}#{extension}"
        path = File.join(subdir, filename)
      else
        ensure_temp_dir!
        filename = "#{SecureRandom.hex(8)}#{extension}"
        path = File.join(TEMP_DIR, filename)
      end

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
