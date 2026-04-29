# Spcrg Hotfix Workflow

Production issue:

$ARGUMENTS

Use hotfix workflow.

## Rules

- Minimal fix only.
- No refactor.
- No opportunistic cleanup.
- Must add regression test.
- Must produce rollback plan.

## OpenSpec hotfix record (optional)

If this hotfix needs to be tracked in OpenSpec, create:

- openspec/changes/hotfix-{issue-id}/proposal.md
- openspec/changes/hotfix-{issue-id}/tasks.md

When a hotfix OpenSpec record exists, the gate applies **before archive or release-readiness sign-off**:

```
scripts/check-openspec-gate.sh hotfix-{issue-id}
scripts/check-crg-evidence.sh hotfix-{issue-id}
```

If either script fails:

1. Do not mark the hotfix as ready to ship.
2. Do not run `/opsx:verify` or `/opsx:archive`.
3. Fix the missing artifacts/evidence, then re-run the scripts.

For hotfixes without an OpenSpec record, skip the OpenSpec gate but still produce CRG evidence in the PR description.

## Debugging

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

> Tool names may appear with or without the `_tool` suffix in Claude Code. Use the actual tool names exposed by the CRG MCP server.

## After fix

- detect_changes_tool
- get_impact_radius_tool
- get_review_context_tool
- query_graph_tool pattern="tests_for"

Run critical tests and E2E if relevant.

Stop if blast radius exceeds hotfix scope.

## V5 Rule: Read Before Decide

Before writing a diagnosis or decision, read the actual source files for
the relevant CRG hits. Use CRG to locate; use source reading to decide.
Do not write raw CRG output as evidence. Write decision evidence.

## V5 Gate on Archive

If a hotfix OpenSpec record exists (`openspec/changes/hotfix-{issue-id}/`),
running `/opsx:verify` or `/opsx:archive` requires all V5 gates:
- scripts/check-openspec-gate.sh hotfix-{issue-id}
- scripts/check-crg-evidence.sh hotfix-{issue-id}
- scripts/check-v5-review.sh hotfix-{issue-id}
