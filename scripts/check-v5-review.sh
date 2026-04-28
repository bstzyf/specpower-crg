#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# check-v5-review.sh — V5 CRG Quantified Review validation
#
# Usage: check-v5-review.sh <change-id>
#
# Validates the ## CRG Quantified Review section in a change's design.md
# (or review.md).
# =============================================================================

change_id="${1:-}"

if [ -z "$change_id" ]; then
  echo "Usage: scripts/check-v5-review.sh <change-id>"
  exit 1
fi

base="openspec/changes/$change_id"

if [ ! -d "$base" ]; then
  echo "OpenSpec change not found: $base"
  exit 1
fi

# Locate review file: design.md first, then review.md
review_file=""
if [ -f "$base/design.md" ]; then
  if grep -q "^## CRG Quantified Review" "$base/design.md" 2>/dev/null; then
    review_file="$base/design.md"
  fi
fi
if [ -z "$review_file" ] && [ -f "$base/review.md" ]; then
  if grep -q "^## CRG Quantified Review" "$base/review.md" 2>/dev/null; then
    review_file="$base/review.md"
  fi
fi
# Fallback: pick whichever exists so we can report "section not found"
if [ -z "$review_file" ]; then
  if [ -f "$base/design.md" ]; then
    review_file="$base/design.md"
  elif [ -f "$base/review.md" ]; then
    review_file="$base/review.md"
  fi
fi

