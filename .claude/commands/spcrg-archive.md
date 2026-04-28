# Spcrg Archive

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
scripts/check-openspec-gate.sh $ARGUMENTS
scripts/check-crg-evidence.sh $ARGUMENTS
```

If either command fails:

1. Do not run `/opsx:verify`.
2. Do not run `/opsx:archive`.
3. Report missing artifacts/evidence.
4. Continue only after both scripts pass.

After both scripts pass:

1. Run `superpowers:verification-before-completion`.
2. Run CRG Archive Gate (see below).
3. Re-run both gate scripts one more time right before `/opsx:verify`.
4. Run `/opsx:verify $ARGUMENTS`.
5. Only if verification passes, run `/opsx:archive $ARGUMENTS`.

## Run project checks

- unit tests
- integration tests
- E2E if applicable
- lint
- typecheck
- build

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

## Report

- updated specs
- archive location
- test evidence
- CRG evidence
- merge/PR readiness
