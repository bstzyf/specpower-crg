#!/usr/bin/env bash
# Real integration tests using actual claude -p instances.
# Prompts reference `.claude/commands/spcrg-loop.md` explicitly to avoid Claude
# interpreting "/spcrg-loop" as an absolute filesystem path and doing broad find.

set -uo pipefail

cd "$(dirname "$0")"

pass=0
fail=0
failed_tests=()

_pass() { printf "  \033[32mPASS\033[0m  %s\n" "$1"; pass=$((pass+1)); }
_fail() { printf "  \033[31mFAIL\033[0m  %s\n          reason: %s\n" "$1" "$2"; fail=$((fail+1)); failed_tests+=("$1"); }
_hdr()  { printf "\n\033[1;34m[%s]\033[0m %s\n" "$1" "$2"; }

# Each claude -p call is scoped to the project directory and uses a tight prompt
# that includes explicit file references to avoid unnecessary tool calls.
_claude_ask() {
  local prompt="$1"
  claude -p --permission-mode bypassPermissions "$prompt" 2>&1
}

_snapshot() {
  cp -r openspec/changes "/tmp/.spcrg-snap-$$"
}
_restore() {
  rm -rf openspec/changes
  mv "/tmp/.spcrg-snap-$$" openspec/changes
}

echo "========================================"
echo "  REAL Integration Tests — Claude CLI"
echo "========================================"
echo "claude CLI: $(claude --version 2>&1 | head -1)"

# ============================================================================
# G: Gate / Refusal Behavior
# ============================================================================

_hdr "G1" "Loop refuses when Precision Plan missing"
_snapshot
cat > openspec/changes/add-search/tasks.md << 'EOF'
# Tasks
(no Precision Plan)

- [ ] 1.1 todo
EOF
output=$(_claude_ask "The file .claude/commands/spcrg-loop.md has a 'Verify Precision Plan exists' section. Given that openspec/changes/add-search/tasks.md has NO '## CRG Precision Plan' section, what does that section say you should do? Answer in one sentence. Do not search the filesystem — just read the two files I named.")
if echo "$output" | grep -qiE "(spcrg-plan.*first|run.*plan|stop|tell the user|no.*precision plan)"; then
  _pass "G1 Loop refuses when Precision Plan missing"
else
  _fail "G1" "output: $(echo "$output" | head -3 | tr '\n' ' ' | cut -c1-200)"
fi
_restore

_hdr "G2" "Loop refuses when CRG Discovery missing"
_snapshot
cat > openspec/changes/add-search/design.md << 'EOF'
# Design (no CRG Discovery)
EOF
output=$(_claude_ask "The file .claude/commands/spcrg-loop.md has a 'Gate: before loop' section that runs check-crg-evidence.sh. If openspec/changes/add-search/design.md is missing the '## CRG Discovery' section, what should the loop command do? One sentence. Read only the two files I named.")
if echo "$output" | grep -qiE "(gate.*fail|not.*start|stop|refuse|missing.*discovery|start.*first)"; then
  _pass "G2 Loop refuses when CRG Discovery missing"
else
  _fail "G2" "output: $(echo "$output" | head -3 | tr '\n' ' ' | cut -c1-200)"
fi
_restore

_hdr "G3" "Archive refuses when archive_ready=no"
_snapshot
cat >> openspec/changes/add-search/design.md << 'EOF'

## CRG Quantified Review

### Review Metadata
- generated_at: 2026-04-30T12:00:00Z
- generated_by: /spcrg-review
- based_on_phases: [1, 2]

### Scope Drift
- planned_files: 3
- actual_files: 3
- drift_percent: 0
- verdict: PASS
- explanation: n/a

### Changed Function Test Coverage
- changed_symbols: 2
- tested_symbols: 1
- coverage_percent: 50
- threshold_percent: 80
- verdict: BLOCKING
- explanation: insufficient coverage

### Flow Impact
- affected_flows: []
- flows_with_e2e: []
- flows_missing_e2e: []
- verdict: PASS
- explanation: n/a

