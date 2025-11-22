# frozen_string_literal: true

require 'json'
require 'diff/lcs'
require_relative 'rubocop_interactive/config'
require_relative 'rubocop_interactive/color'
require_relative 'rubocop_interactive/noop_colorizer'
require_relative 'rubocop_interactive/cop_config'
require_relative 'rubocop_interactive/offense'
require_relative 'rubocop_interactive/session'
require_relative 'rubocop_interactive/actions'
require_relative 'rubocop_interactive/ui'
require_relative 'rubocop_interactive/patch_generator'
require_relative 'rubocop_interactive/patch_renderer'
require_relative 'rubocop_interactive/template_context'
require_relative 'rubocop_interactive/template_renderer'
require_relative 'rubocop_interactive/temp_file'
require_relative 'rubocop_interactive/editor_launcher'

module RubocopInteractive
  class Error < StandardError; end

  def self.start_with_stdin!(confirm_patch: false, template: 'default', summary_on_exit: false, record_keypresses: false)
    ui = UI.new(confirm_patch: confirm_patch, template: template, summary_on_exit: summary_on_exit, record_keypresses: record_keypresses)
    ui.show_loading(source: :stdin)

    json = $stdin.read

    start!(json, ui: ui, confirm_patch: confirm_patch, template: template, summary_on_exit: summary_on_exit, record_keypresses: record_keypresses)
  end

  def self.start_with_files!(files, confirm_patch: false, template: 'default', summary_on_exit: false, record_keypresses: false)
    ui = UI.new(confirm_patch: confirm_patch, template: template, summary_on_exit: summary_on_exit, record_keypresses: record_keypresses)
    ui.show_loading(source: :files, files: files)

    json = run_rubocop_on_files(files)

    start!(json, ui: ui, confirm_patch: confirm_patch, template: template, summary_on_exit: summary_on_exit, record_keypresses: record_keypresses)
  end

  def self.start!(json, ui: nil, confirm_patch: false, template: 'default', summary_on_exit: false, record_keypresses: false)
    ui ||= UI.new(confirm_patch: confirm_patch, template: template, summary_on_exit: summary_on_exit, record_keypresses: record_keypresses)

    session = Session.new(json, ui: ui)
    stats = session.run

    # Write keypress recording if enabled
    if record_keypresses && ui.recording_input
      write_keypress_log(ui.recording_input.keypresses)
    end

    stats
  ensure
    TempFile.cleanup!
  end

  def self.run_rubocop_on_files(files)
    require 'rubocop'
    require 'stringio'

    output = StringIO.new
    old_stdout = $stdout
    old_stderr = $stderr
    $stdout = output
    $stderr = StringIO.new

    begin
      cli = RuboCop::CLI.new
      cli.run(['--format', 'json', '--cache', 'false'] + files)
    ensure
      $stdout = old_stdout
      $stderr = old_stderr
    end

    output.string
  end

  def self.write_keypress_log(keypresses)
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    filename = "keystroke_record_#{timestamp}.log"

    File.write(filename, keypresses.join)
    puts "\nRecorded #{keypresses.size} keypresses to: #{filename}"
  end
end
