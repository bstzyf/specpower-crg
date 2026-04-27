# Spcrd Hotfix Workflow

Production issue:

$ARGUMENTS

Use hotfix workflow.

## Rules

- Minimal fix only.
- No refactor.
- No opportunistic cleanup.
- Must add regression test.
- Must produce rollback plan.

Create minimal OpenSpec hotfix record if needed:

- openspec/changes/hotfix-{issue-id}/proposal.md
- openspec/changes/hotfix-{issue-id}/tasks.md

Use:

superpowers:systematic-debugging

## CRG fast diagnosis required

- get_minimal_context_tool
- semantic_search_nodes_tool
- query_graph_tool callers/callees/tests_for
- get_impact_radius_tool

If production user flow is affected:

- list_flows_tool
- get_flow_tool
- get_affected_flows_tool

## After fix

- detect_changes_tool
- get_impact_radius_tool
- get_review_context_tool
- query_graph_tool pattern="tests_for"

Run critical tests and E2E if relevant.

Stop if blast radius exceeds hotfix scope.
