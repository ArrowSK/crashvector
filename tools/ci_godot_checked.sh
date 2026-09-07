#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "usage: $0 <command> [args...]" >&2
  exit 64
fi

# Kenney Car Kit is pinned as a submodule. GitHub checkout intentionally stays
# lightweight, so initialise it on demand before any Godot command that can
# parse/load the production presentation assets.
if [[ ! -f third_party/kenney_car_kit/License.txt ]] && [[ -f .gitmodules ]]; then
  git submodule update --init --recursive third_party/kenney_car_kit
fi

# Godot 4.4.1 can abort the filesystem scan/import when an editor invocation is
# told to --quit immediately. That left freshly checked-out GLB submodule assets
# present on disk but unavailable through ResourceLoader in the following test.
# For the canonical CI import invocation, use --import instead: Godot starts the
# editor import pipeline, waits for resource import to finish, then exits.
args=("$@")
if [[ "${args[0]}" == "godot" ]]; then
  has_editor=0
  has_quit=0
  for arg in "${args[@]}"; do
    [[ "$arg" == "--editor" ]] && has_editor=1
    [[ "$arg" == "--quit" ]] && has_quit=1
  done
  if [[ $has_editor -eq 1 && $has_quit -eq 1 ]]; then
    rewritten=()
    for arg in "${args[@]}"; do
      [[ "$arg" == "--editor" || "$arg" == "--quit" ]] && continue
      rewritten+=("$arg")
    done
    rewritten+=("--import")
    args=("${rewritten[@]}")
  fi
fi

log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT

set +e
"${args[@]}" 2>&1 | tee "$log_file"
status=${PIPESTATUS[0]}
set -e

if [[ $status -ne 0 ]]; then
  exit "$status"
fi

# Godot can return zero while still reporting script/parser/runtime failures.
# Treat these as hard CI failures, while leaving ordinary WARNING lines alone.
if grep -E -q 'SCRIPT ERROR:|Parse Error:|Parser Error:|Failed to load script|Cannot get class|TEST FAILURE:' "$log_file"; then
  echo "Godot reported a script/parser/runtime failure despite exit code 0." >&2
  exit 1
fi
