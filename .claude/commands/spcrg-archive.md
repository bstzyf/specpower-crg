# Spcrg Archive (V5)

Change ID:

$ARGUMENTS

## Resolve change-id if missing

If `$ARGUMENTS` is empty:

1. Run `scripts/detect-change-id.sh`.
2. If exactly one active change exists, report it and ask the user to confirm before using it.
3. If multiple active changes exist, list them and ask the user to pick one.
4. If none exist, tell the user there is nothing to archive and stop.

Do not proceed until a concrete change-id is chosen.

## Gate: before archive

Before verification or archive, run:

```
AIWK_OPENSPEC_MODE=archive scripts/check-openspec-gate.sh $ARGUMENTS
scripts/check-crg-evidence.sh $ARGUMENTS
scripts/check-v5-review.sh $ARGUMENTS
```

If any command fails:

1. Do not run `/opsx:verify`.
2. Do not run `/opsx:archive`.
3. Report missing artifacts or evidence sections.
4. For `check-v5-review.sh` failures: the `## CRG Quantified Review` section must exist and pass before archive can proceed. Run `/spcrg-review $ARGUMENTS` first.
5. Continue only after all three scripts pass.

## V5 Archive Readiness Check

After all gate scripts pass, read `## CRG Quantified Review` from
`openspec/changes/$ARGUMENTS/design.md` (or `review.md`).

Assert:
```
Final CRG Verdict.archive_ready: yes
```

If `archive_ready` is `no` or the section is missing:

1. **STOP**.
2. Report: "Archive blocked: archive_ready is not 'yes'. Run /spcrg-review to produce or update the Quantified Review, address all blockers, and re-run /spcrg-archive."
3. Do not proceed with project checks, `/opsx:verify`, or `/opsx:archive`.

Only continue when `archive_ready: yes` is confirmed.

## Run project checks

After gate scripts pass and `archive_ready: yes` is confirmed:

1. Run `superpowers:verification-before-completion`.
2. Then run all project quality checks:

- unit tests
- integration tests
- E2E if applicable
- lint
- typecheck
- build

All checks must pass before proceeding.

## CRG Archive Gate

Before `/opsx:verify`, run:

- detect_changes_tool
- get_review_context_tool
- get_impact_radius_tool
- get_affected_flows_tool
- get_knowledge_gaps_tool

If user flow is affected, also use:

- list_flows_tool
- get_flow_tool

> Tool names may appear with or without the `_tool` suffix in Claude Code. Use the actual tool names exposed by the CRG MCP server and record the exact names used inside CRG Evidence.

## Pre-archive gate re-run

Re-run all three gate scripts one final time right before `/opsx:verify`:

```
AIWK_OPENSPEC_MODE=archive scripts/check-openspec-gate.sh $ARGUMENTS
scripts/check-crg-evidence.sh $ARGUMENTS
scripts/check-v5-review.sh $ARGUMENTS
```

All must pass. If any fail, stop and repair before proceeding.

## Verify and archive

1. Run `/opsx:verify $ARGUMENTS`.
2. Only if verification passes, run `/opsx:archive $ARGUMENTS`.

## State write

After successful archive, update `.ai-workflow-kit/state/$ARGUMENTS.json`:

```json
{
  "phases": {
    "archive": {
      "status": "completed",
      "completedAt": "<ISO 8601 UTC>"
    }
  }
}
```

## Report

- updated specs
- archive location
- test evidence
- CRG evidence
- merge/PR readiness
