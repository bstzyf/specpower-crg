# Spcrg Development: Delta Check Protocol + Post-Phase Verification

Change ID:

$ARGUMENTS

## Resolve change-id if missing

If `$ARGUMENTS` is empty:

1. Run `scripts/detect-change-id.sh`.
2. If exactly one active change exists, report it and ask the user to confirm before using it.
3. If multiple active changes exist, list them and ask the user to pick one.
4. If none exist, tell the user to run `/spcrg-start <description>` first, then stop.

Do not proceed until a concrete change-id is chosen.

## Gate: before development

Before starting implementation, run:

```
scripts/check-openspec-gate.sh $ARGUMENTS
scripts/check-crg-evidence.sh $ARGUMENTS
```

If either command fails:

1. Do not run `superpowers:subagent-driven-development`.
2. Do not edit code.
3. Report missing OpenSpec artifacts or missing CRG Evidence sections.
4. Fix missing evidence only if it can be produced safely from existing CRG tool outputs or existing OpenSpec context.
5. Re-run both scripts.
6. Continue only after both pass.

## Delta Check Protocol

Before each phase, compute context continuity and decide whether to run CRG pre-checks:

### Session and tree hash setup

```bash
# Session ID: reuse if already exported in this session, otherwise generate
session_id="${AIWK_SESSION_ID:-$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$RANDOM$RANDOM$RANDOM")}"
export AIWK_SESSION_ID="$session_id"

# Tree hash: fingerprint of committed + staged files
tree_hash=$(git ls-files --stage 2>/dev/null | sha256sum | cut -c1-16)
[ -z "$tree_hash" ] && tree_hash="no-git"
```

### Continuity decision table

Read `.ai-workflow-kit/state/<change-id>.json`. Get `last = state.phases.dev.phaseHistory[-1]`.

| Condition | Classification | Action |
|---|---|---|
| state missing OR phaseHistory empty | resumed | run `detect_changes` |
| `last.sessionId` != `$AIWK_SESSION_ID` | resumed | run `detect_changes` |
| `last.treeHash` != `current_tree_hash` | tree changed | run `detect_changes` |
| all match | continuous | skip broad CRG pre-check; read target files directly |

### On "resumed" or "tree changed"

1. Run `detect_changes`.
2. If changed files intersect the current phase's `expected_files`, run `get_impact_radius`.
3. Read the changed code.
4. Decide whether the Precision Plan must be updated before continuing.
5. If plan update is required: STOP and ask user to re-run `/spcrg-plan $ARGUMENTS`.

### On "continuous"

Read the current task's target files directly from `tasks.md#CRG Precision Plan`. Start TDD immediately.

## Execute phase via TDD

Use `superpowers:subagent-driven-development` for parallel or sequential task execution, combined with `superpowers:test-driven-development` for each task.

Only execute tasks from:

```
openspec/changes/$ARGUMENTS/tasks.md
```

For each task:

1. **Red** — write a failing test that captures the required change.
2. **Green** — implement the minimal code to make the test pass.
3. **Refactor** — improve without breaking; confirm tests still pass.
4. Update the task's status in `tasks.md`.

Do not expand scope beyond the tasks in `tasks.md`. Do not edit files not listed in the phase's `expected_files`.

## CRG Post-Phase Verification

After each phase N completes, run the following CRG tools:

1. `detect_changes` — list all files changed in this phase
2. `get_impact_radius` — downstream impact of changed files
3. `query_graph pattern="tests_for"` for each changed symbol
4. `get_affected_flows` — flows touched by the changes
5. `get_knowledge_gaps` — if `config.gates.requireReviewBeforeArchive` is true

Compute:

- `actual_changed_files` from `detect_changes` output
- `scope_drift_percent` = `(|actual - expected| / expected) * 100`
- `changed_symbol_test_coverage` = `(tested_changed_symbols / changed_symbols) * 100`
- `affected_flows` from `get_affected_flows`
- `knowledge_gaps` from `get_knowledge_gaps`

Write `### CRG Post-Phase Verification: Phase N` into `tasks.md` per the V5 schema:

```
### CRG Post-Phase Verification: Phase <N>

- generated_at: <ISO 8601 UTC>
- actual_changed_files: [...]
- expected_changed_files: [...]
- scope_drift_percent: <0-100 integer>
- changed_symbols: [...]
- tested_changed_symbols: [...]
- changed_symbol_test_coverage: <0-100 integer>
- affected_flows: [...]
- e2e_required: yes | no
- e2e_status: existing-coverage | planned | missing
- knowledge_gaps: [{severity: critical|medium, description: ...}, ...]
- surprising_connections: [...]
- verdict: PASS | BLOCKING | NEEDS_HUMAN_DECISION
- action_taken: <text>
```

### Verdict rules

| Condition | Verdict |
|---|---|
| `scope_drift_percent` > `config.thresholds.scopeDriftPercent` AND no explanation | BLOCKING |
| `changed_symbol_test_coverage` < `config.thresholds.changedSymbolTestCoveragePercent` | BLOCKING |
| any `knowledge_gaps` entry with `severity: critical` | BLOCKING |
| `affected_flows` need E2E but E2E is missing and team cannot provide | NEEDS_HUMAN_DECISION |
| otherwise | PASS |

### Numeric consistency enforcement

These contradictions are always invalid:

- `scope_drift_percent` > threshold AND `verdict: PASS`
- `changed_symbol_test_coverage` < threshold AND `verdict: PASS`
- `knowledge_gaps` contains `critical` AND `verdict: PASS`

### State update

After writing Post-Phase Verification, update `.ai-workflow-kit/state/<change-id>.json`:

```json
{
  "phases": {
    "dev": {
      "status": "in_progress",
      "currentPhase": <N>,
      "phaseHistory": [
        {
          "phaseNumber": <N>,
          "completedAt": "<ISO 8601 UTC>",
          "sessionId": "<AIWK_SESSION_ID>",
          "treeHash": "<current_tree_hash>",
          "verdict": "PASS | BLOCKING | NEEDS_HUMAN_DECISION",
          "scopeDriftPercent": <integer>,
          "changedSymbolCoveragePercent": <integer>
        }
      ]
    }
  }
}
```

## STOP conditions

- `verdict == BLOCKING` → STOP immediately. Report the specific failing metric. Do not continue to the next phase.
- `verdict == NEEDS_HUMAN_DECISION` → STOP. Explain what human input is needed. Wait for user response before continuing.
- Plan-external files changed without explanation → STOP. Report which files were not in `expected_files`. Do not continue.
- CRG unavailable → STOP. Do not fabricate Post-Phase Verification evidence.
- Unexpected blast radius appears → STOP. Report the unexpected impact before proceeding.
