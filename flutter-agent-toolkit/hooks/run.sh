#!/usr/bin/env bash
# Runs the hook engine: the compiled exe when available (~0.1s), otherwise
# the Dart script (~1s). Usage: run.sh <session-start|post-edit|stop>
mode="$1"
exe="${CLAUDE_PLUGIN_DATA}/toolkit.exe"
if [ -n "${CLAUDE_PLUGIN_DATA}" ] && [ -x "$exe" ]; then
  exec "$exe" "$mode"
elif command -v dart >/dev/null 2>&1; then
  exec dart "$(dirname "$0")/toolkit.dart" "$mode"
elif [ "$mode" = session-start ] && [ -f pubspec.yaml ]; then
  echo "flutter-agent-toolkit: 'dart' is not on PATH, so Flutter checks are off. Tell the user to add their Flutter SDK bin folder to PATH."
fi
