#!/usr/bin/env bash
#
# check-command-protocols.sh — verifies that .claude/commands/*.md files
# contain V5 protocol keywords, preventing accidental installation of V1 commands.
#
# Usage:
#   scripts/check-command-protocols.sh [command-directory]
#   Default command-directory: .claude/commands
#
# Exit 0 if all checks pass, non-zero otherwise.

set -euo pipefail

cmd_dir="${1:-.claude/commands}"

pass=0
fail=0

check() {
  local file="$1"
  local keyword="$2"
  local label="$3"

  if [ ! -f "$file" ]; then
    printf "CHECK: %-55s FAIL (file not found)\n" "$label"
    fail=$((fail + 1))
    return
  fi

  if grep -qF "$keyword" "$file"; then
    printf "CHECK: %-55s PASS\n" "$label"
    pass=$((pass + 1))
  else
    printf "CHECK: %-55s FAIL\n" "$label"
    fail=$((fail + 1))
  fi
}

# ---------------------------------------------------------------------------
# spcrg-start.md
# ---------------------------------------------------------------------------
f="$cmd_dir/spcrg-start.md"
check "$f" "CRG Discovery Protocol"  "spcrg-start contains 'CRG Discovery Protocol'"
check "$f" "Read Before Decide"       "spcrg-start contains 'Read Before Decide'"
check "$f" "## CRG Discovery"         "spcrg-start contains '## CRG Discovery'"

# ---------------------------------------------------------------------------
# spcrg-plan.md
# ---------------------------------------------------------------------------
f="$cmd_dir/spcrg-plan.md"
check "$f" "CRG Precision Mapping Protocol"  "spcrg-plan contains 'CRG Precision Mapping Protocol'"
check "$f" "superpowers:writing-plans"        "spcrg-plan contains 'superpowers:writing-plans'"
check "$f" "## CRG Precision Plan"            "spcrg-plan contains '## CRG Precision Plan'"

# ---------------------------------------------------------------------------
# spcrg-dev.md
# ---------------------------------------------------------------------------
f="$cmd_dir/spcrg-dev.md"
check "$f" "Delta Check Protocol"            "spcrg-dev contains 'Delta Check Protocol'"
check "$f" "CRG Post-Phase Verification"     "spcrg-dev contains 'CRG Post-Phase Verification'"
check "$f" "PASS | BLOCKING | NEEDS_HUMAN_DECISION" \
           "spcrg-dev contains 'PASS | BLOCKING | NEEDS_HUMAN_DECISION'"

# ---------------------------------------------------------------------------
# spcrg-review.md
# ---------------------------------------------------------------------------
f="$cmd_dir/spcrg-review.md"
check "$f" "CRG Quantified Review"  "spcrg-review contains 'CRG Quantified Review'"
check "$f" "scope_drift"            "spcrg-review contains 'scope_drift'"
check "$f" "archive_ready"          "spcrg-review contains 'archive_ready'"

# ---------------------------------------------------------------------------
# spcrg-archive.md
# ---------------------------------------------------------------------------
f="$cmd_dir/spcrg-archive.md"
check "$f" "check-v5-review.sh"  "spcrg-archive contains 'check-v5-review.sh'"
check "$f" "/opsx:verify"        "spcrg-archive contains '/opsx:verify'"

# ---------------------------------------------------------------------------
# spcrg-audit.md
# ---------------------------------------------------------------------------
f="$cmd_dir/spcrg-audit.md"
check "$f" "structured evidence"  "spcrg-audit contains 'structured evidence'"
check "$f" "Code Reading Summary" "spcrg-audit contains 'Code Reading Summary'"
check "$f" "Precision Plan"       "spcrg-audit contains 'Precision Plan'"

# ---------------------------------------------------------------------------
# Gated commands must all embed both gate scripts
# ---------------------------------------------------------------------------
gated_files=(
  "$cmd_dir/spcrg-plan.md"
  "$cmd_dir/spcrg-dev.md"
  "$cmd_dir/spcrg-review.md"
  "$cmd_dir/spcrg-archive.md"
  "$cmd_dir/spcrg-audit.md"
)
gated_names=(
  "spcrg-plan"
  "spcrg-dev"
  "spcrg-review"
  "spcrg-archive"
  "spcrg-audit"
)

i=0
while [ $i -lt ${#gated_files[@]} ]; do
  gf="${gated_files[$i]}"
  gn="${gated_names[$i]}"
  check "$gf" "check-openspec-gate.sh"  "$gn contains 'check-openspec-gate.sh'"
  check "$gf" "check-crg-evidence.sh"   "$gn contains 'check-crg-evidence.sh'"
  i=$((i + 1))
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
total=$((pass + fail))
echo ""
echo "SUMMARY: $total checks, $pass passed, $fail failed"

if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
