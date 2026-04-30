#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# check-crg-evidence.sh — V5 structured CRG schema validation
#
# Usage: check-crg-evidence.sh <change-id>
#
# Modes (AIWK_CHECK_CRG_MODE):
#   strict      (default) — validates Discovery + Precision Plan + Post-Phase
#   shape-only             — validates Discovery only (used by /spcrg-start gate)
# =============================================================================

change_id="${1:-}"

if [ -z "$change_id" ]; then
  echo "Usage: scripts/check-crg-evidence.sh <change-id>"
  exit 1
fi

MODE="${AIWK_CHECK_CRG_MODE:-strict}"
base="openspec/changes/$change_id"

if [ ! -d "$base" ]; then
  echo "OpenSpec change not found: $base"
  exit 1
fi

design_file="$base/design.md"
tasks_file="$base/tasks.md"

# =============================================================================
# Config reader
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
DISCOVERY_MIN_READINGS=$(_read_config ".thresholds.discoveryMinReadings" "2")
PRECISION_PLAN_MIN_TASKS=$(_read_config ".thresholds.precisionPlanMinTasks" "1")
SCOPE_DRIFT_THRESHOLD=$(_read_config ".thresholds.scopeDriftPercent" "20")
COVERAGE_THRESHOLD=$(_read_config ".thresholds.changedSymbolTestCoveragePercent" "80")

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

# Extract the raw content of a level-2 section (## Heading) from a file.
# Returns all lines between the heading and the next ## (or EOF).
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

# Count non-header, non-separator table rows in stdin
# Table rows look like: | col1 | col2 | ...
# Header separator rows look like: |---|---|...  or  |:---|:---|...
_count_table_rows() {
  grep -c "^|" | tr -d ' ' || echo 0
  # We'll do it properly below
}

# Count data rows in a markdown table (excludes header and separator lines)
_count_data_rows() {
  awk '/^\|/ && !/^\|[-: |]+\|/' | grep -c "^|" || echo 0
}

# =============================================================================
# VALIDATION: design.md — ## CRG Discovery
# =============================================================================

