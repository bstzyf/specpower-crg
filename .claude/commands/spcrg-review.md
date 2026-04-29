# Spcrg Review (V5)

Change ID:

$ARGUMENTS

## Resolve change-id if missing

If `$ARGUMENTS` is empty:

1. Run `scripts/detect-change-id.sh`.
2. If exactly one active change exists, report it and ask the user to confirm before using it.
3. If multiple active changes exist, list them and ask the user to pick one.
4. If none exist, tell the user to run `/spcrg-start <description>` first, then stop.

Do not proceed until a concrete change-id is chosen.

## Gate: before review

Before review, run:

```
scripts/check-openspec-gate.sh $ARGUMENTS
scripts/check-crg-evidence.sh $ARGUMENTS
```

Note: `check-v5-review.sh` is **NOT** in the entry gate — the `## CRG Quantified Review` section is
this command's **output**, not a precondition. Running `check-v5-review.sh` at entry would always fail.

If either gate script fails:

1. Do not perform final review yet.
2. Report missing artifacts or evidence sections.
3. Ask whether to repair evidence or return to the previous phase.
4. Continue only after both scripts pass.

## Phase 1: OpenSpec Compliance Review

Review the OpenSpec documents for this change:

- `openspec/changes/$ARGUMENTS/proposal.md`
- `openspec/changes/$ARGUMENTS/design.md`
- `openspec/changes/$ARGUMENTS/specs/**`
- `openspec/changes/$ARGUMENTS/tasks.md`

Check:

- GIVEN/WHEN/THEN scenarios are present and unambiguous
- Scope and out-of-scope are clearly stated
- Success criteria are measurable
- All planned tasks are represented

Report any compliance gaps before proceeding to Phase 2.

## Phase 2: CRG Quantified Review

Aggregate all Post-Phase Verifications from `tasks.md` into a single quantified summary.

### Step 1: Collect phase data

For each `### CRG Post-Phase Verification: Phase N` section in `tasks.md`, read:

- `actual_changed_files` list and count
- `expected_changed_files` list and count (from the Precision Plan for that phase)
- `changed_symbol_test_coverage`
- `affected_flows`, `e2e_required`, `e2e_status`
- `knowledge_gaps` (severity: critical or medium)

### Step 2: Compute aggregate metrics

**Scope Drift:**
- `planned_files` = sum of all `expected_changed_files` counts across phases
- `actual_files` = sum of all `actual_changed_files` counts across phases
- `drift_percent` = abs(actual_files - planned_files) / planned_files × 100 (integer)
- Read threshold from `.ai-workflow-kit/config.json` key `thresholds.scopeDriftPercent` (default: 20)

**Changed Function Test Coverage:**
- `changed_symbols` = union of all `changed_symbols` across phases
- `tested_symbols` = union of all `tested_changed_symbols` across phases
- `coverage_percent` = tested_symbols / changed_symbols × 100 (integer)
- Read threshold from config `thresholds.changedSymbolTestCoveragePercent` (default: 80)

**Flow Impact:**
- `affected_flows` = union of all per-phase `affected_flows`
- `flows_with_e2e` = flows where `e2e_status` is `existing-coverage`
- `flows_missing_e2e` = flows where `e2e_required=yes` and `e2e_status=missing`

**Knowledge Gaps:**
- `critical` = all `knowledge_gaps` entries with `severity=critical` across all phases
- `medium` = all `knowledge_gaps` entries with `severity=medium` across all phases

### Step 3: Apply verdict rules per subsection

Each subsection verdict must be numerically consistent:

| Condition | Verdict |
|---|---|
| `drift_percent > threshold` with no explanation | BLOCKING |
| `coverage_percent < threshold` | BLOCKING |
| `flows_missing_e2e` non-empty AND `requireE2EForAffectedFlows=true` | NEEDS_HUMAN_DECISION |
| `critical` knowledge gaps non-empty | BLOCKING |
| otherwise | PASS |

Any verdict that is not PASS **requires** a non-empty `explanation` field.

### Step 4: Determine Final CRG Verdict

- `archive_ready: yes` only if ALL subsection verdicts are PASS
- `archive_ready: no` if any subsection verdict is BLOCKING or NEEDS_HUMAN_DECISION
- `blockers`: list all BLOCKING items
- `human_decisions_required`: list all NEEDS_HUMAN_DECISION items

### Step 5: Write the section

Append `## CRG Quantified Review` to `openspec/changes/$ARGUMENTS/design.md`
(or write to `review.md` if design.md is already very long).

Use this exact schema:

```markdown
## CRG Quantified Review

### Review Metadata
- generated_at: <ISO 8601 UTC>
- generated_by: /spcrg-review
- based_on_phases: [<list of phase numbers>]

### Scope Drift
- planned_files: <N>
- actual_files: <M>
- drift_percent: <0-100>
- verdict: PASS | BLOCKING | NEEDS_HUMAN_DECISION
- explanation: <required if not PASS>

### Changed Function Test Coverage
- changed_symbols: <N>
- tested_symbols: <M>
- coverage_percent: <0-100>
- threshold_percent: <from config>
- verdict: PASS | BLOCKING | NEEDS_HUMAN_DECISION
- explanation: <required if not PASS>

### Flow Impact
- affected_flows: [...]
- flows_with_e2e: [...]
- flows_missing_e2e: [...]
- verdict: PASS | BLOCKING | NEEDS_HUMAN_DECISION
- explanation: <required if not PASS>

### Knowledge Gaps
- critical: [...]
- medium: [...]
- verdict: PASS | BLOCKING | NEEDS_HUMAN_DECISION
- explanation: <required if not PASS>

### Final CRG Verdict
- archive_ready: yes | no
- blockers: [...]
- human_decisions_required: [...]
```

## Phase 3: Superpowers Code Review

Use:

superpowers:requesting-code-review

Check:

- TDD compliance (every changed symbol has a corresponding test)
- Minimal implementation (no speculative features)
- YAGNI (no code that is not yet needed)
- DRY (no copy-pasted logic that should be extracted)
- Complexity (functions should be small and focused)
- Unverified claims (assertions backed by tests, not just prose)
- Test evidence (tests actually run and pass)

## Self-check

After writing `## CRG Quantified Review`, run:

```
scripts/check-v5-review.sh $ARGUMENTS
```

If the script fails:

1. Read the failure messages carefully.
2. Repair the written `## CRG Quantified Review` section (fix numeric inconsistencies, missing fields, etc.).
3. Re-run `scripts/check-v5-review.sh $ARGUMENTS` until it passes.
4. Only then produce the output report below.

Do not report `archive_ready` to the user until `check-v5-review.sh` passes.

## Output

Report:

- **Blocking issues**: items that must be fixed before archive (from Phase 1 compliance and Phase 2 BLOCKING verdicts)
- **Non-blocking issues**: recommended improvements that do not block archive
- **Missing tests**: symbols that lack test coverage
- **CRG risk summary**: scope_drift percent, coverage percent, affected flows, critical knowledge gaps
- **archive_ready verdict**: `yes` or `no` with rationale

Do not archive. Do not run `/opsx:verify`. Do not run `/opsx:archive`.
