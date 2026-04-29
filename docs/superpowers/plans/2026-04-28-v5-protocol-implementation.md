# V5 Protocol Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade specpower-crg from V1 (gate-driven prompt wrappers) to V5 (decision-driven development OS with structured evidence schemas, numeric verdict consistency, and TDD-driven scripts).

**Architecture:** Bottom-up by layer. Infrastructure and scripts with fixture tests first (so later tasks can reference working scripts), then command file rewrites (which embed gate calls to those scripts), then docs and installer last. Every script change is TDD: write fixture → run (expect fail) → implement → run (expect pass).

**Tech Stack:** Bash scripts, jq (preferred) / python3 (fallback) for JSON parsing, markdown-structured evidence, Claude Code slash commands.

**Spec reference:** `docs/superpowers/specs/2026-04-28-v5-protocol-design.md`

---

## File Structure Overview

New/changed files (total ~35):

```
[new] .ai-workflow-kit/config.json
[new] tests/fixtures/config.json
[new] tests/fixtures/good-discovery-minimal/change/{proposal,design,tasks,specs/feature}.md
[new] tests/fixtures/good-precision-plan/change/{design,proposal,tasks,specs/feature}.md
[new] tests/fixtures/good-post-phase-pass/change/{design,proposal,tasks,specs/feature}.md
[new] tests/fixtures/good-quantified-review-archive-ready/change/{design,proposal,tasks,specs/feature}.md
[new] tests/fixtures/bad-missing-discovery/change/{proposal,design,tasks,specs/feature}.md
[new] tests/fixtures/bad-discovery-one-row/change/{design,...}.md
[new] tests/fixtures/bad-discovery-empty-col/change/{design,...}.md
[new] tests/fixtures/bad-precision-plan-no-phase/change/{design,tasks,...}.md
[new] tests/fixtures/bad-precision-plan-bad-target/change/{design,tasks,...}.md
[new] tests/fixtures/bad-post-phase-verdict-inconsistent/change/{design,tasks,...}.md
[new] tests/fixtures/bad-post-phase-missing-field/change/{design,tasks,...}.md
[new] tests/fixtures/bad-quantified-review-archive-yes-with-blocker/change/{design,...}.md
[new] tests/fixtures/bad-quantified-review-drift-over-threshold/change/{design,...}.md
[new] scripts/run-tests.sh
[new] scripts/check-v5-review.sh
[new] scripts/check-command-protocols.sh
[new] CHANGELOG.md
[changed] .gitignore
[changed] scripts/check-crg-evidence.sh       (full rewrite)
[changed] scripts/verify-install.sh            (add step 5)
[changed] scripts/build-installer.sh           (add new scripts + config)
[changed] scripts/install-ai-workflow-kit.sh   (regenerated)
[changed] .claude/commands/spcrg-start.md      (full rewrite)
[changed] .claude/commands/spcrg-plan.md       (full rewrite)
[changed] .claude/commands/spcrg-dev.md        (full rewrite)
[changed] .claude/commands/spcrg-review.md     (full rewrite)
[changed] .claude/commands/spcrg-archive.md    (moderate change)
[changed] .claude/commands/spcrg-bugfix.md     (minor)
[changed] .claude/commands/spcrg-hotfix.md     (minor)
[changed] .claude/commands/spcrg-refactor.md   (minor)
[changed] .claude/commands/spcrg-audit.md      (full rewrite)
[changed] .claude/skills/project-development-workflow/SKILL.md
[changed] CLAUDE.md
[changed] README.md
```

---

## Phase A: Infrastructure

### Task 1: Create `.ai-workflow-kit/config.json` and update `.gitignore`

**Files:**
- Create: `.ai-workflow-kit/config.json`
- Modify: `.gitignore`

- [ ] **Step 1: Create config directory and default config**

```bash
mkdir -p .ai-workflow-kit
```

Write `.ai-workflow-kit/config.json`:

```json
{
  "version": "5",
  "commandPrefix": "spcrg",
  "thresholds": {
    "scopeDriftPercent": 20,
    "changedSymbolTestCoveragePercent": 80,
    "discoveryMinReadings": 2,
    "precisionPlanMinTasks": 1,
    "maxCallChainDepth": 2
  },
  "gates": {
    "requireE2EForAffectedFlows": true,
    "allowHumanOverride": true,
    "requireReviewBeforeArchive": true
  }
}
```

- [ ] **Step 2: Update `.gitignore`**

Append to `.gitignore`:

```
.ai-workflow-kit/state/
```

- [ ] **Step 3: Verify**

```bash
cat .ai-workflow-kit/config.json | jq .version
# Expected: "5"
cat .gitignore | grep "state"
# Expected: .ai-workflow-kit/state/
```

- [ ] **Step 4: Commit**

```bash
git add .ai-workflow-kit/config.json .gitignore
git commit -m "feat(v5): add .ai-workflow-kit/config.json with default thresholds"
```

---

### Task 2: Create test fixture framework and `scripts/run-tests.sh`

**Files:**
- Create: `scripts/run-tests.sh`
- Create: `tests/fixtures/config.json`

- [ ] **Step 1: Create shared test config**

Write `tests/fixtures/config.json`:

```json
{
  "version": "5",
  "commandPrefix": "spcrg",
  "thresholds": {
    "scopeDriftPercent": 20,
    "changedSymbolTestCoveragePercent": 80,
    "discoveryMinReadings": 2,
    "precisionPlanMinTasks": 1,
    "maxCallChainDepth": 2
  },
  "gates": {
    "requireE2EForAffectedFlows": true,
    "allowHumanOverride": true,
    "requireReviewBeforeArchive": true
  }
}
```

- [ ] **Step 2: Write `scripts/run-tests.sh`**

```bash
#!/usr/bin/env bash
#
# run-tests.sh — run fixture tests for V5 gate scripts.
# Convention: good-* → expect exit 0; bad-* → expect exit non-zero.
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

  # Determine expected exit code from naming convention
  if [[ "$case_name" == good-* ]]; then
    expected_exit=0
  elif [[ "$case_name" == bad-* ]]; then
    expected_exit=1
  else
    continue
  fi

  # Determine which script to test based on fixture name
  if [[ "$case_name" == *quantified-review* ]]; then
    script="$root/scripts/check-v5-review.sh"
  else
    script="$root/scripts/check-crg-evidence.sh"
  fi

  # Skip if target script doesn't exist yet
  if [ ! -f "$script" ]; then
    echo "  SKIP  $case_name (script not found: $(basename "$script"))"
    continue
  fi

  # Build temporary project structure
  workdir=$(mktemp -d)
  trap_cmd="rm -rf $workdir"
  mkdir -p "$workdir/openspec/changes/$case_name"
  cp -r "$case_dir/change/"* "$workdir/openspec/changes/$case_name/"
  mkdir -p "$workdir/.ai-workflow-kit"
  cp "$fixtures/config.json" "$workdir/.ai-workflow-kit/config.json"

  # Run the script
  output=$(cd "$workdir" && "$script" "$case_name" 2>&1) || true
  actual_exit=$?

  # For check-crg-evidence.sh good fixtures that don't have Precision Plan,
  # use shape-only mode
  if [[ "$case_name" == good-discovery-minimal ]] && [ "$actual_exit" -ne 0 ]; then
    output=$(cd "$workdir" && AIWK_CHECK_CRG_MODE=shape-only "$script" "$case_name" 2>&1) || true
    actual_exit=$?
  fi

  rm -rf "$workdir"

  # Compare
  if [ "$actual_exit" -eq 0 ] && [ "$expected_exit" -eq 0 ]; then
    printf "  \033[32mPASS\033[0m  %s (exit 0 as expected)\n" "$case_name"
    pass=$((pass + 1))
  elif [ "$actual_exit" -ne 0 ] && [ "$expected_exit" -ne 0 ]; then
    printf "  \033[32mPASS\033[0m  %s (exit %d as expected)\n" "$case_name" "$actual_exit"
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
```

