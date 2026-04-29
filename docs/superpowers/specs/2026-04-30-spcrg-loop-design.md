# Design Spec: /spcrg-loop — Ralph-Driven Iterative Development

## Summary

New command `/spcrg-loop <change-id>` that leverages the Ralph Loop plugin to automate the development-test-verify cycle after planning is complete. It replaces the manual `/spcrg-plan` → `/spcrg-dev` → `/spcrg-review` middle steps with a single self-driving loop that iterates until all planned work is implemented, tested, verified, and reviewed to V5 standards.

## Position in Workflow

```
/spcrg-start → /spcrg-plan → /spcrg-loop <change-id> → /spcrg-archive
```

- **Prerequisite:** `/spcrg-plan` completed — `tasks.md` contains `## CRG Precision Plan` with Function-Level Change Map and Phase Plan.
- **Output:** All tasks `[x]`, Post-Phase Verifications per phase, CRG Quantified Review with `archive_ready` verdict.
- **Coexistence:** `/spcrg-dev` + `/spcrg-review` remain as the "manual" path. `/spcrg-loop` is the "automatic" alternative. Users choose based on preference and change complexity.

## Ralph Loop Integration

The command invokes the installed Ralph Loop plugin:

```
/ralph-loop "<navigator-prompt>" --max-iterations 10 --completion-promise "ARCHIVE_READY"
```

Ralph Loop mechanism:
- Same prompt fed to Claude each iteration via stop hook
- Claude sees its own previous work in files/git each round
- Loop terminates when `<promise>ARCHIVE_READY</promise>` is output, or after 10 iterations

## Command File Structure

File: `.claude/commands/spcrg-loop.md`

### Sections:

1. **Resolve change-id** — Same pattern as other commands (detect-change-id.sh fallback)
2. **Gate: before loop** — `check-openspec-gate.sh` + `check-crg-evidence.sh`; on failure, do not start loop
3. **Construct Navigator Prompt** — Read change-id, build the fixed loop prompt with the change-id baked in
4. **Start Ralph Loop** — Invoke `/ralph-loop` with the navigator prompt
5. **Post-loop validation** — Run `check-v5-review.sh` to confirm evidence integrity
6. **State write** — Update `.ai-workflow-kit/state/<change-id>.json`
7. **Report** — Output summary (completed tasks, skipped tasks, archive_ready status)

## Navigator Prompt Design

The prompt follows "rules are fixed, files are state" — Claude reads filesystem each iteration to determine current progress.

### Decision Tree (8 stages, evaluated top-to-bottom each iteration)

#### Stage A: Implement Uncompleted Tasks

- Read `tasks.md`, find first phase with `- [ ]` items
- For each uncompleted task:
  - Use `superpowers:test-driven-development` (RED → GREEN → REFACTOR)
  - Use `superpowers:subagent-driven-development` for independent tasks in parallel
- Mark completed tasks `- [x]`
- If all tasks already `[x]` → proceed to Stage B

#### Stage B: Verify Tests Pass

- Run current phase's `verification_command` (from Phase Plan)
- If failures exist:
  - Use `superpowers:systematic-debugging` to diagnose and fix
  - Re-run verification
- If all pass → proceed to Stage C

#### Stage C: Ensure Coverage and E2E

- Check `changed_symbol_test_coverage` ≥ 80%
- Check affected_flows have E2E coverage
- If coverage insufficient:
  - Add unit tests for uncovered symbols via TDD
- If E2E missing:
  - Design real-scenario E2E cases (simulate real environment, no mocks on core paths)
  - Implement and run E2E tests
- When targets met → proceed to Stage D

#### Stage D: Write Post-Phase Verification

- Check if `### CRG Post-Phase Verification: Phase N` exists in tasks.md
- If not written:
  - Run CRG tools: detect_changes, get_impact_radius, query_graph tests_for, get_affected_flows, get_knowledge_gaps
  - Compute scope_drift_percent, changed_symbol_test_coverage
  - Write V5 schema (14 required fields)
  - Apply verdict rules:
    - scope_drift > threshold with no explanation → BLOCKING
    - coverage < threshold → BLOCKING
    - critical knowledge_gaps → BLOCKING
    - otherwise → PASS
- If already written:
  - verdict = PASS → proceed to Stage E
  - verdict = BLOCKING → return to Stage B/C to fix, then rewrite Verification
  - verdict = NEEDS_HUMAN_DECISION → mark reason, skip phase, proceed to Stage E

#### Stage E: Check All Phases Complete

- Read Phase Plan, verify each phase has a PASS Post-Phase Verification
- If phases remain → return to Stage A for next phase
- If all complete → proceed to Stage F

