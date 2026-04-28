# Spcrd CRG Evidence Audit

Change ID:

$ARGUMENTS

## Resolve change-id if missing

If `$ARGUMENTS` is empty:

1. Run `scripts/detect-change-id.sh`.
2. If exactly one active change exists, report it and ask the user to confirm before using it.
3. If multiple active changes exist, list them and ask the user to pick one.
4. If none exist, tell the user there is nothing to audit and stop.

Do not proceed until a concrete change-id is chosen.

## Gate: at start of audit

Run:

```
scripts/check-openspec-gate.sh $ARGUMENTS
scripts/check-crg-evidence.sh $ARGUMENTS
```

Audit behavior is **report-only**:

1. If either script fails, include the failure in the audit report.
2. Do not auto-repair evidence unless the user explicitly asks.
3. Continue the remainder of the audit even if scripts fail, so the full gap list is produced in one pass.

## Audit scope

Check these files:

- openspec/changes/$ARGUMENTS/proposal.md
- openspec/changes/$ARGUMENTS/design.md
- openspec/changes/$ARGUMENTS/tasks.md
- openspec/changes/$ARGUMENTS/specs/**

### Required evidence

1. proposal.md has CRG Architecture Context.
2. design.md has CRG Impact Analysis.
3. tasks.md has CRG Planning Evidence.
4. Each implementation phase has CRG Pre-Phase Check.
5. Each implementation phase has CRG Post-Phase Check.
6. Final review includes CRG Final Impact Review.
7. Archive/verify includes CRG Archive Gate.

### Required tool names must appear where applicable

Baseline:

- get_minimal_context_tool
- semantic_search_nodes_tool
- query_graph_tool
- get_impact_radius_tool
- detect_changes_tool
- get_review_context_tool
- get_affected_flows_tool
- get_knowledge_gaps_tool

For complex changes also check:

- get_architecture_overview_tool
- list_communities_tool
- get_community_tool
- get_hub_nodes_tool
- get_bridge_nodes_tool
- get_surprising_connections_tool
- get_suggested_questions_tool

> Tool names may appear with or without the `_tool` suffix in Claude Code. Accept either form during audit, but note which form was recorded.

## Report

- missing evidence
- missing tools
- stale evidence
- gate script results
- whether next phase is allowed

If evidence is missing, do not continue to the next phase. Fix evidence first.
