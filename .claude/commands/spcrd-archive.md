# Spcrd Archive

Change ID:

$ARGUMENTS

Before archive, run final verification.

Use:

superpowers:verification-before-completion

## Run project checks

- unit tests
- integration tests
- E2E if applicable
- lint
- typecheck
- build

## CRG Archive Gate

Before /opsx:verify, run:

- detect_changes_tool
- get_review_context_tool
- get_impact_radius_tool
- get_affected_flows_tool
- get_knowledge_gaps_tool

If user flow is affected, also use:

- list_flows_tool
- get_flow_tool

Then run:

/opsx:verify $ARGUMENTS

If verify passes, run:

/opsx:archive $ARGUMENTS

## Report

- updated specs
- archive location
- test evidence
- CRG evidence
- merge/PR readiness
