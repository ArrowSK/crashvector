#!/usr/bin/env sh
set -eu

scan_regex() {
  grep -RInE --include='*.gd' --include='*.tscn' "$1" src app 2>/dev/null || true
}

scan_fixed() {
  grep -RInF --include='*.gd' --include='*.tscn' "$1" src app 2>/dev/null || true
}

matches="$(
  scan_regex 'set_script[[:space:]]*\('
  scan_regex 'take_over_path[[:space:]]*\('
  scan_regex '\.[[:space:]]*script[[:space:]]*='
  scan_fixed 'set("script"'
  scan_fixed "set('script'"
)"

if [ -n "$matches" ]; then
  echo "Runtime script/resource monkey-patching is prohibited in production code:" >&2
  echo "$matches" >&2
  exit 1
fi

echo "CrashVector architecture audit passed: no prohibited runtime monkey-patching patterns found."
