# Spcrd Plan

Change ID:

$ARGUMENTS

Use superpowers:writing-plans to rewrite the OpenSpec tasks file.

## Input files

- openspec/changes/$ARGUMENTS/proposal.md
- openspec/changes/$ARGUMENTS/design.md
- openspec/changes/$ARGUMENTS/specs/**
- openspec/changes/$ARGUMENTS/tasks.md

## CRG Planning Analysis

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

## Output

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
