# frozen_string_literal: true

require 'fileutils'
require 'securerandom'

module RubocopInteractive
  # Manages temp files in project directory for rubocop server compatibility
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
