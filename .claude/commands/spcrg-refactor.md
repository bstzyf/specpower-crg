# Spcrg Refactor Workflow

Refactor goal:

$ARGUMENTS

Use CRG + Superpowers refactor workflow.

## CRG refactor assessment

Required CRG tools:

- get_architecture_overview_tool
- list_communities_tool
- get_community_tool
- get_hub_nodes_tool
- get_bridge_nodes_tool
- find_large_functions_tool
- get_knowledge_gaps_tool
- get_surprising_connections_tool
- get_impact_radius_tool
- query_graph_tool callers/callees/tests_for
- refactor_tool

> Tool names may appear with or without the `_tool` suffix in Claude Code. Use the actual tool names exposed by the CRG MCP server.

Use apply_refactor_tool only after:

- refactor_tool preview reviewed
- test strategy clear
- blast radius acceptable
- user approved

## Superpowers

Use superpowers:brainstorming to clarify:

- refactor goal
- behavior preservation
- scope boundary
- risk
- test strategy

If external behavior, public API, or architecture rules change, stop and upgrade to:

/spcrg-start {refactor-change-name}

## V5 Rule: Read Before Decide

Before writing a diagnosis or decision, read the actual source files for
the relevant CRG hits. Use CRG to locate; use source reading to decide.
Do not write raw CRG output as evidence. Write decision evidence.
