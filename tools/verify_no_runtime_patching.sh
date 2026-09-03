#!/usr/bin/env bash
set -euo pipefail

# CrashVector uses inheritance/composition and explicit services. Replacing a live
# Node's script at runtime would bypass that architecture and makes packaged builds
# substantially harder to reason about.
if grep -RInE --include='*.gd' '\bset_script[[:space:]]*\(' src; then
  echo "Runtime script replacement (set_script) is not allowed in production code." >&2
  exit 1
fi

if grep -RInE --include='*.gd' '\btake_over_path[[:space:]]*\(' src; then
  echo "Runtime Resource path takeover is not allowed in production code." >&2
  exit 1
fi

echo "No runtime monkey-patching patterns found."
