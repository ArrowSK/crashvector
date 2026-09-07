#!/bin/sh
# Fail CI on both process failures and Godot script/compile errors. Godot's
# editor import can otherwise return zero even when a GDScript failed to load.
#
# The Kenney Car Kit is a pinned public submodule. CI intentionally initialises
# it here rather than allowing presentation tests to fall back to the historical
# procedural skin and report a false green result.
set -eu
if [ -f .gitmodules ] && [ ! -f "third_party/kenney_car_kit/License.txt" ]; then
  git submodule sync --recursive
  git submodule update --init --recursive
fi
if [ -f .gitmodules ] && [ ! -f "third_party/kenney_car_kit/License.txt" ]; then
  echo "CrashVector CI could not initialise the pinned Kenney Car Kit assets." >&2
  exit 1
fi

set +e
output="$($@ 2>&1)"
status=$?
printf '%s\n' "$output"
if [ "$status" -ne 0 ]; then
  exit "$status"
fi
if printf '%s\n' "$output" | grep -Eq 'SCRIPT ERROR:|ERROR: Failed to load script'; then
  echo "CrashVector CI detected a Godot script error." >&2
  exit 1
fi
exit 0
