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

echo "OpenSpec gate passed for $change_id"
