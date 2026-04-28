# Spcrg Plan

Change ID:

$ARGUMENTS

## Resolve change-id if missing

If `$ARGUMENTS` is empty:

1. Run `scripts/detect-change-id.sh`.
2. If exactly one active change exists, report it and ask the user to confirm before using it.
3. If multiple active changes exist, list them and ask the user to pick one.
4. If none exist, tell the user to run `/spcrg-start <description>` or `/opsx:propose <description>` first, then stop.

Do not proceed until a concrete change-id is chosen.

## Gate: before planning

Before writing the plan, run:

```
scripts/check-openspec-gate.sh $ARGUMENTS
scripts/check-crg-evidence.sh $ARGUMENTS
```

If either command fails:

1. Do not run `superpowers:writing-plans`.
2. Report exactly what is missing.
3. If the missing item can be fixed from existing context, fix the OpenSpec artifact or CRG Evidence first.
4. Re-run the failed script.
5. Continue only after both scripts pass.

## Plan phase

Use `superpowers:writing-plans` to rewrite the OpenSpec tasks file.

### Input files

- openspec/changes/$ARGUMENTS/proposal.md
- openspec/changes/$ARGUMENTS/design.md
- openspec/changes/$ARGUMENTS/specs/**
- openspec/changes/$ARGUMENTS/tasks.md

### CRG Planning Analysis

Before writing the plan, run these CRG tools:

Required:

- get_minimal_context_tool
- semantic_search_nodes_tool
- query_graph_tool for callers/callees/imports/tests_for
- get_impact_radius_tool

For complex flows, also use:

- traverse_graph_tool
- list_flows_tool
- get_flow_tool
- find_large_functions_tool

> Tool names may appear with or without the `_tool` suffix in Claude Code. Use the actual tool names exposed by the CRG MCP server and record the exact names used inside CRG Evidence.

### Output

Rewrite:

openspec/changes/$ARGUMENTS/tasks.md

Requirements:

1. Preserve OpenSpec checklist format.
2. Every task must include:
   - task id
   - exact files
   - TDD steps
   - verification command
   - related spec/design reference
   - related CRG evidence
3. Every phase must include:
   - CRG Pre-Phase Check
   - Tasks
   - CRG Post-Phase Check
4. Do not expand scope beyond OpenSpec.
5. Stop after writing the plan and ask for execution approval.

If CRG evidence is missing, run CRG first.
