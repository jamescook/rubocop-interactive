# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-01-24

### Added
- Initial release
- Interactive TUI for reviewing and fixing RuboCop offenses one at a time
- Patch preview with syntax-highlighted diffs
- Safe/unsafe autocorrect support with visual indicators
- Bulk correction for all instances of a cop
- Navigation between offenses with arrow keys
- Inline disable comments (line and file-level)
- Context-aware source highlighting with caret indicators
- Deterministic cop name coloring
- State tracking for offenses (skipped, corrected, disabled)
- Support for trailing whitespace visualization
- Blank line offense context display
- Template system for customizable output
- X11 color support with 256-color and truecolor fallback

[0.1.0]: https://github.com/jamescook/rubocop-interactive/releases/tag/v0.1.0
