#!/usr/bin/env bash
set -euo pipefail

change_id="${1:-}"

if [ -z "$change_id" ]; then
  echo "Usage: scripts/check-crg-evidence.sh <change-id>"
  exit 1
fi

base="openspec/changes/$change_id"

if [ ! -d "$base" ]; then
  echo "OpenSpec change not found: $base"
  exit 1
fi

required_files=(
  "$base/proposal.md"
  "$base/design.md"
  "$base/tasks.md"
)

for file in "${required_files[@]}"; do
  if [ ! -f "$file" ]; then
    echo "Missing file: $file"
    exit 1
  fi

  if ! grep -qi "CRG" "$file"; then
    echo "Missing CRG evidence in $file"
    exit 1
  fi
done

required_tools=(
  "get_minimal_context"
  "semantic_search_nodes"
  "query_graph"
  "get_impact_radius"
)

for tool in "${required_tools[@]}"; do
  if ! grep -R -q "$tool" "$base"; then
    echo "Missing required CRG tool evidence: $tool"
    exit 1
  fi
done

echo "CRG evidence baseline found for $change_id"
