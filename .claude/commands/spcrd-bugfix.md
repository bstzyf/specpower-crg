# Spcrd Bugfix Workflow

Bug:

$ARGUMENTS

Use lightweight bugfix workflow unless behavior/spec changes are discovered.

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

## Then

1. Write regression test.
2. Use superpowers:test-driven-development.
3. Fix minimally.
4. Run CRG after fix:
   - detect_changes_tool
   - get_impact_radius_tool
   - query_graph_tool pattern="tests_for"

If expected behavior changes, stop and upgrade to:

/opsx:propose fix-{bug-name}