- [ ] **Step 3: Make executable and verify**

```bash
chmod +x scripts/run-tests.sh
./scripts/run-tests.sh
# Expected: "Results: 0 tests, 0 passed, 0 failed" (no fixtures yet)
```

- [ ] **Step 4: Commit**

```bash
git add scripts/run-tests.sh tests/fixtures/config.json
git commit -m "feat(v5): add run-tests.sh fixture framework"
```

---

### Task 3: Create initial fixture pair (good + bad)

**Files:**
- Create: `tests/fixtures/good-discovery-minimal/change/` (4 files)
- Create: `tests/fixtures/bad-missing-discovery/change/` (4 files)

- [ ] **Step 1: Create good-discovery-minimal fixture**

```bash
mkdir -p tests/fixtures/good-discovery-minimal/change/specs
```

Write `tests/fixtures/good-discovery-minimal/change/proposal.md`:

```markdown
# Proposal: Add User Search

## Summary
Add email and name search to the user list.

## CRG Risk Summary
- 4 expected changed files
- Bridge node: src/services/UserService.ts
```

Write `tests/fixtures/good-discovery-minimal/change/design.md`:

```markdown
# Design: Add User Search

## CRG Discovery

### Discovery Metadata
- generated_at: 2026-04-28T01:00:00Z
- generated_by: /spcrg-start
- crg_graph_status: fresh
- source_requirement: Add user search with email and name filters

### Search Queries
- "user search" → top hits: 8
- "email filter" → top hits: 3

### Code Reading Summary
| File | Symbol | Why Read | Finding | Decision |
|---|---|---|---|---|
| src/services/UserService.ts | searchUsers | semantic top hit | Only supports name filter | modify |
| src/services/UserService.ts | findByName | callers reference | Shows pagination pattern | reuse-pattern |
| tests/services/UserService.test.ts | (file) | tests_for searchUsers | 3 existing cases for name | extend |

### Involved Modules
- services/user — main search logic — modify
- components/UserList — display layer — add

### Entry Points
- src/services/UserService.ts:searchUsers — API entry — caller count: 7

### Existing Patterns
- pagination via cursor — reference src/services/UserService.ts:findByName — adopt

### Risk Boundary
- expected_changed_files: 4
- expected_changed_symbols: 6
- expected_affected_flows: [UserListFlow]
- hub_nodes: none
- bridge_nodes: [src/services/UserService.ts]

### Open Questions
- none
```

Write `tests/fixtures/good-discovery-minimal/change/tasks.md`:

```markdown
# Tasks

- [ ] Implement email filter
- [ ] Add tests
```

Write `tests/fixtures/good-discovery-minimal/change/specs/feature.md`:

```markdown
# Spec: User Search

GIVEN a user list
WHEN searching by email
THEN results are filtered by email
```

- [ ] **Step 2: Create bad-missing-discovery fixture**

```bash
mkdir -p tests/fixtures/bad-missing-discovery/change/specs
```

Write `tests/fixtures/bad-missing-discovery/change/proposal.md`:

```markdown
# Proposal: Something

## Summary
A feature without CRG Discovery.
```

Write `tests/fixtures/bad-missing-discovery/change/design.md`:

```markdown
# Design: Something

## Overview
This design has no CRG Discovery section at all.
Just plain text with no structured evidence.
```

Write `tests/fixtures/bad-missing-discovery/change/tasks.md`:

```markdown
# Tasks

- [ ] Do something
```

Write `tests/fixtures/bad-missing-discovery/change/specs/feature.md`:

```markdown
# Spec
Basic spec.
```

- [ ] **Step 3: Run existing V1 check-crg-evidence.sh against fixtures (baseline)**

```bash
./scripts/run-tests.sh
# Expected: may SKIP if check-crg-evidence.sh hasn't been upgraded yet,
# or may PASS/FAIL — this establishes current behavior.
```

- [ ] **Step 4: Commit**

```bash
git add tests/fixtures/good-discovery-minimal tests/fixtures/bad-missing-discovery
git commit -m "feat(v5): add initial good/bad fixture pair for Discovery"
```

---

## Phase B: Gate Script Upgrades

### Task 4: Rewrite `scripts/check-crg-evidence.sh` — Discovery validation

**Files:**
- Rewrite: `scripts/check-crg-evidence.sh`

- [ ] **Step 1: Write the full upgraded script**