#### Stage F: Code Review + CRG Quantified Review

- Use `superpowers:requesting-code-review`:
  - TDD compliance, minimal implementation, DRY, YAGNI, focused functions
  - Issues found → fix and return to Stage B for re-verification
- If code review passes:
  - Aggregate all Post-Phase Verification data
  - Compute aggregate metrics (scope_drift, coverage, affected_flows, knowledge_gaps)
  - Write `## CRG Quantified Review` into design.md (V5 schema)
  - Determine `archive_ready: yes/no`

#### Stage G: Self-Check

- Run `scripts/check-v5-review.sh <change-id>`
- If fails → fix numeric inconsistencies/missing fields, re-run
- If passes → proceed to Stage H

#### Stage H: Completion

- Use `superpowers:verification-before-completion`:
  - Full test suite passes
  - lint/typecheck/build pass
  - All tasks `[x]`
  - archive_ready = yes confirmed
- Output `<promise>ARCHIVE_READY</promise>`
- If archive_ready = no with BLOCKING → return to corresponding stage
- If archive_ready = no with only NEEDS_HUMAN_DECISION → output promise anyway, report human-pending items in final summary

### Inviolable Rules (embedded in prompt)

1. Do not expand scope beyond tasks listed in tasks.md
2. Do not modify files outside expected_files (except E2E/config when justified)
3. E2E must simulate real environments; no mocks on core paths
4. Every verdict must be numerically consistent (drift > 20% cannot be PASS)
5. Unresolvable issues: mark NEEDS_HUMAN_DECISION, skip, continue other work
6. Never fabricate test results or CRG evidence

## Gate System

| Timing | Check |
|---|---|
| Before loop starts | `check-openspec-gate.sh` + `check-crg-evidence.sh` |
| Per phase within loop | Post-Phase Verification (auto-written to tasks.md) |
| Final step within loop | `check-v5-review.sh` self-check |
| After loop ends | Command re-runs `check-v5-review.sh` as safety net |

## State Management

On loop start and completion, update `.ai-workflow-kit/state/<change-id>.json`:

```json
{
  "phases": {
    "loop": {
      "status": "completed",
      "completedAt": "<ISO 8601 UTC>",
      "mode": "ralph-loop",
      "iterations": "<actual iteration count>",
      "maxIterations": 10,
      "archive_ready": true,
      "skipped_tasks": [],
      "human_decisions_required": []
    }
  }
}
```

## Configuration

Add to `.ai-workflow-kit/config.json`:

```json
{
  "loop": {
    "maxIterations": 10,
    "completionPromise": "ARCHIVE_READY"
  }
}
```

Users can override per-invocation: `/spcrg-loop <change-id> --max-iterations 20`

## Superpowers Skills Used Within Loop

| Skill | Stage | Purpose |
|---|---|---|
| `superpowers:test-driven-development` | A, C | RED → GREEN → REFACTOR for each task |
| `superpowers:subagent-driven-development` | A | Parallel execution of independent tasks |
| `superpowers:systematic-debugging` | B | Diagnose and fix test failures |
| `superpowers:verification-before-completion` | H | Final confirmation before claiming done |
| `superpowers:requesting-code-review` | F | Self-review for quality issues |

## Expected Iteration Counts

| Change Complexity | Estimated Iterations | Typical Flow |
|---|---|---|
| Simple (1 phase, 2-3 tasks) | 3-5 | implement → test → evidence → review → done |
| Medium (2 phases, 5-6 tasks) | 6-8 | implement P1 → fix → evidence → implement P2 → fix → evidence → review → done |
| Complex (3+ phases, 10+ tasks) | 8-10 | multiple implement/fix/evidence cycles → review → self-check → done |

## Failure Modes

| Scenario | Loop Behavior |
|---|---|
| Test failure (fixable) | systematic-debugging → fix → re-verify (stays in loop) |
| Coverage insufficient | Add tests → re-check (stays in loop) |
| Scope drift > threshold | Attempt to reduce drift; if not possible, mark BLOCKING and skip |
| Needs spec/design change | Mark NEEDS_HUMAN_DECISION, skip, continue other phases |
| CRG tools unavailable | Cannot write evidence → mark issue, report at end |
| 10 iterations exhausted | Loop force-stops; user inspects partial progress |

## Success Criteria

- All tasks in tasks.md marked `[x]`
- All Post-Phase Verifications have verdict = PASS
- CRG Quantified Review exists with archive_ready = yes
- `check-v5-review.sh` passes
- Full test suite (unit + integration + E2E) passes
- Coverage ≥ 80% for changed symbols
