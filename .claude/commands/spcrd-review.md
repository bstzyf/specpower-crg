# Spcrd Review

Change ID:

$ARGUMENTS

## Resolve change-id if missing

If `$ARGUMENTS` is empty:

1. Run `scripts/detect-change-id.sh`.
2. If exactly one active change exists, report it and ask the user to confirm before using it.
3. If multiple active changes exist, list them and ask the user to pick one.
4. If none exist, tell the user to run `/spcrd-start <description>` first, then stop.

Do not proceed until a concrete change-id is chosen.

## Gate: before review

Before final review, run:

```
scripts/check-openspec-gate.sh $ARGUMENTS
scripts/check-crg-evidence.sh $ARGUMENTS
```

If either command fails:

1. Do not perform final review yet.
2. Report missing artifacts/evidence.
3. Ask whether to repair evidence or return to the previous phase.
4. Continue only after both scripts pass.

## Review phases

Run final review for this OpenSpec change.

### Phase 1: OpenSpec Compliance Review

Check:

- proposal.md
- design.md
- specs/**
- tasks.md
- GIVEN/WHEN/THEN scenarios
- scope / out of scope
- success criteria

### Phase 2: CRG Final Impact Review

Required CRG tools:

- detect_changes_tool
- get_review_context_tool
- get_impact_radius_tool
- get_affected_flows_tool
- query_graph_tool pattern="tests_for"
- get_knowledge_gaps_tool

If architecture-sensitive, also use:

- get_surprising_connections_tool
- get_hub_nodes_tool
- get_bridge_nodes_tool
- get_suggested_questions_tool

> Tool names may appear with or without the `_tool` suffix in Claude Code. Use the actual tool names exposed by the CRG MCP server and record the exact names used inside CRG Evidence.

### Phase 3: Superpowers Review

Use:

superpowers:requesting-code-review

Check:

- TDD compliance
- minimal implementation
- YAGNI
- DRY
- complexity
- unverified claims
- test evidence

## Output

- blocking issues
- non-blocking issues
- missing tests
- CRG risk summary
- archive readiness recommendation

Do not archive.
