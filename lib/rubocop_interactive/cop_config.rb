# frozen_string_literal: true

require 'rubocop'

module RubocopInteractive
  # Caches RuboCop cop configuration for safety checks
  module CopConfig
    class << self
      def safe_autocorrect?(cop_name)
        cache[cop_name] ||= compute_safe_autocorrect(cop_name)
      end

      def reset!
        @cache = nil
        @config = nil
      end

      private

      def cache
        @cache ||= {}
      end

      def config
        @config ||= begin
          config_store = RuboCop::ConfigStore.new
          config_store.for_pwd
        end
      end

      def compute_safe_autocorrect(cop_name)
        cop_config = config.for_cop(cop_name)
        safe = cop_config.fetch('Safe', true)
        safe_autocorrect = cop_config.fetch('SafeAutoCorrect', true)
        safe && safe_autocorrect
      end
    end
  end
end
