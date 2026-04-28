#!/usr/bin/env bash
set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
fixtures="$root/tests/fixtures"

if [ ! -d "$fixtures" ]; then
  echo "No fixtures directory at $fixtures"
  exit 1
fi

pass=0
fail=0
failed_cases=()

for case_dir in "$fixtures"/*/; do
  [ -d "$case_dir/change" ] || continue
  case_name=$(basename "$case_dir")

  if [[ "$case_name" == good-* ]]; then
    expected_exit=0
  elif [[ "$case_name" == bad-* ]]; then
    expected_exit=1
  else
    continue
  fi

  if [[ "$case_name" == *quantified-review* ]]; then
    script="$root/scripts/check-v5-review.sh"
  else
    script="$root/scripts/check-crg-evidence.sh"
  fi

  if [ ! -f "$script" ]; then
    echo "  SKIP  $case_name (script not found: $(basename "$script"))"
    continue
  fi

  workdir=$(mktemp -d)
  mkdir -p "$workdir/openspec/changes/$case_name"
  cp -r "$case_dir/change/"* "$workdir/openspec/changes/$case_name/"
  mkdir -p "$workdir/.ai-workflow-kit"
  cp "$fixtures/config.json" "$workdir/.ai-workflow-kit/config.json"

  if [[ "$case_name" == good-discovery-minimal ]]; then
    output=$(cd "$workdir" && AIWK_CHECK_CRG_MODE=shape-only "$script" "$case_name" 2>&1) || true
  else
    output=$(cd "$workdir" && "$script" "$case_name" 2>&1) || true
  fi
  actual_exit=$?

  rm -rf "$workdir"

  if [ "$actual_exit" -eq 0 ] && [ "$expected_exit" -eq 0 ]; then
    printf "  \033[32mPASS\033[0m  %s\n" "$case_name"
    pass=$((pass + 1))
  elif [ "$actual_exit" -ne 0 ] && [ "$expected_exit" -ne 0 ]; then
    printf "  \033[32mPASS\033[0m  %s\n" "$case_name"
    pass=$((pass + 1))
  else
    printf "  \033[31mFAIL\033[0m  %s (expected exit %d, got %d)\n" "$case_name" "$expected_exit" "$actual_exit"
    fail=$((fail + 1))
    failed_cases+=("$case_name")
  fi
done

echo ""
echo "Results: $((pass + fail)) tests, $pass passed, $fail failed"

if [ "$fail" -gt 0 ]; then
  echo "Failed:"
  for c in "${failed_cases[@]}"; do echo "  - $c"; done
  exit 1
fi
