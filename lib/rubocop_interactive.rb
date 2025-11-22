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

  def self.start!(input, ui: nil, confirm_patch: false, template: 'default', summary_on_exit: false, record_keypresses: false)
    # Create UI if not provided
    ui ||= UI.new(confirm_patch: confirm_patch, template: template, summary_on_exit: summary_on_exit, record_keypresses: record_keypresses)

    # Convert input to JSON string based on type
    json_string = case input
                  when Array
                    # Array of file paths
                    ui.show_loading(source: :files, files: input)
                    run_rubocop_on_files(input)
                  when Hash
                    # Already parsed JSON - convert back to string
                    JSON.generate(input)
                  when String
                    # Raw JSON string
                    input
                  else
                    # IO-like object (IO, StringIO, File, etc) - must have #read method
                    if input.respond_to?(:read)
                      ui.show_loading(source: :stdin)
                      input.read
                    else
                      raise ArgumentError, "input must be IO-like (with #read), Array (files), Hash (parsed JSON), or String (JSON)"
                    end
                  end

    session = Session.new(json_string, ui: ui)
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
