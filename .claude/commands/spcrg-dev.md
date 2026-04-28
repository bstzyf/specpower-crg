# Spcrg Development

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
3. Report missing OpenSpec artifacts or missing CRG Evidence.
4. Fix missing evidence only if it can be produced safely from CRG tools.
5. Re-run scripts.
6. Continue only after both scripts pass.

## Development phase

Use `superpowers:subagent-driven-development`.

### Strict rules

1. Only execute tasks from:

openspec/changes/$ARGUMENTS/tasks.md

2. Every task must follow superpowers:test-driven-development:

- write failing test
- confirm red
- implement minimal code
- confirm green
- refactor

3. Before every phase, run CRG Pre-Phase Check.

Required CRG tools before phase:

- query_graph_tool for callers/callees/imports/tests_for
- semantic_search_nodes_tool
- get_impact_radius_tool

If the phase touches a user/business flow, also use:

- list_flows_tool
- get_flow_tool

If the phase touches complex code, also use:

- traverse_graph_tool
- find_large_functions_tool

4. After every phase, run CRG Post-Phase Check.

Required CRG tools after phase:

- detect_changes_tool
- get_impact_radius_tool
- get_affected_flows_tool
- query_graph_tool pattern="tests_for"

If unexpected impact appears, also use:

- get_review_context_tool
- get_surprising_connections_tool
- get_knowledge_gaps_tool

> Tool names may appear with or without the `_tool` suffix in Claude Code. Use the actual tool names exposed by the CRG MCP server and record the exact names used inside CRG Evidence.

5. Update tasks.md after each task/phase.

6. Stop immediately if:

- unexpected blast radius appears
- spec mismatch appears
- CRG unavailable
- test strategy missing
- subagent needs to exceed scope
