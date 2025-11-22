# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'rubocop-interactive'
  spec.version       = '0.1.0'
  spec.authors       = ['James Cook']
  spec.email         = ['jcook.rubyist@gmail.com']

  spec.summary       = 'Interactive TUI for resolving RuboCop offenses one at a time'
  spec.description   = 'Pipe RuboCop JSON output to interactively review and fix offenses'
  spec.homepage      = 'https://github.com/jamescook/rubocop-interactive'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.files         = Dir['lib/**/*.rb', 'lib/**/*.erb', 'bin/*', 'README.md', 'LICENSE']
  spec.bindir        = 'bin'
  spec.executables   = ['rubocop-interactive']
  spec.require_paths = ['lib']

  spec.add_dependency 'diff-lcs', '~> 1.5'
  spec.add_dependency 'rubocop', '>= 1.72.2'

  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rake', '>= 13.0'
  spec.add_development_dependency 'simplecov', '~> 0.22'
end
