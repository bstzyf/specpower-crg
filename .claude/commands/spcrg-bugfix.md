# Spcrg Bugfix Workflow

Bug:

$ARGUMENTS

Use the lightweight bugfix workflow unless behavior/spec changes are discovered.

## Gate policy

A plain bugfix does **not** create an OpenSpec change, so the OpenSpec gate scripts are **not** run here.

However, as soon as the bug analysis reveals that expected behavior, public API, data model, or spec must change:

1. Stop bugfix workflow.
2. Run `/spcrg-start fix-{bug-name}` to get full V5 treatment (Discovery + brainstorming + gates).
3. Then follow the complete feature flow:
   - `/spcrg-plan fix-{bug-name}`
   - `/spcrg-dev fix-{bug-name}`
   - `/spcrg-review fix-{bug-name}`
   - `/spcrg-archive fix-{bug-name}`
4. All feature-style gate scripts apply from that point.

## Debugging

Use:

superpowers:systematic-debugging

## CRG required for diagnosis

- get_minimal_context_tool
- semantic_search_nodes_tool
- query_graph_tool callers/callees/imports/tests_for
- get_impact_radius_tool

If root cause is unclear, also use:

- traverse_graph_tool
- get_affected_flows_tool
- get_review_context_tool

> Tool names may appear with or without the `_tool` suffix in Claude Code. Use the actual tool names exposed by the CRG MCP server.

## Then

1. Write regression test.
2. Use superpowers:test-driven-development.
3. Fix minimally.
4. Run CRG after fix:
   - detect_changes_tool
   - get_impact_radius_tool
   - query_graph_tool pattern="tests_for"

If expected behavior changes, stop and upgrade to:

/spcrg-start fix-{bug-name}

## V5 Rule: Read Before Decide

Before writing a diagnosis or decision, read the actual source files for
the relevant CRG hits. Use CRG to locate; use source reading to decide.
Do not write raw CRG output as evidence. Write decision evidence.
