#!/bin/sh
# Fake editor for E2E testing
# Records invocations to a log file and exits immediately

LOG_FILE="${FAKE_EDITOR_LOG:-/tmp/fake_editor.log}"

# Append invocation to log
echo "$@" >> "$LOG_FILE"

# Exit successfully
exit 0