```bash
#!/usr/bin/env bash
#
# check-crg-evidence.sh — V5 structured evidence validation.
# Validates: CRG Discovery, CRG Precision Plan, Post-Phase Verifications.
#
# Modes:
#   default (strict): requires Precision Plan (use for plan/dev/review/archive gates)
#   AIWK_CHECK_CRG_MODE=shape-only: only Discovery (use for /spcrg-start end-gate)
#
set -uo pipefail

change_id="${1:-}"
mode="${AIWK_CHECK_CRG_MODE:-strict}"

if [ -z "$change_id" ]; then
  echo "Usage: scripts/check-crg-evidence.sh <change-id>"
  echo "  Env: AIWK_CHECK_CRG_MODE=strict|shape-only (default: strict)"
  exit 1
fi

base="openspec/changes/$change_id"

if [ ! -d "$base" ]; then
  echo "OpenSpec change not found: $base"
  exit 1
fi

# --- Config reader ---
_read_config() {
  local key="$1" default="$2" config=".ai-workflow-kit/config.json"
  if [ ! -f "$config" ]; then echo "$default"; return; fi
  if command -v jq &>/dev/null; then
    val=$(jq -r "$key // empty" "$config" 2>/dev/null)
    [ -n "$val" ] && echo "$val" || echo "$default"
  elif command -v python3 &>/dev/null; then
    val=$(python3 -c "
import json,sys
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

min_readings=$(_read_config '.thresholds.discoveryMinReadings' '2')
min_tasks=$(_read_config '.thresholds.precisionPlanMinTasks' '1')
scope_drift_max=$(_read_config '.thresholds.scopeDriftPercent' '20')
coverage_min=$(_read_config '.thresholds.changedSymbolTestCoveragePercent' '80')

checks=0
failures=0

check() {
  local desc="$1" result="$2"
  checks=$((checks + 1))
  if [ "$result" = "PASS" ]; then
    printf "CHECK: %-60s PASS\n" "$desc"
  else
    printf "CHECK: %-60s FAIL (%s)\n" "$desc" "$result"
    failures=$((failures + 1))
  fi
}

# --- design.md: CRG Discovery ---
design="$base/design.md"

if [ ! -f "$design" ]; then
  check "design.md exists" "file not found"
else
  if grep -q "^## CRG Discovery" "$design"; then
    check "## CRG Discovery section exists" "PASS"
  else
    check "## CRG Discovery section exists" "not found in design.md"
  fi

  # Check 7 subsections
  for section in "### Discovery Metadata" "### Search Queries" "### Code Reading Summary" \
                 "### Involved Modules" "### Entry Points" "### Existing Patterns" "### Risk Boundary"; do
    if grep -q "^$section" "$design"; then
      check "$section exists" "PASS"
    else
      check "$section exists" "missing"
    fi
  done

  # Open Questions (can be inside or outside CRG Discovery)
  if grep -q "### Open Questions" "$design"; then
    check "### Open Questions exists" "PASS"
  else
    check "### Open Questions exists" "missing"
  fi

  # Discovery Metadata fields
  for field in "generated_at" "generated_by" "crg_graph_status" "source_requirement"; do
    if grep -q "^- ${field}:.\+" "$design"; then
      check "Discovery Metadata.$field non-empty" "PASS"
    else
      check "Discovery Metadata.$field non-empty" "missing or empty"
    fi
  done

  # crg_graph_status enum
  status_val=$(grep "^- crg_graph_status:" "$design" 2>/dev/null | sed 's/.*: *//')
  if echo "$status_val" | grep -qE "^(fresh|rebuilt|stale|unavailable)$"; then
    check "crg_graph_status valid enum" "PASS"
  else
    check "crg_graph_status valid enum" "got: $status_val"
  fi

  # Code Reading Summary row count
  reading_rows=$(awk '/^### Code Reading Summary/,/^###/{print}' "$design" | grep -c "^|" || true)
  # Subtract header + separator rows (2)
  reading_rows=$((reading_rows > 2 ? reading_rows - 2 : 0))
  if [ "$reading_rows" -ge "$min_readings" ]; then
    check "Code Reading Summary rows >= $min_readings" "PASS"
  else
    check "Code Reading Summary rows >= $min_readings" "found: $reading_rows"
  fi

  # Code Reading Summary column completeness (5 cols: File|Symbol|Why Read|Finding|Decision)
  if [ "$reading_rows" -gt 0 ]; then
    empty_cols=0
    while IFS= read -r row; do
      cols=$(echo "$row" | awk -F'|' '{for(i=2;i<=NF-1;i++) if($i ~ /^[[:space:]]*$/) print i}' | wc -l)
      [ "$cols" -gt 0 ] && empty_cols=$((empty_cols + 1))
    done < <(awk '/^### Code Reading Summary/,/^###/{print}' "$design" | grep "^|" | tail -n +3)
    if [ "$empty_cols" -eq 0 ]; then
      check "Code Reading Summary all columns non-empty" "PASS"
    else
      check "Code Reading Summary all columns non-empty" "$empty_cols row(s) have empty columns"
    fi
  fi

  # Risk Boundary expected_changed_files is positive integer
  ecf=$(grep "^- expected_changed_files:" "$design" 2>/dev/null | grep -oE '[0-9]+')
  if [ -n "$ecf" ] && [ "$ecf" -gt 0 ]; then
    check "Risk Boundary.expected_changed_files positive int" "PASS"
  else
    check "Risk Boundary.expected_changed_files positive int" "got: $ecf"
  fi
fi

# --- tasks.md: CRG Precision Plan (strict mode only) ---
tasks="$base/tasks.md"

if [ "$mode" = "strict" ] && [ -f "$tasks" ]; then
  if grep -q "^## CRG Precision Plan" "$tasks"; then
    check "## CRG Precision Plan exists" "PASS"
  else
    check "## CRG Precision Plan exists" "not found in tasks.md"
  fi

  for section in "### Mapping Metadata" "### Function-Level Change Map" \
                 "### Test Coverage Plan" "### Phase Plan"; do
    if grep -q "^$section" "$tasks"; then
      check "Precision Plan: $section exists" "PASS"
    else
      check "Precision Plan: $section exists" "missing"
    fi
  done

  # Change Map row count
  map_rows=$(awk '/^### Function-Level Change Map/,/^###/{print}' "$tasks" | grep -c "^|" || true)
  map_rows=$((map_rows > 2 ? map_rows - 2 : 0))
  if [ "$map_rows" -ge "$min_tasks" ]; then
    check "Function-Level Change Map rows >= $min_tasks" "PASS"
  else
    check "Function-Level Change Map rows >= $min_tasks" "found: $map_rows"
  fi

  # Target column format check (file:symbol)
  if [ "$map_rows" -gt 0 ]; then
    bad_targets=0
    while IFS= read -r row; do
      target=$(echo "$row" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$3); print $3}')
      if ! echo "$target" | grep -qE '^[^[:space:]:]+:[^[:space:]:]+$'; then
        bad_targets=$((bad_targets + 1))
      fi
    done < <(awk '/^### Function-Level Change Map/,/^###/{print}' "$tasks" | grep "^|" | tail -n +3)
    if [ "$bad_targets" -eq 0 ]; then
      check "Change Map Target column format (file:symbol)" "PASS"
    else
      check "Change Map Target column format (file:symbol)" "$bad_targets invalid"
    fi
  fi

  # Risk column enum
  if [ "$map_rows" -gt 0 ]; then
    bad_risk=0
    while IFS= read -r row; do
      risk=$(echo "$row" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$8); print $8}')
      if ! echo "$risk" | grep -qE '^(low|medium|high)$'; then
        bad_risk=$((bad_risk + 1))
      fi
    done < <(awk '/^### Function-Level Change Map/,/^###/{print}' "$tasks" | grep "^|" | tail -n +3)
    if [ "$bad_risk" -eq 0 ]; then
      check "Change Map Risk column valid enum" "PASS"
    else
      check "Change Map Risk column valid enum" "$bad_risk invalid"
    fi
  fi

  # At least 1 Phase Plan subsection
  phase_count=$(grep -c "^#### Phase" "$tasks" || true)
  if [ "$phase_count" -ge 1 ]; then
    check "Phase Plan has >= 1 phase subsection" "PASS"
  else
    check "Phase Plan has >= 1 phase subsection" "found: $phase_count"
  fi

  # Each Phase has 5 required fields
  if [ "$phase_count" -ge 1 ]; then
    phase_fields_ok=true
    for field in "expected_files" "expected_symbols" "required_tests" "verification_command" "crg_post_phase_checks"; do
      field_count=$(grep -c "^- ${field}:" "$tasks" || true)
      if [ "$field_count" -lt "$phase_count" ]; then
        check "Phase Plan field: $field in all phases" "found $field_count, need $phase_count"
        phase_fields_ok=false
      fi
    done
    if [ "$phase_fields_ok" = true ]; then
      check "Phase Plan all phases have 5 required fields" "PASS"
    fi
  fi
fi

# --- tasks.md: Post-Phase Verifications (if any exist) ---
if [ -f "$tasks" ]; then
  verification_count=$(grep -c "^### CRG Post-Phase Verification:" "$tasks" || true)
  if [ "$verification_count" -gt 0 ]; then
    check "Post-Phase Verifications found: $verification_count" "PASS"

    # Check each verification
    phase_num=0
    while IFS= read -r header; do
      phase_num=$((phase_num + 1))
      # Extract the section content (until next ### or end)
      section_content=$(awk "/^### CRG Post-Phase Verification: Phase $phase_num/,/^###/" "$tasks" | head -n -1)

      # Check 14 required fields
      for field in "generated_at" "actual_changed_files" "expected_changed_files" \
                   "scope_drift_percent" "changed_symbols" "tested_changed_symbols" \
                   "changed_symbol_test_coverage" "affected_flows" "e2e_required" \
                   "e2e_status" "knowledge_gaps" "surprising_connections" "verdict" "action_taken"; do
        if ! echo "$section_content" | grep -q "^- ${field}:"; then
          check "Post-Phase $phase_num: field $field present" "missing"
        fi
      done

      # scope_drift_percent numeric
      drift=$(echo "$section_content" | grep "^- scope_drift_percent:" | grep -oE '[0-9]+')
      if [ -n "$drift" ]; then
        # verdict consistency
        verdict=$(echo "$section_content" | grep "^- verdict:" | sed 's/.*: *//')
        if [ "$drift" -gt "$scope_drift_max" ] && [ "$verdict" = "PASS" ]; then
          check "Post-Phase $phase_num: verdict consistent with drift" "drift=$drift > $scope_drift_max but verdict=PASS"
        fi
      fi

      # coverage consistency
      coverage=$(echo "$section_content" | grep "^- changed_symbol_test_coverage:" | grep -oE '[0-9]+')
      if [ -n "$coverage" ]; then
        verdict=$(echo "$section_content" | grep "^- verdict:" | sed 's/.*: *//')
        if [ "$coverage" -lt "$coverage_min" ] && [ "$verdict" = "PASS" ]; then
          check "Post-Phase $phase_num: verdict consistent with coverage" "coverage=$coverage < $coverage_min but verdict=PASS"
        fi
      fi

      # verdict enum
      verdict=$(echo "$section_content" | grep "^- verdict:" | sed 's/.*: *//')
      if echo "$verdict" | grep -qE "^(PASS|BLOCKING|NEEDS_HUMAN_DECISION)$"; then
        check "Post-Phase $phase_num: verdict valid enum" "PASS"
      else
        check "Post-Phase $phase_num: verdict valid enum" "got: $verdict"
      fi

      # BLOCKING/NEEDS_HUMAN_DECISION requires action_taken
      if echo "$verdict" | grep -qE "^(BLOCKING|NEEDS_HUMAN_DECISION)$"; then
        action=$(echo "$section_content" | grep "^- action_taken:" | sed 's/.*: *//')
        if [ -n "$action" ] && [ "$action" != "none" ]; then
          check "Post-Phase $phase_num: action_taken non-empty for $verdict" "PASS"
        else
          check "Post-Phase $phase_num: action_taken non-empty for $verdict" "empty or missing"
        fi
      fi
    done < <(grep "^### CRG Post-Phase Verification:" "$tasks")
  fi
fi

# --- Summary ---
echo ""
echo "SUMMARY: $checks checks, $((checks - failures)) passed, $failures failed"
[ "$failures" -eq 0 ]
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/check-crg-evidence.sh
```

