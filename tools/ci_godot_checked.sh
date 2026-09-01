#!/bin/sh
# Fail CI on both process failures and Godot script/compile errors. Godot's
# editor import can otherwise return zero even when a GDScript failed to load.
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
