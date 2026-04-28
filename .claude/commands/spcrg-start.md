# Spcrg Start: OpenSpec OPSX + Superpowers + CRG

User input:

$ARGUMENTS

Start a new feature or significant change using the mandatory project workflow.

## Steps

1. Run OpenSpec propose:

/opsx:propose $ARGUMENTS

2. Do not implement code.

3. After OpenSpec artifacts are created, identify the change-id and verify these files exist:

- openspec/changes/{change-id}/proposal.md
- openspec/changes/{change-id}/design.md
- openspec/changes/{change-id}/specs/**
- openspec/changes/{change-id}/tasks.md

4. Run CRG Context Pass.

Required CRG tools:

- build_or_update_graph_tool if graph is missing or stale
- list_graph_stats_tool
- get_minimal_context_tool
- get_architecture_overview_tool
- list_communities_tool
- get_community_tool for relevant communities
- semantic_search_nodes_tool
- query_graph_tool for callers/callees/imports/tests_for
- get_impact_radius_tool if target files/modules are known

If the change is cross-module, architecture-sensitive, permission-related, data-model-related, or core-flow-related, also use:

- get_hub_nodes_tool
- get_bridge_nodes_tool
- get_knowledge_gaps_tool
- get_surprising_connections_tool
- get_suggested_questions_tool

> Tool names may appear with or without the `_tool` suffix in Claude Code. Use the actual tool names exposed by the CRG MCP server and record the exact names used inside CRG Evidence.

5. Write CRG Evidence into:

- proposal.md → CRG Architecture Context
- design.md → CRG Impact Analysis

6. Use superpowers:brainstorming.

Inputs:

- proposal.md
- design.md
- specs/**
- tasks.md
- CRG Evidence

Brainstorm must clarify:

- requirement boundaries
- technical approach
- scope / out of scope
- measurable success criteria
- feature flag / migration / compatibility needs
- testing and E2E strategy
- CRG-discovered risks
- whether this should be split into multiple OpenSpec changes

7. Update:

- proposal.md
- design.md
- specs/**
- tasks.md

8. If brainstorming changes target modules, API boundaries, data models, permissions, testing strategy, E2E scope, or task split, run CRG Recheck using:

- semantic_search_nodes_tool
- query_graph_tool callers/callees/imports/tests_for
- get_impact_radius_tool
- list_communities_tool / get_community_tool when target modules changed
- get_hub_nodes_tool / get_bridge_nodes_tool / get_surprising_connections_tool / get_knowledge_gaps_tool for architecture or cross-module changes

## Gate: before requesting approval

Only after propose + CRG Context Pass + brainstorming + writing all artifacts + CRG Recheck are complete, run:

```
scripts/check-openspec-gate.sh <change-id>
scripts/check-crg-evidence.sh <change-id>
```

If either command fails:

1. Do not tell the user you are "waiting for approval".
2. Do not implement code.
3. Identify what is missing (OpenSpec artifact section or CRG Evidence).
4. Repair the missing content using the existing proposal / design / CRG tool outputs — do not expand scope.
5. Re-run both scripts.
6. Only when both scripts pass, continue.

After both scripts pass:

9. Stop and ask for human approval.

Do not implement code.

Stop if CRG is unavailable, stale, or fails.