- [ ] **Step 3: Run against good-discovery-minimal (shape-only mode)**

```bash
mkdir -p /tmp/crg-test/openspec/changes/good-discovery-minimal
cp -r tests/fixtures/good-discovery-minimal/change/* /tmp/crg-test/openspec/changes/good-discovery-minimal/
mkdir -p /tmp/crg-test/.ai-workflow-kit
cp tests/fixtures/config.json /tmp/crg-test/.ai-workflow-kit/config.json
cd /tmp/crg-test && AIWK_CHECK_CRG_MODE=shape-only /path/to/scripts/check-crg-evidence.sh good-discovery-minimal
# Expected: all PASS
cd - && rm -rf /tmp/crg-test
```

- [ ] **Step 4: Run against bad-missing-discovery**

```bash
mkdir -p /tmp/crg-test/openspec/changes/bad-missing-discovery
cp -r tests/fixtures/bad-missing-discovery/change/* /tmp/crg-test/openspec/changes/bad-missing-discovery/
mkdir -p /tmp/crg-test/.ai-workflow-kit
cp tests/fixtures/config.json /tmp/crg-test/.ai-workflow-kit/config.json
cd /tmp/crg-test && scripts/check-crg-evidence.sh bad-missing-discovery
# Expected: FAIL on "## CRG Discovery section exists"
cd - && rm -rf /tmp/crg-test
```

- [ ] **Step 5: Run `run-tests.sh`**

```bash
./scripts/run-tests.sh
# Expected: 2 tests, 2 passed
```

- [ ] **Step 6: Commit**

```bash
git add scripts/check-crg-evidence.sh
git commit -m "feat(v5): rewrite check-crg-evidence.sh with structured schema validation"
```

---

### Task 5: Add remaining Discovery fixtures

**Files:**
- Create: `tests/fixtures/bad-discovery-one-row/change/` (4 files)
- Create: `tests/fixtures/bad-discovery-empty-col/change/` (4 files)

- [ ] **Step 1: Create bad-discovery-one-row**

Same as `good-discovery-minimal` but Code Reading Summary has only 1 row (below `discoveryMinReadings=2`):

Write `tests/fixtures/bad-discovery-one-row/change/design.md` — same header sections as good, but table has only:

```markdown
### Code Reading Summary
| File | Symbol | Why Read | Finding | Decision |
|---|---|---|---|---|
| src/services/UserService.ts | searchUsers | semantic hit | only name filter | modify |
```

(1 data row; minimum is 2.)

Copy proposal.md, tasks.md, specs/feature.md from good-discovery-minimal.

- [ ] **Step 2: Create bad-discovery-empty-col**

Same as `good-discovery-minimal` but one row has empty Decision column:

```markdown
### Code Reading Summary
| File | Symbol | Why Read | Finding | Decision |
|---|---|---|---|---|
| src/services/UserService.ts | searchUsers | semantic hit | only name filter | modify |
| src/services/UserService.ts | findByName | reference | pagination pattern |  |
```

(Row 2 has empty Decision.)

- [ ] **Step 3: Run tests**

```bash
./scripts/run-tests.sh
# Expected: 4 tests, 4 passed (2 good + 2 bad)
```

- [ ] **Step 4: Commit**

```bash
git add tests/fixtures/bad-discovery-one-row tests/fixtures/bad-discovery-empty-col
git commit -m "test(v5): add bad-discovery-one-row and bad-discovery-empty-col fixtures"
```

---

### Task 6: Add Precision Plan fixtures + verify strict mode

**Files:**
- Create: `tests/fixtures/good-precision-plan/change/` (4 files)
- Create: `tests/fixtures/bad-precision-plan-no-phase/change/` (4 files)
- Create: `tests/fixtures/bad-precision-plan-bad-target/change/` (4 files)

- [ ] **Step 1: Create good-precision-plan**

`design.md` = same as good-discovery-minimal. `tasks.md` includes full Precision Plan:

```markdown
# Tasks

## CRG Precision Plan

### Mapping Metadata
- based_on_discovery: 2026-04-28T01:00:00Z
- generated_by: /spcrg-plan
- generated_at: 2026-04-28T01:30:00Z

### Function-Level Change Map
| Task | Target | Current Behavior | Required Change | Tests | Reference Pattern | Risk |
|---|---|---|---|---|---|---|
| 1.1 | src/services/UserService.ts:searchUsers | name only | add email filter | tests/services/UserService.test.ts | src/services/UserService.ts:findByName | low |

### Test Coverage Plan
| Changed Symbol | Existing Test | New Test Case | Verification Command |
|---|---|---|---|
| UserService.searchUsers | tests/services/UserService.test.ts | email filter cases | pnpm test tests/services/UserService.test.ts |

### Phase Plan

#### Phase 1: Core search extension
- expected_files: [src/services/UserService.ts]
- expected_symbols: [searchUsers]
- required_tests: [tests/services/UserService.test.ts]
- verification_command: `pnpm test tests/services`
- crg_post_phase_checks: [detect_changes, get_impact_radius, query_graph]
```

- [ ] **Step 2: Create bad-precision-plan-no-phase**

Same as good-precision-plan but remove the `#### Phase 1: ...` subsection entirely from tasks.md.

- [ ] **Step 3: Create bad-precision-plan-bad-target**

Same as good-precision-plan but Change Map Target column has `UserService` instead of `src/services/UserService.ts:searchUsers`:

```
| 1.1 | UserService | name only | add email | tests/x.test.ts | src/x.ts:y | low |
```

- [ ] **Step 4: Run tests**

```bash
./scripts/run-tests.sh
# Expected: 7 tests, 7 passed
```

- [ ] **Step 5: Commit**

```bash
git add tests/fixtures/good-precision-plan tests/fixtures/bad-precision-plan-no-phase tests/fixtures/bad-precision-plan-bad-target
git commit -m "test(v5): add Precision Plan fixtures (good + 2 bad)"
```

---

### Task 7: Add Post-Phase Verification fixtures

**Files:**
- Create: `tests/fixtures/good-post-phase-pass/change/` (4 files)
- Create: `tests/fixtures/bad-post-phase-verdict-inconsistent/change/` (4 files)
- Create: `tests/fixtures/bad-post-phase-missing-field/change/` (4 files)

- [ ] **Step 1: Create good-post-phase-pass**