### Knowledge Gaps
- critical: []
- medium: []
- verdict: PASS
- explanation: n/a

### Final CRG Verdict
- archive_ready: no
- blockers: [coverage below 80]
- human_decisions_required: []
EOF
output=$(_claude_ask "The file .claude/commands/spcrg-archive.md has a 'V5 Archive Readiness Check' section. Given that openspec/changes/add-search/design.md has 'archive_ready: no' in its Quantified Review, what does the archive command do per that section? One sentence. Read only the two files I named.")
if echo "$output" | grep -qiE "(stop|refuse|archive blocked|block|not proceed|cannot archive|run.*review)"; then
  _pass "G3 Archive refuses when archive_ready=no"
else
  _fail "G3" "output: $(echo "$output" | head -3 | tr '\n' ' ' | cut -c1-200)"
fi
_restore

# ============================================================================
# S: State Detection
# ============================================================================

_hdr "S1" "Empty state → Stage A"
output=$(_claude_ask "Read .claude/commands/spcrg-loop.md decision tree. Read openspec/changes/add-search/tasks.md. All tasks show '- [ ]'. Which decision-tree stage (letter A-H) runs first? Answer only one letter.")
if echo "$output" | grep -qE "(^|[^A-Za-z])A([^A-Za-z]|$)" | head -1 >/dev/null; then
  _pass "S1 Empty state → Stage A"
else
  # Also accept if Claude writes "Stage A" or "阶段 A"
  if echo "$output" | grep -qiE "Stage A|阶段 A|^A$|^A\."; then
    _pass "S1 Empty state → Stage A"
  else
    _fail "S1" "output: $(echo "$output" | head -3 | tr '\n' ' ' | cut -c1-200)"
  fi
fi

_hdr "S2" "All tasks [x] but no PPV → Stage B/C/D/E"
_snapshot
sed -i.bak 's/- \[ \]/- [x]/g' openspec/changes/add-search/tasks.md
output=$(_claude_ask "Read .claude/commands/spcrg-loop.md decision tree. In openspec/changes/add-search/tasks.md all tasks are '[x]' completed but NO '### CRG Post-Phase Verification' section exists. Which stage letter (A-H) runs next? Answer one letter.")
# Accept B (verify tests), C (coverage), D (write PPV), or E (check all phases).
# These are all valid interpretations of "tasks checked but PPV missing".
# A is wrong (tasks already done), F/G/H wrong (evidence incomplete).
if echo "$output" | grep -qiE "Stage [BCDE]|阶段 [BCDE]|^[BCDE]$|^[BCDE]\."; then
  _pass "S2 Tasks done no PPV → Stage B/C/D/E"
else
  _fail "S2" "output: $(echo "$output" | head -3 | tr '\n' ' ' | cut -c1-200)"
fi
_restore

_hdr "S3" "All evidence complete → Stage G/H"
_snapshot
sed -i.bak 's/- \[ \]/- [x]/g' openspec/changes/add-search/tasks.md
cat >> openspec/changes/add-search/tasks.md << 'EOF'

### CRG Post-Phase Verification: Phase 1
- generated_at: 2026-04-30T11:00:00Z
- actual_changed_files: [src/todo-service.js, tests/run.js]
- expected_changed_files: [src/todo-service.js, tests/run.js]
- scope_drift_percent: 0
- changed_symbols: [TodoService.search]
- tested_changed_symbols: [TodoService.search]
- changed_symbol_test_coverage: 100
- affected_flows: []
- e2e_required: no
- e2e_status: existing-coverage
- knowledge_gaps: []
- surprising_connections: []
- verdict: PASS
- action_taken: proceed

### CRG Post-Phase Verification: Phase 2
- generated_at: 2026-04-30T11:30:00Z
- actual_changed_files: [src/index.js, tests/run.js]
- expected_changed_files: [src/index.js, tests/run.js]
- scope_drift_percent: 0
- changed_symbols: [searchHandler]
- tested_changed_symbols: [searchHandler]
- changed_symbol_test_coverage: 100
- affected_flows: [search-todos]
- e2e_required: yes
- e2e_status: existing-coverage
- knowledge_gaps: []
- surprising_connections: []
- verdict: PASS
- action_taken: proceed
EOF
cat >> openspec/changes/add-search/design.md << 'EOF'

