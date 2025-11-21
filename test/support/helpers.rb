# frozen_string_literal: true

# Global test helper methods

FIXTURES_PATH = File.expand_path('../fixtures', __dir__)

def fixture_json
  File.read(File.join(FIXTURES_PATH, 'rubocop_output.json'))
end

def fixture_project_path
  File.join(FIXTURES_PATH, 'sample_project')
end

# Create a temp copy of the fixture for tests that modify files
def with_temp_fixture
  Dir.mktmpdir do |dir|
    FileUtils.cp_r(Dir.glob("#{fixture_project_path}/*"), dir)
    yield dir
  end
end

# Set COLORTERM for the duration of a block, restoring original value
def with_colorterm(value)
  original = ENV['COLORTERM']
  if value.nil?
    ENV.delete('COLORTERM')
  else
    ENV['COLORTERM'] = value
  end
  yield
ensure
  if original
    ENV['COLORTERM'] = original
  else
    ENV.delete('COLORTERM')
  end
end