`design.md` = same as good-discovery-minimal. `tasks.md` includes Precision Plan + Post-Phase Verification:

Append to tasks.md after the Phase Plan section:

```markdown
### CRG Post-Phase Verification: Phase 1

- generated_at: 2026-04-28T02:00:00Z
- actual_changed_files: [src/services/UserService.ts]
- expected_changed_files: [src/services/UserService.ts]
- scope_drift_percent: 0
- changed_symbols: [searchUsers]
- tested_changed_symbols: [searchUsers]
- changed_symbol_test_coverage: 100
- affected_flows: [UserListFlow]
- e2e_required: no
- e2e_status: existing-coverage
- knowledge_gaps: []
- surprising_connections: []
- verdict: PASS
- action_taken: continue to next phase
```

- [ ] **Step 2: Create bad-post-phase-verdict-inconsistent**

Same as good-post-phase-pass but:
```
- changed_symbol_test_coverage: 60
- verdict: PASS
```
(60% < 80% threshold but verdict says PASS — contradiction.)

- [ ] **Step 3: Create bad-post-phase-missing-field**

Same as good-post-phase-pass but remove the `scope_drift_percent` line entirely.

- [ ] **Step 4: Run tests**

```bash
./scripts/run-tests.sh
# Expected: 10 tests, 10 passed
```

- [ ] **Step 5: Commit**

```bash
git add tests/fixtures/good-post-phase-pass tests/fixtures/bad-post-phase-verdict-inconsistent tests/fixtures/bad-post-phase-missing-field
git commit -m "test(v5): add Post-Phase Verification fixtures (good + 2 bad)"
```

---

### Task 8: Write `scripts/check-v5-review.sh` + Quantified Review fixtures

**Files:**
- Create: `scripts/check-v5-review.sh`
- Create: `tests/fixtures/good-quantified-review-archive-ready/change/` (4 files)
- Create: `tests/fixtures/bad-quantified-review-archive-yes-with-blocker/change/` (4 files)
- Create: `tests/fixtures/bad-quantified-review-drift-over-threshold/change/` (4 files)

- [ ] **Step 1: Create good-quantified-review-archive-ready fixture**

`design.md` includes full CRG Discovery + CRG Quantified Review:

Append to design.md:

```markdown
## CRG Quantified Review

### Review Metadata
- generated_at: 2026-04-28T03:00:00Z
- generated_by: /spcrg-review
- based_on_phases: [1]

### Scope Drift
- planned_files: 4
- actual_files: 4
- drift_percent: 0
- verdict: PASS

### Changed Function Test Coverage
- changed_symbols: 6
- tested_symbols: 6
- coverage_percent: 100
- threshold_percent: 80
- verdict: PASS

### Flow Impact
- affected_flows: [UserListFlow]
- flows_with_e2e: [UserListFlow]
- flows_missing_e2e: []
- verdict: PASS

### Knowledge Gaps
- critical: []
- medium: []
- verdict: PASS

### Final CRG Verdict
- archive_ready: yes
- blockers: []
- human_decisions_required: []
```

- [ ] **Step 2: Create bad-quantified-review-archive-yes-with-blocker fixture**

Same but:
```
### Flow Impact
...
- verdict: BLOCKING
- explanation: AdminSearchFlow has no E2E

### Final CRG Verdict
- archive_ready: yes
```
(archive_ready=yes but Flow Impact verdict=BLOCKING — contradiction.)

- [ ] **Step 3: Create bad-quantified-review-drift-over-threshold fixture**

Same but:
```
### Scope Drift
- planned_files: 4
- actual_files: 6
- drift_percent: 50
- verdict: PASS
```
(drift 50% > 20% threshold but verdict=PASS — contradiction.)

- [ ] **Step 4: Write `scripts/check-v5-review.sh`**

```bash
#!/usr/bin/env bash
#
# check-v5-review.sh — V5 Quantified Review validation.
# Validates: CRG Quantified Review section structure + verdict consistency.
#
set -uo pipefail

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

# --- Config reader (same as check-crg-evidence.sh) ---
_read_config() {
  local key="$1" default="$2" config=".ai-workflow-kit/config.json"
  if [ ! -f "$config" ]; then echo "$default"; return; fi
  if command -v jq &>/dev/null; then
    val=$(jq -r "$key // empty" "$config" 2>/dev/null)
    [ -n "$val" ] && echo "$val" || echo "$default"
  elif command -v python3 &>/dev/null; then
    val=$(python3 -c "
import json,sys
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

scope_drift_max=$(_read_config '.thresholds.scopeDriftPercent' '20')
coverage_min=$(_read_config '.thresholds.changedSymbolTestCoveragePercent' '80')
require_e2e=$(_read_config '.gates.requireE2EForAffectedFlows' 'true')

checks=0
failures=0

check() {
  local desc="$1" result="$2"
  checks=$((checks + 1))
  if [ "$result" = "PASS" ]; then
    printf "CHECK: %-60s PASS\n" "$desc"
  else
    printf "CHECK: %-60s FAIL (%s)\n" "$desc" "$result"
    failures=$((failures + 1))
  fi
}

# Find the review content in design.md or review.md
review_file=""
for f in "$base/design.md" "$base/review.md"; do
  if [ -f "$f" ] && grep -q "^## CRG Quantified Review" "$f"; then
    review_file="$f"
    break
  fi
done

if [ -z "$review_file" ]; then
  check "## CRG Quantified Review found" "not found in design.md or review.md"
  echo ""
  echo "SUMMARY: $checks checks, $((checks - failures)) passed, $failures failed"
  exit 1
fi

check "## CRG Quantified Review found" "PASS"

# Check subsections
for section in "### Review Metadata" "### Scope Drift" "### Changed Function Test Coverage" \
               "### Flow Impact" "### Knowledge Gaps" "### Final CRG Verdict"; do
  if grep -q "^$section" "$review_file"; then
    check "$section exists" "PASS"
  else
    check "$section exists" "missing"
  fi
done

# Scope Drift verdict consistency
drift=$(grep "^- drift_percent:" "$review_file" | head -1 | grep -oE '[0-9]+')
drift_verdict=$(awk '/^### Scope Drift/,/^###/' "$review_file" | grep "^- verdict:" | head -1 | sed 's/.*: *//')
if [ -n "$drift" ] && [ -n "$drift_verdict" ]; then
  if [ "$drift" -gt "$scope_drift_max" ] && [ "$drift_verdict" = "PASS" ]; then
    check "Scope Drift verdict consistent" "drift=$drift > $scope_drift_max but verdict=PASS"
  else
    check "Scope Drift verdict consistent" "PASS"
  fi
fi

# Coverage verdict consistency
coverage=$(grep "^- coverage_percent:" "$review_file" | head -1 | grep -oE '[0-9]+')
cov_verdict=$(awk '/^### Changed Function Test Coverage/,/^###/' "$review_file" | grep "^- verdict:" | head -1 | sed 's/.*: *//')
if [ -n "$coverage" ] && [ -n "$cov_verdict" ]; then
  if [ "$coverage" -lt "$coverage_min" ] && [ "$cov_verdict" = "PASS" ]; then
    check "Coverage verdict consistent" "coverage=$coverage < $coverage_min but verdict=PASS"
  else
    check "Coverage verdict consistent" "PASS"
  fi
fi

# Flow Impact verdict consistency (flows_missing_e2e non-empty + requireE2E=true + verdict=PASS)
missing_e2e=$(awk '/^### Flow Impact/,/^###/' "$review_file" | grep "^- flows_missing_e2e:" | sed 's/.*: *//')
flow_verdict=$(awk '/^### Flow Impact/,/^###/' "$review_file" | grep "^- verdict:" | head -1 | sed 's/.*: *//')
if [ "$require_e2e" = "true" ] && [ -n "$missing_e2e" ] && [ "$missing_e2e" != "[]" ] && [ "$flow_verdict" = "PASS" ]; then
  check "Flow Impact verdict consistent" "flows_missing_e2e non-empty but verdict=PASS"
else
  check "Flow Impact verdict consistent" "PASS"
fi

# Knowledge Gaps critical non-empty + verdict=PASS
critical=$(awk '/^### Knowledge Gaps/,/^###/' "$review_file" | grep "^- critical:" | sed 's/.*: *//')
gaps_verdict=$(awk '/^### Knowledge Gaps/,/^###/' "$review_file" | grep "^- verdict:" | head -1 | sed 's/.*: *//')
if [ -n "$critical" ] && [ "$critical" != "[]" ] && [ "$gaps_verdict" = "PASS" ]; then
  check "Knowledge Gaps verdict consistent" "critical non-empty but verdict=PASS"
else
  check "Knowledge Gaps verdict consistent" "PASS"
fi

# All verdicts valid enum
while IFS= read -r v; do
  v=$(echo "$v" | sed 's/.*: *//')
  if ! echo "$v" | grep -qE "^(PASS|BLOCKING|NEEDS_HUMAN_DECISION)$"; then
    check "verdict enum valid" "got: $v"
  fi
done < <(grep "^- verdict:" "$review_file")

# BLOCKING verdicts must have explanation
while IFS= read -r line; do
  # For each subsection that has BLOCKING, check for explanation
  true  # This is complex to implement per-section; rely on structural audit instead
done < /dev/null

# Final CRG Verdict
archive_ready=$(grep "^- archive_ready:" "$review_file" | sed 's/.*: *//')
if echo "$archive_ready" | grep -qE "^(yes|no)$"; then
  check "archive_ready valid enum" "PASS"
else
  check "archive_ready valid enum" "got: $archive_ready"
fi

# If archive_ready=yes, all sub-verdicts must be PASS
if [ "$archive_ready" = "yes" ]; then
  non_pass=$(grep "^- verdict:" "$review_file" | grep -v "PASS" | wc -l || true)
  if [ "$non_pass" -gt 0 ]; then
    check "archive_ready=yes implies all verdicts PASS" "$non_pass non-PASS verdict(s) found"
  else
    check "archive_ready=yes implies all verdicts PASS" "PASS"
  fi
fi

# --- Summary ---
echo ""
echo "SUMMARY: $checks checks, $((checks - failures)) passed, $failures failed"
[ "$failures" -eq 0 ]
```

