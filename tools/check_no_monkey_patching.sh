#!/usr/bin/env sh
set -eu

ROOTS="src app"
PATTERNS='set_script[[:space:]]*\(|take_over_path[[:space:]]*\(|\.[[:space:]]*script[[:space:]]*=|set[[:space:]]*\([[:space:]]*["'"']script["'"']'

matches="$(grep -RInE --include='*.gd' --include='*.tscn' "$PATTERNS" $ROOTS 2>/dev/null || true)"
if [ -n "$matches" ]; then
  echo "Runtime script/resource monkey-patching is prohibited in production code:" >&2
  echo "$matches" >&2
  exit 1
fi

echo "CrashVector architecture audit passed: no prohibited runtime monkey-patching patterns found."
