# Spcrg Plan: CRG Precision Mapping Protocol

Change ID:

$ARGUMENTS

## Resolve change-id if missing

If `$ARGUMENTS` is empty:

1. Run `scripts/detect-change-id.sh`.
2. If exactly one active change exists, report it and ask the user to confirm before using it.
3. If multiple active changes exist, list them and ask the user to pick one.
4. If none exist, tell the user to run `/spcrg-start <description>` first, then stop.

Do not proceed until a concrete change-id is chosen.

## Gate: before planning

Before writing the plan, run:

```
scripts/check-openspec-gate.sh $ARGUMENTS
scripts/check-crg-evidence.sh $ARGUMENTS
```

If either command fails:

1. Do not run `superpowers:writing-plans`.
2. Report exactly what is missing (section name, field name, row count).
3. If the missing item can be fixed from existing context, fix the OpenSpec artifact or CRG Evidence first.
4. Re-run the failed script.
5. Continue only after both scripts pass.

## CRG Precision Mapping Protocol

Do NOT repeat `/spcrg-start`'s broad discovery unless `design.md#CRG Discovery` is missing or older than 7 days. Inherit and extend, do not re-search from scratch.

### Step 1: Inherit Discovery

Read `design.md#CRG Discovery`. The following are your starting state:

- **Entry Points** — file:function pairs to trace
- **Involved Modules** — modify / add / read-only designations
- **Risk Boundary** — expected_changed_files, expected_changed_symbols, hub_nodes, bridge_nodes

### Step 2: Expand via call graph

For each Entry Point marked `modify` or `add`:

1. Run `query_graph callers/callees` with depth ≤ `config.thresholds.maxCallChainDepth` (default 2).
2. Read the actual source code of every caller and callee flagged as a modify candidate.
3. Record each examined symbol as a row in the Function-Level Change Map table.

### Step 3: Test coverage pass

For each symbol in the Function-Level Change Map:

1. Run `query_graph pattern="tests_for"`.
2. Read the existing test file.
3. Decide: `extend | new file | explicit no-test-justification`.
4. Record in the Test Coverage Plan table.

### Step 4: Phase grouping

Group tasks into phases. Each phase must:

- Touch ≤ 5 files
- Have a runnable `verification_command`
- Complete its own Post-Phase Verification independently

### Step 5: Write CRG Precision Plan to tasks.md FIRST

**CRITICAL:** Before calling superpowers:writing-plans, you MUST write `## CRG Precision Plan` into `openspec/changes/$ARGUMENTS/tasks.md` per the V5 schema below. This is the structured evidence that gate scripts validate. The section must remain at the TOP of tasks.md and must NOT be removed or overwritten by any subsequent step.

### Step 6: Hand off to superpowers:writing-plans

Pass the Precision Mapping output as input to `superpowers:writing-plans`. It produces TDD-structured tasks (red/green/refactor). The superpowers plan output should be APPENDED BELOW the `## CRG Precision Plan` section in tasks.md, or saved separately to `docs/superpowers/plans/`. Either way, the `## CRG Precision Plan` section in tasks.md must be preserved intact.

### Required tasks.md structure

The final tasks.md MUST have this structure (gate scripts validate it):

1. `## CRG Precision Plan` section (structured evidence — validated by check-crg-evidence.sh)
2. Task checklist with `- [ ]` items at file:function granularity (validated by check-openspec-gate.sh archive mode)

Write `## CRG Precision Plan` per this exact V5 schema:

```
## CRG Precision Plan

### Mapping Metadata
- based_on_discovery: <timestamp from Discovery Metadata>
- generated_by: /spcrg-plan
- generated_at: <ISO 8601 UTC>

### Function-Level Change Map
| Task | Target | Current Behavior | Required Change | Tests | Reference Pattern | Risk |
|---|---|---|---|---|---|---|
| <id> | <file:symbol> | <text> | <text> | <test path or "none-with-justification"> | <file:symbol> | low | medium | high |

### Test Coverage Plan
| Changed Symbol | Existing Test | New Test Case | Verification Command |
|---|---|---|---|

### Phase Plan

#### Phase N: <name>
- expected_files: [...]
- expected_symbols: [...]
- required_tests: [...]
- verification_command: `<command>`
- crg_post_phase_checks: [<tool names to run in Post-Phase Verification>]
```

## V5 Task Granularity Rule

Tasks MUST be written at file:function level.

BAD:
```
- [ ] Modify UserService
```

GOOD:
```
- [ ] 1.2 Extend src/services/UserService.ts:searchUsers() to accept email filter
        - Current behavior: only filters by displayName
        - Required change: add optional email predicate; preserve pagination
        - Reference pattern: src/services/UserService.ts:findByName()
        - TDD: write failing test → red → minimal impl → green → refactor
        - Verification: pnpm test tests/services/UserService.test.ts
        - CRG evidence: design.md#CRG Discovery, tasks.md#CRG Precision Plan row 1.2
```

Every task must include:

- task id
- exact `file:function` target
- current behavior description
- required change description
- TDD steps (red → green → refactor)
- verification command
- reference pattern (file:function, or "none")
- related CRG evidence reference

## State write

After the plan is written and execution approval is granted, write `.ai-workflow-kit/state/<change-id>.json` with `phase=plan`:

```json
{
  "phases": {
    "plan": {
      "status": "completed",
      "completedAt": "<ISO 8601 UTC>",
      "sessionId": "<AIWK_SESSION_ID>",
      "treeHash": "<git ls-files --stage | sha256sum | cut -c1-16>",
      "plannedPhases": <integer from Phase Plan>
    }
  }
}
```

Stop after writing the plan and ask for execution approval. Do not implement code.