# =============================================================================
# Config reader (same pattern as check-crg-evidence.sh)
# =============================================================================
_read_config() {
  local key="$1" default="$2" config=".ai-workflow-kit/config.json"
  if [ ! -f "$config" ]; then echo "$default"; return; fi
  if command -v jq &>/dev/null; then
    local val
    val=$(jq -r "$key // empty" "$config" 2>/dev/null)
    [ -n "$val" ] && echo "$val" || echo "$default"
  elif command -v python3 &>/dev/null; then
    local val
    val=$(python3 -c "
import json
try:
  c=json.load(open('$config'))
  keys='$key'.lstrip('.').split('.')
  v=c
  for k in keys: v=v[k]
  print(v)
except:
  pass
" 2>/dev/null)
    [ -n "$val" ] && echo "$val" || echo "$default"
  else
    echo "$default"
  fi
}

# Load thresholds
SCOPE_DRIFT_THRESHOLD=$(_read_config ".thresholds.scopeDriftPercent" "20")
COVERAGE_THRESHOLD=$(_read_config ".thresholds.changedSymbolTestCoveragePercent" "80")
REQUIRE_E2E=$(_read_config ".gates.requireE2EForAffectedFlows" "true")

# =============================================================================
# Check tracking
# =============================================================================
PASS_COUNT=0
FAIL_COUNT=0

_pass() {
  local desc="$1"
  printf "CHECK: %-65s PASS\n" "$desc"
  PASS_COUNT=$((PASS_COUNT + 1))
}

_fail() {
  local desc="$1" reason="$2"
  printf "CHECK: %-65s FAIL (%s)\n" "$desc" "$reason"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

# =============================================================================
# Markdown helpers
# =============================================================================

# Extract content of a level-2 section (## Heading) from a file
_extract_h2_section() {
  local file="$1" heading="$2"
  awk -v h="## $heading" '
    found && /^## / { exit }
    found { print }
    $0 == h { found=1 }
  ' "$file"
}

# Check whether a ## heading exists in a file
_has_h2() {
  local file="$1" heading="$2"
  grep -q "^## $heading" "$file" 2>/dev/null
}

# Check whether a ### sub-heading exists within a block of text (stdin)
_has_h3_in_block() {
  local heading="$1"
  grep -q "^### $heading"
}

# Extract content of a level-3 section within a block of text (stdin)
_extract_h3_section() {
  local heading="$1"
  awk -v h="### $heading" '
    found && /^### / { exit }
    found { print }
    $0 == h { found=1 }
  '
}

# Get a field value from a block of text (- field_name: value)
_get_field() {
  local field="$1"
  grep -E "^-?\s*${field}:" | head -1 | sed 's/.*://' | tr -d ' '
}

# Validate a subsection's verdict and return the value via stdout
_get_verdict_for_subsection() {
  local sub="$1" review_content="$2"
  echo "$review_content" | _extract_h3_section "$sub" | _get_field "verdict"
}

# =============================================================================
# VALIDATION: ## CRG Quantified Review
# =============================================================================

validate_quantified_review() {
  # 1. File must exist
  if [ -z "$review_file" ] || [ ! -f "$review_file" ]; then
    _fail "review file exists (design.md or review.md)" "no file found under $base"
    return
  fi

  # 2. Section must exist
  if ! _has_h2 "$review_file" "CRG Quantified Review"; then
    _fail "file has ## CRG Quantified Review section" "section not found in $review_file"
    return
  fi
  _pass "file has ## CRG Quantified Review section"

  local review_content
  review_content=$(_extract_h2_section "$review_file" "CRG Quantified Review")

  # 3. Required subsections
  local required_subsections="Review Metadata|Scope Drift|Changed Function Test Coverage|Flow Impact|Knowledge Gaps|Final CRG Verdict"
  local IFS_SAVE="$IFS"
  IFS='|'
  for sub in $required_subsections; do
    IFS="$IFS_SAVE"
    if echo "$review_content" | _has_h3_in_block "$sub"; then
      _pass "CRG Quantified Review has ### $sub subsection"
    else
      _fail "CRG Quantified Review has ### $sub subsection" "subsection not found"
    fi
    IFS='|'
  done
  IFS="$IFS_SAVE"

  # 4. Validate verdict fields for subsections that have them
  # Use individual variables instead of associative array (bash 3 compat)

  local verdict_scope_drift
  verdict_scope_drift=$(_get_verdict_for_subsection "Scope Drift" "$review_content")
  if echo "$verdict_scope_drift" | grep -qE "^(PASS|BLOCKING|NEEDS_HUMAN_DECISION)$"; then
    _pass "Scope Drift: verdict is valid enum ($verdict_scope_drift)"
  else
    _fail "Scope Drift: verdict is valid enum" \
      "got '$verdict_scope_drift', expected PASS|BLOCKING|NEEDS_HUMAN_DECISION"
  fi

  local verdict_coverage
  verdict_coverage=$(_get_verdict_for_subsection "Changed Function Test Coverage" "$review_content")
  if echo "$verdict_coverage" | grep -qE "^(PASS|BLOCKING|NEEDS_HUMAN_DECISION)$"; then
    _pass "Changed Function Test Coverage: verdict is valid enum ($verdict_coverage)"
  else
    _fail "Changed Function Test Coverage: verdict is valid enum" \
      "got '$verdict_coverage', expected PASS|BLOCKING|NEEDS_HUMAN_DECISION"
  fi

  local verdict_flow_impact
  verdict_flow_impact=$(_get_verdict_for_subsection "Flow Impact" "$review_content")
  if echo "$verdict_flow_impact" | grep -qE "^(PASS|BLOCKING|NEEDS_HUMAN_DECISION)$"; then
    _pass "Flow Impact: verdict is valid enum ($verdict_flow_impact)"
  else
    _fail "Flow Impact: verdict is valid enum" \
      "got '$verdict_flow_impact', expected PASS|BLOCKING|NEEDS_HUMAN_DECISION"
  fi

  local verdict_knowledge_gaps
  verdict_knowledge_gaps=$(_get_verdict_for_subsection "Knowledge Gaps" "$review_content")
  if echo "$verdict_knowledge_gaps" | grep -qE "^(PASS|BLOCKING|NEEDS_HUMAN_DECISION)$"; then
    _pass "Knowledge Gaps: verdict is valid enum ($verdict_knowledge_gaps)"
  else
    _fail "Knowledge Gaps: verdict is valid enum" \
      "got '$verdict_knowledge_gaps', expected PASS|BLOCKING|NEEDS_HUMAN_DECISION"
  fi

  # 5. Verdict consistency checks

  # Scope Drift: drift_percent > threshold AND verdict=PASS → FAIL
  local drift_content drift_percent
  drift_content=$(echo "$review_content" | _extract_h3_section "Scope Drift")
  drift_percent=$(echo "$drift_content" | _get_field "drift_percent")

  if echo "$drift_percent" | grep -qE "^[0-9]+(\.[0-9]+)?$"; then
    local drift_int
    drift_int=$(echo "$drift_percent" | cut -d. -f1)
    if [ "$drift_int" -gt "$SCOPE_DRIFT_THRESHOLD" ] && [ "$verdict_scope_drift" = "PASS" ]; then
      _fail "Scope Drift: verdict consistency" \
        "drift_percent ${drift_percent}% > threshold ${SCOPE_DRIFT_THRESHOLD}% but verdict=PASS"
    else
      _pass "Scope Drift: verdict consistency"
    fi
  fi

  # Coverage: coverage_percent < threshold AND verdict=PASS → FAIL
  local cov_content cov_percent
  cov_content=$(echo "$review_content" | _extract_h3_section "Changed Function Test Coverage")
  cov_percent=$(echo "$cov_content" | _get_field "coverage_percent")

  if echo "$cov_percent" | grep -qE "^[0-9]+(\.[0-9]+)?$"; then
    local cov_int
    cov_int=$(echo "$cov_percent" | cut -d. -f1)
    if [ "$cov_int" -lt "$COVERAGE_THRESHOLD" ] && [ "$verdict_coverage" = "PASS" ]; then
      _fail "Changed Function Test Coverage: verdict consistency" \
        "coverage_percent ${cov_percent}% < threshold ${COVERAGE_THRESHOLD}% but verdict=PASS"
    else
      _pass "Changed Function Test Coverage: verdict consistency"
    fi
  fi

  # Flow Impact: flows_missing_e2e non-empty AND requireE2EForAffectedFlows=true AND verdict=PASS → FAIL
  local flow_content flows_missing
  flow_content=$(echo "$review_content" | _extract_h3_section "Flow Impact")
  flows_missing=$(echo "$flow_content" | _get_field "flows_missing_e2e")

  if [ "$REQUIRE_E2E" = "true" ]; then
    local flows_missing_clean
    flows_missing_clean=$(echo "$flows_missing" | tr -d ' ')
    if [ "$flows_missing_clean" != "[]" ] && [ -n "$flows_missing_clean" ] && \
       [ "$verdict_flow_impact" = "PASS" ]; then
      _fail "Flow Impact: verdict consistency" \
        "flows_missing_e2e is non-empty ($flows_missing) but verdict=PASS and requireE2EForAffectedFlows=true"
    else
      _pass "Flow Impact: verdict consistency"
    fi
  fi

  # Knowledge Gaps: critical list non-empty AND verdict=PASS → FAIL
  local gaps_content critical_list
  gaps_content=$(echo "$review_content" | _extract_h3_section "Knowledge Gaps")
  critical_list=$(echo "$gaps_content" | _get_field "critical")

  local critical_clean
  critical_clean=$(echo "$critical_list" | tr -d ' ')
  if [ "$critical_clean" != "[]" ] && [ -n "$critical_clean" ] && \
     [ "$verdict_knowledge_gaps" = "PASS" ]; then
    _fail "Knowledge Gaps: verdict consistency" \
      "critical list is non-empty ($critical_list) but verdict=PASS"
  else
    _pass "Knowledge Gaps: verdict consistency"
  fi

  # 6. Final CRG Verdict: archive_ready must be yes or no
  local final_content archive_ready
  final_content=$(echo "$review_content" | _extract_h3_section "Final CRG Verdict")
  archive_ready=$(echo "$final_content" | _get_field "archive_ready")

  if echo "$archive_ready" | grep -qE "^(yes|no)$"; then
    _pass "Final CRG Verdict: archive_ready is yes or no ($archive_ready)"
  else
    _fail "Final CRG Verdict: archive_ready is yes or no" \
      "got '$archive_ready', expected yes|no"
  fi

  # 7. If archive_ready=yes, ALL subsection verdicts must be PASS (contradiction check)
  if [ "$archive_ready" = "yes" ]; then
    local all_pass=true
    local blockers=""

    if [ "$verdict_scope_drift" != "PASS" ]; then
      all_pass=false
      blockers="${blockers} Scope Drift=${verdict_scope_drift}"
    fi
    if [ "$verdict_coverage" != "PASS" ]; then
      all_pass=false
      blockers="${blockers} Changed Function Test Coverage=${verdict_coverage}"
    fi
    if [ "$verdict_flow_impact" != "PASS" ]; then
      all_pass=false
      blockers="${blockers} Flow Impact=${verdict_flow_impact}"
    fi
    if [ "$verdict_knowledge_gaps" != "PASS" ]; then
      all_pass=false
      blockers="${blockers} Knowledge Gaps=${verdict_knowledge_gaps}"
    fi

    if $all_pass; then
      _pass "Final CRG Verdict: archive_ready=yes is consistent (all subsections PASS)"
    else
      _fail "Final CRG Verdict: archive_ready=yes contradiction" \
        "non-PASS subsections:$blockers"
    fi
  fi
}

# =============================================================================
# Main execution
# =============================================================================

validate_quantified_review

# Summary
total=$((PASS_COUNT + FAIL_COUNT))
echo ""
echo "SUMMARY: $total checks, $PASS_COUNT passed, $FAIL_COUNT failed"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi

exit 0