## CRG Quantified Review

### Review Metadata
- generated_at: 2026-04-30T12:00:00Z
- generated_by: /spcrg-loop
- based_on_phases: [1, 2]

### Scope Drift
- planned_files: 3
- actual_files: 3
- drift_percent: 0
- verdict: PASS
- explanation: n/a

### Changed Function Test Coverage
- changed_symbols: 2
- tested_symbols: 2
- coverage_percent: 100
- threshold_percent: 80
- verdict: PASS
- explanation: n/a

### Flow Impact
- affected_flows: [search-todos]
- flows_with_e2e: [search-todos]
- flows_missing_e2e: []
- verdict: PASS
- explanation: n/a

### Knowledge Gaps
- critical: []
- medium: []
- verdict: PASS
- explanation: n/a

### Final CRG Verdict
- archive_ready: yes
- blockers: []
- human_decisions_required: []
EOF
output=$(_claude_ask "Read .claude/commands/spcrg-loop.md decision tree. All tasks '[x]', Post-Phase Verifications all PASS, CRG Quantified Review archive_ready=yes. Which stage letter (A-H) runs next? One letter.")
if echo "$output" | grep -qiE "Stage [GH]|阶段 [GH]|^[GH]$|^[GH]\."; then
  _pass "S3 All evidence complete → Stage G/H"
else
  _fail "S3" "output: $(echo "$output" | head -3 | tr '\n' ' ' | cut -c1-200)"
fi
_restore

# ============================================================================
# K: Skill Invocation
# ============================================================================

_hdr "K1" "Stage A uses superpowers:test-driven-development"
output=$(_claude_ask "Read .claude/commands/spcrg-loop.md Stage A. When implementing a single task, which superpowers skill drives the TDD cycle (RED/GREEN/REFACTOR)? Answer just the skill name.")
if echo "$output" | grep -qE "test-driven-development"; then
  _pass "K1 Stage A uses superpowers:test-driven-development"
else
  _fail "K1" "output: $(echo "$output" | head -3 | tr '\n' ' ' | cut -c1-200)"
fi

_hdr "K2" "Phase task orchestration uses subagent-driven-development"
output=$(_claude_ask "Read .claude/commands/spcrg-loop.md Stage A. Which superpowers skill is named as the primary orchestrator for executing the tasks in a phase per the Precision Plan? Answer just the skill name.")
if echo "$output" | grep -qE "subagent-driven-development"; then
  _pass "K2 Tasks orchestrated by subagent-driven-development"
else
  _fail "K2" "output: $(echo "$output" | head -3 | tr '\n' ' ' | cut -c1-200)"
fi

_hdr "K3" "Stage B uses systematic-debugging"
output=$(_claude_ask "Read .claude/commands/spcrg-loop.md Stage B. When verification_command fails, which superpowers skill drives diagnosis and fix? Just the skill name.")
if echo "$output" | grep -qE "systematic-debugging"; then
  _pass "K3 Stage B uses systematic-debugging"
else
  _fail "K3" "output: $(echo "$output" | head -3 | tr '\n' ' ' | cut -c1-200)"
fi

_hdr "K4" "Stage F uses requesting-code-review"
output=$(_claude_ask "Read .claude/commands/spcrg-loop.md Stage F. Before writing the Quantified Review, which superpowers skill is used for self-review? Just the skill name.")
if echo "$output" | grep -qE "requesting-code-review"; then
  _pass "K4 Stage F uses requesting-code-review"
else
  _fail "K4" "output: $(echo "$output" | head -3 | tr '\n' ' ' | cut -c1-200)"
fi

_hdr "K5" "Stage H uses verification-before-completion"
output=$(_claude_ask "Read .claude/commands/spcrg-loop.md Stage H. Before outputting the completion promise, which superpowers skill does the final verification? Just the skill name.")
# Accept with or without the superpowers: namespace prefix
if echo "$output" | grep -qE "verification-before-completion"; then
  _pass "K5 Stage H uses verification-before-completion"