validate_discovery() {
  local file="$design_file"

  # 1. File exists
  if [ ! -f "$file" ]; then
    _fail "design.md exists" "file not found: $file"
    return
  fi

  # 2. ## CRG Discovery section exists
  if ! _has_h2 "$file" "CRG Discovery"; then
    _fail "design.md has ## CRG Discovery section" "section not found"
    return
  fi
  _pass "design.md has ## CRG Discovery section"

  # Extract the discovery section content
  local disc_content
  disc_content=$(_extract_h2_section "$file" "CRG Discovery")

  # 3. Required subsections (7 + Open Questions)
  local required_subsections=(
    "Discovery Metadata"
    "Search Queries"
    "Code Reading Summary"
    "Involved Modules"
    "Entry Points"
    "Existing Patterns"
    "Risk Boundary"
  )

  for sub in "${required_subsections[@]}"; do
    if echo "$disc_content" | _has_h3_in_block "$sub"; then
      _pass "CRG Discovery has ### $sub subsection"
    else
      _fail "CRG Discovery has ### $sub subsection" "subsection not found"
    fi
  done

  # 4. Open Questions subsection
  if echo "$disc_content" | _has_h3_in_block "Open Questions"; then
    _pass "CRG Discovery has ### Open Questions subsection"
  else
    _fail "CRG Discovery has ### Open Questions subsection" "subsection not found"
  fi

  # 5. Discovery Metadata — 4 required fields non-empty
  local meta_content
  meta_content=$(echo "$disc_content" | awk '
    found && /^### / { exit }
    found { print }
    /^### Discovery Metadata/ { found=1 }
  ')

  local meta_fields=("generated_at" "generated_by" "crg_graph_status" "source_requirement")
  for field in "${meta_fields[@]}"; do
    local val
    val=$(echo "$meta_content" | grep -E "^-?\s*${field}:" | sed 's/.*://' | tr -d ' ')
    if [ -n "$val" ]; then
      _pass "Discovery Metadata: $field is non-empty"
    else
      _fail "Discovery Metadata: $field is non-empty" "field missing or empty"
    fi
  done

  # 6. crg_graph_status valid enum: fresh|rebuilt|stale|unavailable
  local graph_status
  graph_status=$(echo "$meta_content" | grep -E "^-?\s*crg_graph_status:" | sed 's/.*://' | tr -d ' ')
  if echo "$graph_status" | grep -qE "^(fresh|rebuilt|stale|unavailable)$"; then
    _pass "Discovery Metadata: crg_graph_status valid enum ($graph_status)"
  else
    _fail "Discovery Metadata: crg_graph_status valid enum" "got '$graph_status', expected fresh|rebuilt|stale|unavailable"
  fi

  # 7. Code Reading Summary table row count >= discoveryMinReadings
  local reading_content
  reading_content=$(echo "$disc_content" | awk '
    found && /^### / { exit }
    found { print }
    /^### Code Reading Summary/ { found=1 }
  ')

  local row_count
  # Count only data rows: exclude separator lines AND the first non-separator row (header)
  row_count=$(echo "$reading_content" | awk '
    /^\|/ && !/^\|[-: |]+\|/ {
      if (!header_seen) { header_seen=1; next }
      count++
    }
    END { print count+0 }
  ')

  if [ "$row_count" -ge "$DISCOVERY_MIN_READINGS" ]; then
    _pass "Code Reading Summary has >= $DISCOVERY_MIN_READINGS rows (found $row_count)"
  else
    _fail "Code Reading Summary has >= $DISCOVERY_MIN_READINGS rows" "found $row_count"
  fi

  # 8. All 5 columns non-empty per Code Reading Summary row
  # Columns: File | Symbol | Why Read | Finding | Decision
  local row_num=0
  local reading_header_skipped=false
  while IFS= read -r row; do
    # Skip non-table lines
    echo "$row" | grep -q "^|" || continue
    # Skip separator lines (e.g. |---|---|)
    echo "$row" | grep -q "^|[-: |]*|$" && continue

    # Skip the header row (first non-separator table row)
    if ! $reading_header_skipped; then
      reading_header_skipped=true
      continue
    fi

    row_num=$((row_num + 1))

    # Split row on | and check each column is non-empty
    # Strip leading/trailing | then split on |
    local inner
    inner="${row#|}"
    inner="${inner%|}"

    local col_num=0
    local all_filled=true
    IFS='|' read -ra cols <<< "$inner"
    for col in "${cols[@]}"; do
      col_num=$((col_num + 1))
      local trimmed
      trimmed=$(echo "$col" | tr -d ' ')
      if [ -z "$trimmed" ] || [ "$trimmed" = "---" ] || echo "$trimmed" | grep -q "^[-:]*$"; then
        all_filled=false
        break
      fi
    done

    if $all_filled && [ "$col_num" -ge 5 ]; then
      _pass "Code Reading Summary row $row_num: all 5 columns non-empty"
    elif ! $all_filled; then
      _fail "Code Reading Summary row $row_num: all 5 columns non-empty" "empty column found"
    else
      _fail "Code Reading Summary row $row_num: all 5 columns non-empty" "only $col_num columns"
    fi
  done <<< "$reading_content"

  # 9. Risk Boundary.expected_changed_files is positive integer
  local risk_content
  risk_content=$(echo "$disc_content" | awk '
    found && /^### / { exit }
    found { print }
    /^### Risk Boundary/ { found=1 }
  ')

  local expected_files
  expected_files=$(echo "$risk_content" | grep -E "expected_changed_files:" | sed 's/.*://' | tr -d ' ')
  if echo "$expected_files" | grep -qE "^[1-9][0-9]*$"; then
    _pass "Risk Boundary: expected_changed_files is positive integer ($expected_files)"
  else
    _fail "Risk Boundary: expected_changed_files is positive integer" "got '$expected_files'"
  fi
}

# =============================================================================
# VALIDATION: tasks.md — ## CRG Precision Plan
# =============================================================================

validate_precision_plan() {
  local file="$tasks_file"

  if [ ! -f "$file" ]; then
    _fail "tasks.md exists" "file not found: $file"
    return
  fi

  if ! _has_h2 "$file" "CRG Precision Plan"; then
    _fail "tasks.md has ## CRG Precision Plan section" "section not found"
    return
  fi
  _pass "tasks.md has ## CRG Precision Plan section"

  local plan_content
  plan_content=$(_extract_h2_section "$file" "CRG Precision Plan")

  # Required subsections
  local required_subsections=(
    "Mapping Metadata"
    "Function-Level Change Map"
    "Test Coverage Plan"
    "Phase Plan"
  )

  for sub in "${required_subsections[@]}"; do
    if echo "$plan_content" | _has_h3_in_block "$sub"; then
      _pass "CRG Precision Plan has ### $sub subsection"
    else
      _fail "CRG Precision Plan has ### $sub subsection" "subsection not found"
    fi
  done

  # Function-Level Change Map row count >= precisionPlanMinTasks
  local map_content
  map_content=$(echo "$plan_content" | awk '
    found && /^### / { exit }
    found { print }
    /^### Function-Level Change Map/ { found=1 }
  ')

  local map_row_count
  # Count only data rows: exclude separator lines AND the first non-separator row (header)
  map_row_count=$(echo "$map_content" | awk '
    /^\|/ && !/^\|[-: |]+\|/ {
      if (!header_seen) { header_seen=1; next }
      count++
    }
    END { print count+0 }
  ')

  if [ "$map_row_count" -ge "$PRECISION_PLAN_MIN_TASKS" ]; then
    _pass "Function-Level Change Map has >= $PRECISION_PLAN_MIN_TASKS rows (found $map_row_count)"
  else
    _fail "Function-Level Change Map has >= $PRECISION_PLAN_MIN_TASKS rows" "found $map_row_count"
  fi

  # All 7 columns non-empty per Change Map row; validate Target and Risk columns.
  # Column positions for Target and Risk are detected from the header row by name,
  # so the script works with both legacy schema (Target | Change Type | Rationale
  # | Depends On | Risk | Test Required | Notes) and the spcrg-plan schema
  # (Task | Target | Current Behavior | Required Change | Tests | Reference Pattern | Risk).
  local map_row_num=0
  local map_header_skipped=false
  local target_col_idx=0
  local risk_col_idx=0
  while IFS= read -r row; do
    echo "$row" | grep -q "^|" || continue
    echo "$row" | grep -q "^|[-: |]*|$" && continue

    # Parse the header row (first non-separator row) to locate Target and Risk columns
    if ! $map_header_skipped; then
      map_header_skipped=true
      local header_inner="${row#|}"
      header_inner="${header_inner%|}"
      local h_idx=0
      IFS='|' read -ra header_cols <<< "$header_inner"
      for hcol in "${header_cols[@]}"; do
        h_idx=$((h_idx + 1))
        local trimmed_h
        trimmed_h=$(echo "$hcol" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ "$trimmed_h" = "Target" ] && target_col_idx=$h_idx
        [ "$trimmed_h" = "Risk" ] && risk_col_idx=$h_idx
      done
      if [ "$target_col_idx" -eq 0 ]; then
        _fail "Function-Level Change Map has Target column in header" "Target header not found"
      else
        _pass "Function-Level Change Map has Target column in header (col $target_col_idx)"
      fi
      if [ "$risk_col_idx" -eq 0 ]; then
        _fail "Function-Level Change Map has Risk column in header" "Risk header not found"
      else
        _pass "Function-Level Change Map has Risk column in header (col $risk_col_idx)"
      fi
      continue
    fi

    map_row_num=$((map_row_num + 1))

    local inner="${row#|}"
    inner="${inner%|}"

    local col_num=0
    local all_filled=true
    local target_col=""
    local risk_col=""

    IFS='|' read -ra cols <<< "$inner"
    for col in "${cols[@]}"; do
      col_num=$((col_num + 1))
      local trimmed
      trimmed=$(echo "$col" | tr -d ' ')
      if [ -z "$trimmed" ] || echo "$trimmed" | grep -q "^[-:]*$"; then
        all_filled=false
      fi
      [ "$col_num" -eq "$target_col_idx" ] && target_col="$trimmed"
      [ "$col_num" -eq "$risk_col_idx" ] && risk_col="$trimmed"
    done

    if $all_filled && [ "$col_num" -ge 7 ]; then
      _pass "Change Map row $map_row_num: all 7 columns non-empty"
    elif ! $all_filled; then
      _fail "Change Map row $map_row_num: all 7 columns non-empty" "empty column found"
    else
      _fail "Change Map row $map_row_num: all 7 columns non-empty" "only $col_num columns"
    fi

    # Target matches file:symbol pattern (contains colon, no spaces around it)
    if echo "$target_col" | grep -q "[^ ]:[^ ]"; then
      _pass "Change Map row $map_row_num: Target matches file:symbol pattern"
    else
      _fail "Change Map row $map_row_num: Target matches file:symbol pattern" "got '$target_col'"
    fi

    # Risk column valid enum: low|medium|high
    if echo "$risk_col" | grep -qE "^(low|medium|high)$"; then
      _pass "Change Map row $map_row_num: Risk is valid enum ($risk_col)"
    else
      _fail "Change Map row $map_row_num: Risk is valid enum" "got '$risk_col'"
    fi
  done <<< "$map_content"

  # At least 1 #### Phase subsection within Phase Plan
  local phase_plan_content
  phase_plan_content=$(echo "$plan_content" | awk '
    found && /^### / { exit }
    found { print }
    /^### Phase Plan/ { found=1 }
  ')

  local phase_count
  phase_count=$(echo "$phase_plan_content" | grep "^#### Phase" 2>/dev/null | wc -l | tr -d ' ')

  if [ "$phase_count" -ge 1 ]; then
    _pass "Phase Plan has >= 1 #### Phase subsection (found $phase_count)"
  else
    _fail "Phase Plan has >= 1 #### Phase subsection" "found 0"
  fi

  # Each phase has 5 required fields
  local required_phase_fields=(
    "expected_files"
    "expected_symbols"
    "required_tests"
    "verification_command"
    "crg_post_phase_checks"
  )

  local phase_idx=0
  local current_phase_lines=""
  local in_phase=false

  while IFS= read -r line; do
    if echo "$line" | grep -q "^#### Phase"; then
      # Validate previous phase if any
      if $in_phase && [ "$phase_idx" -gt 0 ]; then
        _validate_phase_fields "$phase_idx" "$current_phase_lines"
      fi
      phase_idx=$((phase_idx + 1))
      current_phase_lines=""
      in_phase=true
      continue
    fi
    if $in_phase; then
      current_phase_lines="${current_phase_lines}
${line}"
    fi
  done <<< "$phase_plan_content"

  # Validate last phase
  if $in_phase && [ "$phase_idx" -gt 0 ]; then
    _validate_phase_fields "$phase_idx" "$current_phase_lines"
  fi
}

_validate_phase_fields() {
  local idx="$1" content="$2"
  local required_phase_fields=(
    "expected_files"
    "expected_symbols"
    "required_tests"
    "verification_command"
    "crg_post_phase_checks"
  )

  for field in "${required_phase_fields[@]}"; do
    local val
    val=$(echo "$content" | grep -E "^-?\s*${field}:" | sed 's/.*://' | tr -d ' ')
    if [ -n "$val" ]; then
      _pass "Phase $idx: $field is present"
    else
      _fail "Phase $idx: $field is present" "field missing or empty"
    fi
  done
}

# =============================================================================
# VALIDATION: Post-Phase Verifications in tasks.md
# =============================================================================

validate_post_phase_verifications() {
  local file="$tasks_file"

  if [ ! -f "$file" ]; then
    return
  fi

  # Find all ## CRG Post-Phase Verification sections
  local ppv_count
  ppv_count=$(grep "^## CRG Post-Phase Verification" "$file" 2>/dev/null | wc -l | tr -d ' ')

  if [ "$ppv_count" -eq 0 ]; then
    # No post-phase verifications — that's fine
    return
  fi

  local required_fields=(
    "generated_at"
    "actual_changed_files"
    "expected_changed_files"
    "scope_drift_percent"
    "changed_symbols"
    "tested_changed_symbols"
    "changed_symbol_test_coverage"
    "affected_flows"
    "e2e_required"
    "e2e_status"
    "knowledge_gaps"
    "surprising_connections"
    "verdict"
    "action_taken"
  )

  # Process each post-phase verification block
  local ppv_idx=0
  local in_ppv=false
  local ppv_content=""

  while IFS= read -r line; do
    if echo "$line" | grep -q "^## CRG Post-Phase Verification"; then
      # Validate previous block if any
      if $in_ppv && [ "$ppv_idx" -gt 0 ]; then
        _validate_ppv "$ppv_idx" "$ppv_content"
      fi
      ppv_idx=$((ppv_idx + 1))
      ppv_content=""
      in_ppv=true
      continue
    fi
    if $in_ppv; then
      if echo "$line" | grep -q "^## "; then
        # End of this PPV block
        _validate_ppv "$ppv_idx" "$ppv_content"
        in_ppv=false
        ppv_content=""
      else
        ppv_content="${ppv_content}
${line}"
      fi
    fi
  done < "$file"

  # Validate last block
  if $in_ppv && [ "$ppv_idx" -gt 0 ]; then
    _validate_ppv "$ppv_idx" "$ppv_content"
  fi
}

_validate_ppv() {
  local idx="$1" content="$2"

  local required_fields=(
    "generated_at"
    "actual_changed_files"
    "expected_changed_files"
    "scope_drift_percent"
    "changed_symbols"
    "tested_changed_symbols"
    "changed_symbol_test_coverage"
    "affected_flows"
    "e2e_required"
    "e2e_status"
    "knowledge_gaps"
    "surprising_connections"
    "verdict"
    "action_taken"
  )

  for field in "${required_fields[@]}"; do
    local val
    val=$(echo "$content" | grep -E "^-?\s*${field}:" | sed 's/.*://' | tr -d ' ')
    if [ -n "$val" ]; then
      _pass "Post-Phase Verification $idx: $field is present"
    else
      _fail "Post-Phase Verification $idx: $field is present" "field missing or empty"
    fi
  done

  # scope_drift_percent and changed_symbol_test_coverage are numeric
  local drift
  drift=$(echo "$content" | grep -E "^-?\s*scope_drift_percent:" | sed 's/.*://' | tr -d ' ')
  if echo "$drift" | grep -qE "^[0-9]+(\.[0-9]+)?$"; then
    _pass "Post-Phase Verification $idx: scope_drift_percent is numeric ($drift)"
  else
    _fail "Post-Phase Verification $idx: scope_drift_percent is numeric" "got '$drift'"
  fi

  local coverage
  coverage=$(echo "$content" | grep -E "^-?\s*changed_symbol_test_coverage:" | sed 's/.*://' | tr -d ' ')
  if echo "$coverage" | grep -qE "^[0-9]+(\.[0-9]+)?$"; then
    _pass "Post-Phase Verification $idx: changed_symbol_test_coverage is numeric ($coverage)"
  else
    _fail "Post-Phase Verification $idx: changed_symbol_test_coverage is numeric" "got '$coverage'"
  fi

  # verdict valid enum: PASS|BLOCKING|NEEDS_HUMAN_DECISION
  local verdict
  verdict=$(echo "$content" | grep -E "^-?\s*verdict:" | sed 's/.*://' | tr -d ' ')
  if echo "$verdict" | grep -qE "^(PASS|BLOCKING|NEEDS_HUMAN_DECISION)$"; then
    _pass "Post-Phase Verification $idx: verdict is valid enum ($verdict)"
  else
    _fail "Post-Phase Verification $idx: verdict is valid enum" "got '$verdict'"
  fi

  # Verdict consistency checks
  # drift > threshold but verdict=PASS → FAIL
  if echo "$drift" | grep -qE "^[0-9]+(\.[0-9]+)?$" && [ "$verdict" = "PASS" ]; then
    local drift_int
    drift_int=$(echo "$drift" | cut -d. -f1)
    if [ "$drift_int" -gt "$SCOPE_DRIFT_THRESHOLD" ]; then
      _fail "Post-Phase Verification $idx: verdict consistency (drift)" \
        "drift ${drift}% > threshold ${SCOPE_DRIFT_THRESHOLD}% but verdict=PASS"
    else
      _pass "Post-Phase Verification $idx: verdict consistency (drift)"
    fi
  fi

  # coverage < threshold but verdict=PASS → FAIL
  if echo "$coverage" | grep -qE "^[0-9]+(\.[0-9]+)?$" && [ "$verdict" = "PASS" ]; then
    local cov_int
    cov_int=$(echo "$coverage" | cut -d. -f1)
    if [ "$cov_int" -lt "$COVERAGE_THRESHOLD" ]; then
      _fail "Post-Phase Verification $idx: verdict consistency (coverage)" \
        "coverage ${coverage}% < threshold ${COVERAGE_THRESHOLD}% but verdict=PASS"
    else
      _pass "Post-Phase Verification $idx: verdict consistency (coverage)"
    fi
  fi

  # BLOCKING/NEEDS_HUMAN_DECISION → action_taken must be non-empty
  if echo "$verdict" | grep -qE "^(BLOCKING|NEEDS_HUMAN_DECISION)$"; then
    local action
    action=$(echo "$content" | grep -E "^-?\s*action_taken:" | sed 's/.*://' | tr -d ' ')
    if [ -n "$action" ]; then
      _pass "Post-Phase Verification $idx: action_taken non-empty for verdict=$verdict"
    else
      _fail "Post-Phase Verification $idx: action_taken non-empty for verdict=$verdict" \
        "action_taken is empty but verdict requires it"
    fi
  fi
}

# =============================================================================
# Main execution
# =============================================================================

validate_discovery

if [ "$MODE" != "shape-only" ]; then
  validate_precision_plan
  validate_post_phase_verifications
fi

# Summary
total=$((PASS_COUNT + FAIL_COUNT))
echo ""
echo "SUMMARY: $total checks, $PASS_COUNT passed, $FAIL_COUNT failed"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi

exit 0
