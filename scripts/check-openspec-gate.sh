#!/usr/bin/env bash
set -euo pipefail

change_id="${1:-}"

if [ -z "$change_id" ]; then
  echo "Usage: scripts/check-openspec-gate.sh <change-id>"
  exit 1
fi

base="openspec/changes/$change_id"

if [ ! -d "$base" ]; then
  echo "OpenSpec change not found: $base"
  exit 1
fi

missing=0

for file in proposal.md design.md tasks.md; do
  if [ ! -f "$base/$file" ]; then
    echo "Missing $base/$file"
    missing=1
  fi
done

if [ ! -d "$base/specs" ]; then
  echo "Missing $base/specs"
  missing=1
fi

if [ "$missing" -ne 0 ]; then
  exit 1
fi

# Archive mode: verify all tasks are marked complete [x]
# Triggered by AIWK_OPENSPEC_MODE=archive (used by /spcrg-archive gate)
if [ "${AIWK_OPENSPEC_MODE:-}" = "archive" ] && [ -f "$base/tasks.md" ]; then
  unchecked=$(grep -c "^- \[ \]" "$base/tasks.md" 2>/dev/null) || unchecked=0
  if [ "$unchecked" -gt 0 ]; then
    echo "BLOCKED: $unchecked unchecked task(s) in $base/tasks.md — all tasks must be [x] before archive"
    exit 1
  fi
fi

echo "OpenSpec gate passed for $change_id"
