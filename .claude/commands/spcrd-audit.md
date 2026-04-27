# Spcrd CRG Evidence Audit

Change ID:

$ARGUMENTS

Audit CRG checkpoint completeness.

Check these files:

- openspec/changes/$ARGUMENTS/proposal.md
- openspec/changes/$ARGUMENTS/design.md
- openspec/changes/$ARGUMENTS/tasks.md
- openspec/changes/$ARGUMENTS/specs/**

## Required evidence

1. proposal.md has CRG Architecture Context.
2. design.md has CRG Impact Analysis.
3. tasks.md has CRG Planning Evidence.
4. Each implementation phase has CRG Pre-Phase Check.
5. Each implementation phase has CRG Post-Phase Check.
6. Final review includes CRG Final Impact Review.
7. Archive/verify includes CRG Archive Gate.

## Required tool names must appear where applicable

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

## Report

- missing evidence
- missing tools
- stale evidence
- whether next phase is allowed

If evidence is missing, do not continue. Fix evidence first.