else
  _fail "K5" "output: $(echo "$output" | head -3 | tr '\n' ' ' | cut -c1-200)"
fi

# ============================================================================
# O: Output / Side Effects
# ============================================================================

_hdr "O1" "max-iterations = 10 (from config)"
output=$(_claude_ask "Read .claude/commands/spcrg-loop.md and .ai-workflow-kit/config.json. What --max-iterations value does the loop pass to the ralph-loop command? Just the number.")
if echo "$output" | grep -qE "(^|[^0-9])10([^0-9]|$)"; then
  _pass "O1 max-iterations = 10"
else
  _fail "O1" "output: $(echo "$output" | head -3 | tr '\n' ' ' | cut -c1-200)"
fi

_hdr "O2" "completion-promise = ARCHIVE_READY"
output=$(_claude_ask "Read .claude/commands/spcrg-loop.md. What --completion-promise string does the command pass to ralph-loop? Just the string.")
if echo "$output" | grep -qE "ARCHIVE_READY"; then
  _pass "O2 completion-promise = ARCHIVE_READY"
else
  _fail "O2" "output: $(echo "$output" | head -3 | tr '\n' ' ' | cut -c1-200)"
fi

_hdr "O3" "PPV has 14 required fields"
output=$(_claude_ask "Read .claude/commands/spcrg-loop.md Stage D. How many required fields does the CRG Post-Phase Verification section specify per V5 schema? Just the number.")
if echo "$output" | grep -qE "(^|[^0-9])14([^0-9]|$)"; then
  _pass "O3 PPV schema has 14 fields"
else
  _fail "O3" "output: $(echo "$output" | head -3 | tr '\n' ' ' | cut -c1-200)"
fi

# ============================================================================
# E: Error Recovery
# ============================================================================

_hdr "E1" "Invalid change-id detected"
output=$(_claude_ask "Read .claude/commands/spcrg-loop.md. If the user passed change-id 'nonexistent-change-xyz' and the directory openspec/changes/nonexistent-change-xyz does not exist, what does the command do per its gate logic? One sentence.")
if echo "$output" | grep -qiE "(does not exist|not found|missing|run.*start|stop|no.*change|error|fail)"; then
  _pass "E1 Invalid change-id reported clearly"
else
  _fail "E1" "output: $(echo "$output" | head -3 | tr '\n' ' ' | cut -c1-200)"
fi

_hdr "E2" "Empty arg triggers detect-change-id.sh"
output=$(_claude_ask "Read .claude/commands/spcrg-loop.md 'Resolve change-id if missing' section. If the user invoked the command with no argument, what is the FIRST script path the command tells you to run? Just the path.")
if echo "$output" | grep -qE "scripts/detect-change-id\.sh"; then
  _pass "E2 Empty arg triggers detect-change-id.sh"
else
  _fail "E2" "output: $(echo "$output" | head -3 | tr '\n' ' ' | cut -c1-200)"
fi

_hdr "E3" "Unresolvable → NEEDS_HUMAN_DECISION"
output=$(_claude_ask "Read .claude/commands/spcrg-loop.md 'Inviolable Rules' and Stage D. When a problem cannot be self-fixed, what verdict enum value should be recorded to allow the loop to continue on other phases? Just the enum value.")
if echo "$output" | grep -qE "NEEDS_HUMAN_DECISION"; then
  _pass "E3 Unresolvable → NEEDS_HUMAN_DECISION"
else
  _fail "E3" "output: $(echo "$output" | head -3 | tr '\n' ' ' | cut -c1-200)"
fi

# Summary
total=$((pass + fail))
echo ""
echo "========================================"
echo "  Real Integration Results"
echo "========================================"
echo "  Total: $total | Pass: $pass | Fail: $fail"
echo ""

if [ "$fail" -gt 0 ]; then
  echo "Failed tests:"
  for t in "${failed_tests[@]}"; do
    echo "  - $t"
  done
  exit 1
fi
echo "All real integration tests passed."
