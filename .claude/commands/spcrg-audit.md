# Spcrg CRG Evidence Audit (V5)

Change ID:

$ARGUMENTS

## Resolve change-id if missing

If `$ARGUMENTS` is empty:

1. Run `scripts/detect-change-id.sh`.
2. If exactly one active change exists, report it and ask the user to confirm before using it.
3. If multiple active changes exist, list them and ask the user to pick one.
4. If none exist, tell the user there is nothing to audit and stop.

Do not proceed until a concrete change-id is chosen.

## Run structured checks (report-only)

Run all three gate scripts and capture their output. Audit is **report-only**:
do NOT auto-repair evidence unless the user explicitly asks.

```
scripts/check-openspec-gate.sh $ARGUMENTS
scripts/check-crg-evidence.sh $ARGUMENTS
scripts/check-v5-review.sh $ARGUMENTS
```

Notes on `check-v5-review.sh`:
- If the `## CRG Quantified Review` section has not yet been produced (review phase not run),
  the script will fail. Record this as "Review phase not yet run" in the report — it is expected
  before `/spcrg-review` has been executed.
- Do not stop the audit because `check-v5-review.sh` fails; continue and include the result in
  the report table.

Capture all CHECK lines and SUMMARY lines from each script. These are the structured evidence
validation results.

## Manual structural audit (semantic checks)

Perform semantic checks that the scripts cannot do automatically. Read the actual files under
`openspec/changes/$ARGUMENTS/`:

### Existing Patterns references

In `design.md` under `## CRG Discovery`, find the `### Existing Patterns` subsection.
For each entry of the form `<pattern name> — reference <file:function>`, verify that
`<file>` actually exists in the project. Record any references to non-existent files as
structural issues.

### Precision Plan Reference Pattern column

In `tasks.md` under `## CRG Precision Plan`, find the `### Function-Level Change Map` table.
The `Reference Pattern` column lists `<file:symbol>` values. For each entry, verify that
`<file>` exists in the project. Record missing files.

### Post-Phase Verifications completeness

Read `.ai-workflow-kit/state/$ARGUMENTS.json` (if it exists) to determine which phases are
listed as completed. For each completed phase N, verify that a
`### CRG Post-Phase Verification: Phase N` section exists in `tasks.md`.
Record any phases that are marked completed but lack a Post-Phase Verification section.

### Code Reading Summary coverage

In the Code Reading Summary table within `## CRG Discovery`, check that:
- No `File`, `Symbol`, `Why Read`, `Finding`, or `Decision` column is empty in any row
- The `Decision` values use the allowed vocabulary: `modify | add | reuse | reuse-pattern | avoid | read-only`

This is the structured evidence that distinguishes V5 from V1: the Code Reading Summary
documents what was actually read and the decisions derived from reading — not raw tool output.

## Report

Produce a table showing the validation status of each evidence section:

| Section | Exists | Schema Valid | Notes |
|---|---|---|---|
| ## CRG Discovery | ✓/✗ | ✓/✗/— | e.g. "2 rows in Code Reading Summary" |
| ## CRG Precision Plan | ✓/✗ | ✓/✗/— | e.g. "Phase 2 missing verification_command" |
| Post-Phase Verification Phase 1 | ✓/✗ | ✓/✗/— | e.g. "verdict=PASS" |
| Post-Phase Verification Phase 2 | ✓/✗ | ✓/✗/— | e.g. "Not generated" |
| ## CRG Quantified Review | ✓/✗ | ✓/✗/— | e.g. "Review phase not run" |

Follow the table with:

1. **Blocker list**: items that will block the next phase (gate failures, missing required sections,
   inconsistent verdicts, Precision Plan targets referencing non-existent files).
2. **Non-blocking issues**: items that are warnings but do not stop forward progress.
3. **Next-phase readiness**:
   - If `/spcrg-review` has not been run: state that `## CRG Quantified Review` and
     `archive_ready` are not yet available.
   - If archive_ready is visible: state whether it is `yes` or `no`.

If blockers exist, the audit report makes them visible. The audit does not auto-fix evidence.
The user must decide whether to repair or accept the risk.
