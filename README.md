# rubocop-interactive

Interactive RuboCop offense resolution in your terminal. Fix violations one at a time with immediate feedback.

## Demo

![Demo](assets/demo.gif)

## Features

- **Interactive workflow**: Review and fix RuboCop offenses one at a time
- **Live patch preview**: See exactly what will change before applying fixes
- **Bulk corrections**: Fix all remaining instances of a cop with `[L]` command
- **Flexible disabling**: Disable cops per-line or per-file
- **Navigation**: Move between offenses with arrow keys
- **Customizable templates**: Create your own UI templates
- **Fast**: Uses RuboCop's in-process API, no shelling out

## Installation

Add to your project's Gemfile (recommended):

```ruby
gem 'rubocop-interactive'
```

Then run:

```bash
bundle install
bundle exec rubocop-interactive lib/
```

Or install globally:

```bash
gem install rubocop-interactive
```

**Important**: When running on a project that uses RuboCop plugins (like `rubocop-performance` or `rubocop-rails`), you should install `rubocop-interactive` in that project's Gemfile. This ensures all required plugins are available. Running as a global gem on projects with plugins will fail with "cannot load such file" errors.

## Usage

Run on files in your current project:

```bash
bundle exec rubocop-interactive file.rb
bundle exec rubocop-interactive lib/
```

Or pipe from RuboCop:

```bash
rubocop --format json | rubocop-interactive
```

**Note**: When running on files outside your current project (e.g., `../other-project/lib`), the tool may fail if the target project requires RuboCop plugins that aren't in your current Gemfile. In this case, cd into the target project and run the tool from there.

### Commands

- `a` - Autocorrect this offense (safe)
- `A` - Autocorrect this offense (unsafe)
- `p` - Show patch preview
- `L` - Correct ALL remaining instances of this cop
- `s` - Skip this offense
- `d` - Disable cop for this line
- `D` - Disable cop for entire file
- `←/→` - Navigate between offenses
- `q` - Quit
- `?` - Show help

### Options

```bash
--confirm-patch              # Show patch preview before applying
--template NAME              # Use template: default, compact, or path to .erb
--rubocop COMMAND            # Custom RuboCop command
--summary-on-exit [BOOL]     # Show summary on exit (default: false)
```

## Templates

rubocop-interactive supports custom ERB templates. See `lib/templates/` for examples.

Create your own template with access to:
- `offense_number`, `total_offenses`, `cop_name`, `cop_count`
- `message`, `file_path`, `line`, `column`
- `can_autocorrect?`, `can_disable?`, `is_safe_autocorrect?`
- Helpers: `bold()`, `dim()`, `color()`, `separator()`

Use with `--template path/to/template.erb`

## License

MIT License - see [LICENSE](LICENSE) for details.
