# Spcrd Development

Change ID:

$ARGUMENTS

Use superpowers:subagent-driven-development.

## Strict rules

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

5. Update tasks.md after each task/phase.

6. Stop immediately if:

- unexpected blast radius appears
- spec mismatch appears
- CRG unavailable
- test strategy missing
- subagent needs to exceed scope
