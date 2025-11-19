# frozen_string_literal: true

require 'json'
require_relative 'rubocop_interactive/offense'
require_relative 'rubocop_interactive/session'
require_relative 'rubocop_interactive/actions'
require_relative 'rubocop_interactive/ui'
require_relative 'rubocop_interactive/server'

module RubocopInteractive
  class Error < StandardError; end

  def self.start!(json, ui: UI.new)
    server = Server.new
    server.ensure_running!

    session = Session.new(json, ui: ui, server: server)
    session.run
  end
end