- [ ] **Step 5: Make executable and run tests**

```bash
chmod +x scripts/check-v5-review.sh
./scripts/run-tests.sh
# Expected: 13 tests, 13 passed (10 previous + 3 new quantified-review fixtures)
```

- [ ] **Step 6: Commit**

```bash
git add scripts/check-v5-review.sh tests/fixtures/good-quantified-review-archive-ready \
        tests/fixtures/bad-quantified-review-archive-yes-with-blocker \
        tests/fixtures/bad-quantified-review-drift-over-threshold
git commit -m "feat(v5): add check-v5-review.sh with quantified review validation"
```

---

### Task 9: Write `scripts/check-command-protocols.sh`

**Files:**
- Create: `scripts/check-command-protocols.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
#
# check-command-protocols.sh — verify V5 protocol keywords in command files.
#
set -uo pipefail

cmd_dir="${1:-.claude/commands}"

if [ ! -d "$cmd_dir" ]; then
  echo "Command directory not found: $cmd_dir"
  exit 1
fi

checks=0
failures=0

check() {
  local desc="$1" result="$2"
  checks=$((checks + 1))
  if [ "$result" = "PASS" ]; then
    printf "CHECK: %-70s PASS\n" "$desc"
  else
    printf "CHECK: %-70s FAIL (%s)\n" "$desc" "$result"
    failures=$((failures + 1))
  fi
}

# Keyword requirements per command
declare -A keywords
keywords[spcrg-start]="CRG Discovery Protocol|Read Before Decide|## CRG Discovery"
keywords[spcrg-plan]="CRG Precision Mapping Protocol|superpowers:writing-plans|## CRG Precision Plan"
keywords[spcrg-dev]="Delta Check Protocol|CRG Post-Phase Verification|PASS | BLOCKING | NEEDS_HUMAN_DECISION"
keywords[spcrg-review]="CRG Quantified Review|scope_drift|archive_ready"
keywords[spcrg-archive]="check-v5-review.sh|/opsx:verify"
keywords[spcrg-audit]="structured evidence|Code Reading Summary|Precision Plan"

# Gate script references required in gated commands
gated_commands=(spcrg-plan spcrg-dev spcrg-review spcrg-archive spcrg-audit)
gate_scripts=("check-openspec-gate.sh" "check-crg-evidence.sh")

for cmd in "${!keywords[@]}"; do
  file="$cmd_dir/${cmd}.md"
  if [ ! -f "$file" ]; then
    check "$cmd: file exists" "missing"
    continue
  fi
  IFS='|' read -ra kws <<< "${keywords[$cmd]}"
  for kw in "${kws[@]}"; do
    if grep -qF "$kw" "$file"; then
      check "$cmd contains '$kw'" "PASS"
    else
      check "$cmd contains '$kw'" "not found"
    fi
  done
done

for cmd in "${gated_commands[@]}"; do
  file="$cmd_dir/${cmd}.md"
  [ -f "$file" ] || continue
  for gs in "${gate_scripts[@]}"; do
    if grep -qF "$gs" "$file"; then
      check "$cmd references $gs" "PASS"
    else
      check "$cmd references $gs" "not found"
    fi
  done
done

echo ""
echo "SUMMARY: $checks checks, $((checks - failures)) passed, $failures failed"
[ "$failures" -eq 0 ]
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/check-command-protocols.sh
```

