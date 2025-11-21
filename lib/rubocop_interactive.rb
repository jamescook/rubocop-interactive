# frozen_string_literal: true

require 'json'
require_relative 'rubocop_interactive/config'
require_relative 'rubocop_interactive/ansi'
require_relative 'rubocop_interactive/color'
require_relative 'rubocop_interactive/noop_colorizer'
require_relative 'rubocop_interactive/cop_config'
require_relative 'rubocop_interactive/offense'
require_relative 'rubocop_interactive/session'
require_relative 'rubocop_interactive/actions'
require_relative 'rubocop_interactive/ui'
require_relative 'rubocop_interactive/server'
require_relative 'rubocop_interactive/patch_generator'
require_relative 'rubocop_interactive/template_context'
require_relative 'rubocop_interactive/template_renderer'
require_relative 'rubocop_interactive/temp_file'

module RubocopInteractive
  class Error < StandardError; end

  def self.start!(json, ui: nil, confirm_patch: false, template: 'default')
    ui ||= UI.new(confirm_patch: confirm_patch, template: template)

    server = Server.new
    server.ensure_running!

    session = Session.new(json, ui: ui, server: server)
    session.run
  ensure
    TempFile.cleanup!
  end
end
