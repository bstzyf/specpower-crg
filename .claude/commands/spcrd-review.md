# Spcrd Review

Change ID:

$ARGUMENTS

Run final review for this OpenSpec change.

## Phase 1: OpenSpec Compliance Review

Check:

- proposal.md
- design.md
- specs/**
- tasks.md
- GIVEN/WHEN/THEN scenarios
- scope / out of scope
- success criteria

## Phase 2: CRG Final Impact Review

Required CRG tools:

- detect_changes_tool
- get_review_context_tool
- get_impact_radius_tool
- get_affected_flows_tool
- query_graph_tool pattern="tests_for"
- get_knowledge_gaps_tool

If architecture-sensitive, also use:

- get_surprising_connections_tool
- get_hub_nodes_tool
- get_bridge_nodes_tool
- get_suggested_questions_tool

## Phase 3: Superpowers Review

Use:

superpowers:requesting-code-review

Check:

- TDD compliance
- minimal implementation
- YAGNI
- DRY
- complexity
- unverified claims
- test evidence

## Output

- blocking issues
- non-blocking issues
- missing tests
- CRG risk summary
- archive readiness recommendation

Do not archive.