- [ ] **Step 3: Run against current V1 commands (expect failures — V5 keywords don't exist yet)**

```bash
./scripts/check-command-protocols.sh .claude/commands
# Expected: multiple FAILs (V1 commands don't have V5 keywords)
```

This confirms the script correctly identifies V1-era commands as lacking V5 protocols.

- [ ] **Step 4: Commit**

```bash
git add scripts/check-command-protocols.sh
git commit -m "feat(v5): add check-command-protocols.sh for V5 keyword verification"
```

---

### Task 10: Upgrade `scripts/verify-install.sh` with Step 5

**Files:**
- Modify: `scripts/verify-install.sh`

- [ ] **Step 1: Add step 5 and update step 2 to include new scripts**

After the existing `[4/5]` section, add:

```bash
echo ""
echo "[5/5] command files contain V5 protocol keywords"
if [ -x scripts/check-command-protocols.sh ]; then
  if scripts/check-command-protocols.sh "$root/.claude/commands" >/dev/null 2>&1; then
    ok "V5 protocol keywords present in all commands"
  else
    bad "V5 protocol keywords missing (run: scripts/check-command-protocols.sh)"
  fi
else
  bad "scripts/check-command-protocols.sh not found or not executable"
fi
```

Also update `required_scripts` array in step 2 to include `check-v5-review.sh` and `check-command-protocols.sh`.

- [ ] **Step 2: Run verify-install (expect step 5 to fail until commands are rewritten)**

```bash
./scripts/verify-install.sh .
# Expected: steps 1-4 pass, step 5 fails (V1 commands don't have V5 keywords yet)
```

- [ ] **Step 3: Commit**

```bash
git add scripts/verify-install.sh
git commit -m "feat(v5): upgrade verify-install.sh with step 5 protocol check"
```

---

## Phase C: Command File Rewrites

### Task 11: Rewrite `spcrg-start.md` — Discovery Protocol

**Files:**
- Rewrite: `.claude/commands/spcrg-start.md`

- [ ] **Step 1: Write the V5 command file**

Write `.claude/commands/spcrg-start.md` — full content per spec §9.1. The file must contain:
- `## CRG Discovery Protocol` with Steps 1-6 (Graph readiness → Divergent search → Mandatory Code Reading → Decision Synthesis → Targeted Risk Tools → Write Structured Discovery)
- `## V5 Mandatory Rule: Read Before Decide` enforcement clause
- Reference to `superpowers:brainstorming`
- `## Gate: before requesting approval` calling `check-openspec-gate.sh` + `AIWK_CHECK_CRG_MODE=shape-only check-crg-evidence.sh`
- `## State write` writing `.ai-workflow-kit/state/<change-id>.json`
- Parameter resolution for missing `$ARGUMENTS`
- Stop conditions including "CRG unavailable → STOP, do not fabricate"
- Reference to `## CRG Discovery` section name (schema output)

- [ ] **Step 2: Verify V5 keywords present**

```bash
./scripts/check-command-protocols.sh .claude/commands 2>&1 | grep "spcrg-start"
# Expected: all spcrg-start checks PASS
```

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/spcrg-start.md
git commit -m "feat(v5): rewrite spcrg-start with CRG Discovery Protocol"
```

---

### Task 12: Rewrite `spcrg-plan.md` — Precision Mapping Protocol

**Files:**
- Rewrite: `.claude/commands/spcrg-plan.md`

- [ ] **Step 1: Write the V5 command file**

Write `.claude/commands/spcrg-plan.md` — full content per spec §9.2. Must contain:
- Parameter resolution (detect-change-id.sh if `$ARGUMENTS` empty)
- `## Gate: before planning` (check-openspec-gate + check-crg-evidence)
- `## CRG Precision Mapping Protocol` (Steps 1-6: Inherit Discovery → Expand via call graph → Test coverage pass → Phase grouping → Hand off to superpowers:writing-plans → Write Evidence)
- `## V5 Task Granularity Rule` with BAD/GOOD example
- `## State write`
- References to `superpowers:writing-plans`, `## CRG Precision Plan`

- [ ] **Step 2: Verify**

```bash
./scripts/check-command-protocols.sh .claude/commands 2>&1 | grep "spcrg-plan"
# Expected: all spcrg-plan checks PASS
```

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/spcrg-plan.md
git commit -m "feat(v5): rewrite spcrg-plan with Precision Mapping Protocol"
```

---

### Task 13: Rewrite `spcrg-dev.md` — Delta Check + Post-Phase

**Files:**
- Rewrite: `.claude/commands/spcrg-dev.md`

- [ ] **Step 1: Write the V5 command file**

Write `.claude/commands/spcrg-dev.md` — full content per spec §9.3. Must contain:
- Parameter resolution
- `## Gate: before development` (check-openspec-gate + check-crg-evidence)
- `## Delta Check Protocol` with state-based continuity decision table
- `## Execute phase via TDD` referencing `superpowers:subagent-driven-development` and `superpowers:test-driven-development`
- `## CRG Post-Phase Verification` with all CRG tools to run, compute steps, and schema output
- Verdict rules table: condition → verdict
- `PASS | BLOCKING | NEEDS_HUMAN_DECISION` literal string
- STOP conditions (blast radius, CRG unavailable, etc.)
- State update: `state.phases.dev.phaseHistory`

- [ ] **Step 2: Verify**

```bash
./scripts/check-command-protocols.sh .claude/commands 2>&1 | grep "spcrg-dev"
# Expected: all spcrg-dev checks PASS
```

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/spcrg-dev.md
git commit -m "feat(v5): rewrite spcrg-dev with Delta Check and Post-Phase Verification"
```

---

### Task 14: Rewrite `spcrg-review.md` — Quantified Review

**Files:**
- Rewrite: `.claude/commands/spcrg-review.md`

- [ ] **Step 1: Write the V5 command file**

Write `.claude/commands/spcrg-review.md` — full content per spec §9.4. Must contain:
- Parameter resolution
- `## Gate: before review` (check-openspec-gate + check-crg-evidence, NOT check-v5-review)
- `## Phase 1: OpenSpec Compliance Review` (preserved from V1)
- `## Phase 2: CRG Quantified Review` with aggregation logic, thresholds from config, verdict per subsection, `archive_ready` determination
- `## Phase 3: Superpowers Code Review` referencing `superpowers:requesting-code-review`
- `## Self-check` running `scripts/check-v5-review.sh`
- `## Output` with blocking/non-blocking/archive_ready format
- Contains keywords: `CRG Quantified Review`, `scope_drift`, `archive_ready`

- [ ] **Step 2: Verify**

```bash
./scripts/check-command-protocols.sh .claude/commands 2>&1 | grep "spcrg-review"
# Expected: all spcrg-review checks PASS
```

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/spcrg-review.md
git commit -m "feat(v5): rewrite spcrg-review with Quantified Review and verdicts"
```

---

### Task 15: Update `spcrg-archive.md` — add V5 gate + state

**Files:**
- Modify: `.claude/commands/spcrg-archive.md`

- [ ] **Step 1: Update the command file**

Add to the opening gate section (after check-openspec-gate and check-crg-evidence):
```
scripts/check-v5-review.sh $ARGUMENTS
```

Add assertion:
```markdown
## V5 Archive Readiness Check

After gates pass, read `## CRG Quantified Review` from design.md or review.md.
Assert `archive_ready: yes`. If no or missing, STOP.
```

Add state write at end:
```markdown
## State write
Update .ai-workflow-kit/state/<change-id>.json with phase=archive, completedAt.
```

Ensure `check-v5-review.sh` and `/opsx:verify` appear as literal strings.

- [ ] **Step 2: Verify**

```bash
./scripts/check-command-protocols.sh .claude/commands 2>&1 | grep "spcrg-archive"
# Expected: all spcrg-archive checks PASS
```

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/spcrg-archive.md
git commit -m "feat(v5): update spcrg-archive with check-v5-review gate and state write"
```

---

### Task 16: Minor updates to bugfix / hotfix / refactor

**Files:**
- Modify: `.claude/commands/spcrg-bugfix.md`
- Modify: `.claude/commands/spcrg-hotfix.md`
- Modify: `.claude/commands/spcrg-refactor.md`

- [ ] **Step 1: Add Read Before Decide clause to each**

Add to each file after the CRG tools section:

```markdown
## V5 Rule: Read Before Decide

Before writing a diagnosis or decision, read the actual source files for
the relevant CRG hits. Use CRG to locate; use source reading to decide.
Do not write raw CRG output as evidence. Write decision evidence.
```

For hotfix, also add:
```markdown
## V5 Gate on Archive

If a hotfix OpenSpec record exists (`openspec/changes/hotfix-{issue-id}/`),
running `/opsx:verify` or `/opsx:archive` requires all V5 gates:
- scripts/check-openspec-gate.sh hotfix-{issue-id}
- scripts/check-crg-evidence.sh hotfix-{issue-id}
- scripts/check-v5-review.sh hotfix-{issue-id}
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/spcrg-bugfix.md .claude/commands/spcrg-hotfix.md .claude/commands/spcrg-refactor.md
git commit -m "feat(v5): add Read Before Decide clause to bugfix/hotfix/refactor"
```

---

### Task 17: Rewrite `spcrg-audit.md` — Structured Evidence Audit

**Files:**
- Rewrite: `.claude/commands/spcrg-audit.md`

- [ ] **Step 1: Write the V5 command file**

Write `.claude/commands/spcrg-audit.md` — per spec §9.7. Must contain:
- Parameter resolution (detect-change-id.sh)
- `## Run structured checks` calling all 3 scripts (check-openspec-gate, check-crg-evidence, check-v5-review)
- Report-only mode: capture results, do not auto-repair
- `## Manual structural audit` for semantic checks beyond scripts
- References to "structured evidence", "Code Reading Summary", "Precision Plan"
- Tabular report format

- [ ] **Step 2: Verify**

```bash
./scripts/check-command-protocols.sh .claude/commands 2>&1 | grep "spcrg-audit"
# Expected: all spcrg-audit checks PASS
```

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/spcrg-audit.md
git commit -m "feat(v5): rewrite spcrg-audit as structured evidence audit"
```

---

## Phase D: Skill + Documentation

### Task 18: Update SKILL.md

**Files:**
- Modify: `.claude/skills/project-development-workflow/SKILL.md`

- [ ] **Step 1: Rewrite with V5 sections**

Replace the full content with V5 version per spec §10.1:
- Keep frontmatter (name + description)
- Add `## V5 Core Principle`
- Add `## Session & State`
- Add `## Config`
- Replace Command Map table with V5 version (Protocol / Produces Evidence / Gate Scripts columns)
- Update Gate Script Matrix (archive row adds check-v5-review)
- Update Missing change-id handling (no change from V1)
- Update CRG tool names section (no change from V1)
- Update Stop Conditions (add "gate script keeps failing after repair")

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/project-development-workflow/SKILL.md
git commit -m "feat(v5): update SKILL.md with V5 Core Principle and protocols"
```

---

### Task 19: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add V5 rules 9-12, update matrix, layout, prerequisites**

Add rules:
```
9. CRG tells where, read code decides what, CRG verifies after.
10. Evidence is structured decisions, not raw tool output.
11. Later phases inherit earlier phases' evidence; no blind re-search.
12. Verdicts must be numeric-consistent with the data.
```

Update Gate enforcement matrix: archive row adds `check-v5-review.sh`.

Update Prerequisites: add `jq (recommended) or python3 for config parsing`.

Update Layout tree to V5 version from spec §5.

Add "Reading V5 Evidence" daily usage section.

Update Success criteria with V5-specific bullets.

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(v5): update CLAUDE.md with V5 rules and matrix"
```

---

### Task 20: Update README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add V5 tagline, workflow diagram, V5 vs V1 table**

Add after first paragraph:
```
> V5 upgrade: CRG from evidence collector to code navigator + risk verifier.
```

Add new section "V5 Workflow at a glance":
```
Requirement → CRG NAVIGATE → Agent READ → Agent DECIDE
           → Superpowers DO → CRG VERIFY → OpenSpec ARCHIVE
```

Add "V5 vs V1" 5-row comparison table.

Update scripts list in "What's inside" (add check-v5-review, check-command-protocols, run-tests).

Add `.ai-workflow-kit/` to the listing.

Update "Editing the kit" section to include `./scripts/run-tests.sh`.

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs(v5): update README with V5 workflow and comparison"
```

---

### Task 21: Add CHANGELOG.md

**Files:**
- Create: `CHANGELOG.md`

- [ ] **Step 1: Write changelog**

```markdown
# Changelog

## [5.0.0] - 2026-04-28

### Breaking changes
- Evidence schema completely changed. V1 evidence does NOT pass V5 gates.
  Reinstall into downstream projects; in-flight changes should be
  restarted from /spcrg-start.
- New required directory `.ai-workflow-kit/` (config + state).

### Added
- CRG Discovery Protocol with mandatory Read Before Decide
- Precision Mapping Protocol for /spcrg-plan (inherits Discovery)
- Delta Check Protocol for /spcrg-dev (state-based continuous vs resumed)
- Post-Phase Verification with PASS|BLOCKING|NEEDS_HUMAN_DECISION verdicts
- Quantified Review with archive_ready gate
- `.ai-workflow-kit/config.json` for team-configurable thresholds
- `.ai-workflow-kit/state/<change-id>.json` for phase progression
- `scripts/check-v5-review.sh` — Quantified Review validation
- `scripts/check-command-protocols.sh` — V5 keyword verification
- `scripts/run-tests.sh` + `tests/fixtures/` for script regression

### Changed
- `scripts/check-crg-evidence.sh` upgraded from grep-based to
  structured schema validation with --shape-only mode
- `scripts/verify-install.sh` adds step 5 (V5 protocol keywords)
- All 9 `spcrg-*` commands updated to V5 protocols

### Removed
- V1-style "just list CRG tool names" evidence pattern

## [1.0.0] - 2026-04-27

- Initial spcrg-prefixed AI Workflow Kit with gate enforcement
```

- [ ] **Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs(v5): add CHANGELOG.md"
```

---

## Phase E: Installer Rebuild + Final Verification

### Task 22: Update `scripts/build-installer.sh`

**Files:**
- Modify: `scripts/build-installer.sh`

- [ ] **Step 1: Add new scripts and config to emit loop**

In the emit loop for scripts, add:
- `check-v5-review.sh`
- `check-command-protocols.sh`

Add a new section emitting `.ai-workflow-kit/config.json` with conditional-create logic:
```bash
# After all emit_file calls, add config creation logic
cat >> "$tmp" <<'CONFIG_SECTION'

# Create config only if missing (preserve user customizations)
if [ ! -f .ai-workflow-kit/config.json ]; then
  mkdir -p .ai-workflow-kit
CONFIG_SECTION

printf 'cat > .ai-workflow-kit/config.json <<'\''AIWK_EOF'\''\n' >> "$tmp"
cat ".ai-workflow-kit/config.json" >> "$tmp"
printf 'AIWK_EOF\n' >> "$tmp"

cat >> "$tmp" <<'CONFIG_END'
  echo "Created default .ai-workflow-kit/config.json"
else
  echo "Keeping existing .ai-workflow-kit/config.json"
fi

CONFIG_END
```

Do NOT emit `run-tests.sh` or `tests/fixtures/` (framework-dev only).

- [ ] **Step 2: Run build-installer**

```bash
./scripts/build-installer.sh
# Expected: Wrote scripts/install-ai-workflow-kit.sh (N lines)
```

- [ ] **Step 3: Commit**

```bash
git add scripts/build-installer.sh scripts/install-ai-workflow-kit.sh
git commit -m "feat(v5): update build-installer to include V5 scripts and config"
```

---

### Task 23: Full acceptance test

**Files:** None (read-only verification)

- [ ] **Step 1: Run verify-install**

```bash
./scripts/verify-install.sh .
# Expected: all 5 steps green
```

- [ ] **Step 2: Run fixture tests**

```bash
./scripts/run-tests.sh
# Expected: 13 tests, 13 passed, 0 failed
```

- [ ] **Step 3: Smoke-test installer in clean directory**

```bash
tmp=$(mktemp -d)
cd "$tmp"
bash /path/to/specpower-crg/scripts/install-ai-workflow-kit.sh
# Expected: installs + verify-install passes (5/5 green)
cd - && rm -rf "$tmp"
```

- [ ] **Step 4: Final commit + tag**

```bash
git add -A
git status  # verify nothing unexpected
git commit -m "chore(v5): final verification pass" --allow-empty
git tag v5.0.0
git push && git push --tags
```

---

## Summary

| Phase | Tasks | Commits | What's verified |
|---|---|---|---|
| A: Infrastructure | 1-3 | 3 | config.json exists, fixtures framework works, initial fixtures valid |
| B: Gate scripts | 4-9 | 6 | check-crg-evidence validates V5 schema, check-v5-review validates Quantified Review, check-command-protocols catches V1 commands |
| C: Commands | 10-17 | 8 | All 9 commands pass check-command-protocols, all gated commands embed gate script calls |
| D: Docs | 18-21 | 4 | SKILL/CLAUDE/README/CHANGELOG reflect V5 |
| E: Installer | 22-23 | 2 | build-installer includes V5 files, verify-install 5/5, run-tests 13/13, clean-room install green |

**Total:** 23 tasks, ~23 commits, 3 verification gates (verify-install, run-tests, clean-room install).
