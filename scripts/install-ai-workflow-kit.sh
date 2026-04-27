#!/usr/bin/env bash
#
# AI Workflow Kit installer (spcrd prefix edition)
# Installs:
#   - .claude/commands/spcrd-*.md        (9 slash commands)
#   - .claude/skills/project-development-workflow/SKILL.md
#   - scripts/check-crg-evidence.sh
#   - scripts/check-openspec-gate.sh
#   - scripts/detect-change-id.sh
#
# Run from a project root.

set -euo pipefail

mkdir -p .claude/commands
mkdir -p .claude/skills/project-development-workflow
mkdir -p scripts

#############################################
# Slash commands
#############################################

cat > .claude/commands/spcrd-start.md <<'EOF'
# Spcrd Start: OpenSpec OPSX + Superpowers + CRG

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

9. Stop and ask for human approval.

Do not implement code.

Stop if CRG is unavailable, stale, or fails.
EOF

cat > .claude/commands/spcrd-plan.md <<'EOF'
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
EOF

cat > .claude/commands/spcrd-dev.md <<'EOF'
# Spcrd Development

Change ID:

$ARGUMENTS

Use superpowers:subagent-driven-development.

## Strict rules

1. Only execute tasks from:

openspec/changes/$ARGUMENTS/tasks.md

2. Every task must follow superpowers:test-driven-development:

- write failing test
- confirm red
- implement minimal code
- confirm green
- refactor

3. Before every phase, run CRG Pre-Phase Check.

Required CRG tools before phase:

- query_graph_tool for callers/callees/imports/tests_for
- semantic_search_nodes_tool
- get_impact_radius_tool

If the phase touches a user/business flow, also use:

- list_flows_tool
- get_flow_tool

If the phase touches complex code, also use:

- traverse_graph_tool
- find_large_functions_tool

4. After every phase, run CRG Post-Phase Check.

Required CRG tools after phase:

- detect_changes_tool
- get_impact_radius_tool
- get_affected_flows_tool
- query_graph_tool pattern="tests_for"

If unexpected impact appears, also use:

- get_review_context_tool
- get_surprising_connections_tool
- get_knowledge_gaps_tool

5. Update tasks.md after each task/phase.

6. Stop immediately if:

- unexpected blast radius appears
- spec mismatch appears
- CRG unavailable
- test strategy missing
- subagent needs to exceed scope
EOF

cat > .claude/commands/spcrd-review.md <<'EOF'
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
EOF

cat > .claude/commands/spcrd-archive.md <<'EOF'
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
EOF

cat > .claude/commands/spcrd-bugfix.md <<'EOF'
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
EOF

cat > .claude/commands/spcrd-hotfix.md <<'EOF'
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
EOF

cat > .claude/commands/spcrd-refactor.md <<'EOF'
# Spcrd Refactor Workflow

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

/opsx:propose {refactor-change-name}
EOF

cat > .claude/commands/spcrd-audit.md <<'EOF'
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
EOF

#############################################
# Skill
#############################################

cat > .claude/skills/project-development-workflow/SKILL.md <<'EOF'
---
name: project-development-workflow
description: Use for all feature work, bugfixes, hotfixes, refactors, OpenSpec OPSX changes, CRG evidence checks, and Superpowers-driven development in this project.
---

# Project Development Workflow

Use OpenSpec OPSX, Superpowers, and CRG together.

## Responsibilities

- OpenSpec defines intended behavior.
- CRG defines code facts, dependencies, execution flows, architecture hotspots, and test coverage.
- Superpowers defines execution discipline.

## Core Rules

1. New features and significant changes start with `/spcrd-start`.
2. Do not implement until OpenSpec artifacts and CRG Evidence exist.
3. Use `superpowers:brainstorming` after OpenSpec proposal and CRG Context Pass.
4. Use `superpowers:writing-plans` before implementation.
5. Use `superpowers:subagent-driven-development` for implementation.
6. Use CRG Pre-Phase and Post-Phase checks around every implementation phase.
7. Run OpenSpec compliance review, CRG final impact review, and Superpowers review before archive.
8. Run `/opsx:verify` before `/opsx:archive` when available.

## Command Map

- `/spcrd-start <description>` — propose + CRG Context Pass + brainstorming
- `/spcrd-plan <change-id>` — rewrite tasks.md with TDD + CRG checks
- `/spcrd-dev <change-id>` — subagent-driven TDD execution with CRG pre/post checks
- `/spcrd-review <change-id>` — OpenSpec + CRG + Superpowers review
- `/spcrd-archive <change-id>` — verification + CRG Archive Gate + /opsx:verify + /opsx:archive
- `/spcrd-bugfix <bug>` — lightweight systematic debugging + CRG diagnosis
- `/spcrd-hotfix <incident>` — minimal production fix + CRG fast diagnosis
- `/spcrd-refactor <goal>` — CRG refactor assessment + Superpowers brainstorming
- `/spcrd-audit <change-id>` — CRG evidence completeness audit

## Stop Conditions

Stop and report if:

- CRG is unavailable.
- CRG evidence is missing.
- OpenSpec and code disagree.
- Unexpected blast radius appears.
- Required tests cannot be found or run.
- E2E is required but unavailable.
- A subagent needs to exceed OpenSpec scope.
EOF

#############################################
# Scripts
#############################################

cat > scripts/check-crg-evidence.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

change_id="${1:-}"

if [ -z "$change_id" ]; then
  echo "Usage: scripts/check-crg-evidence.sh <change-id>"
  exit 1
fi

base="openspec/changes/$change_id"

if [ ! -d "$base" ]; then
  echo "OpenSpec change not found: $base"
  exit 1
fi

required_files=(
  "$base/proposal.md"
  "$base/design.md"
  "$base/tasks.md"
)

for file in "${required_files[@]}"; do
  if [ ! -f "$file" ]; then
    echo "Missing file: $file"
    exit 1
  fi

  if ! grep -qi "CRG" "$file"; then
    echo "Missing CRG evidence in $file"
    exit 1
  fi
done

required_tools=(
  "get_minimal_context"
  "semantic_search_nodes"
  "query_graph"
  "get_impact_radius"
)

for tool in "${required_tools[@]}"; do
  if ! grep -R -q "$tool" "$base"; then
    echo "Missing required CRG tool evidence: $tool"
    exit 1
  fi
done

echo "CRG evidence baseline found for $change_id"
EOF

cat > scripts/check-openspec-gate.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

change_id="${1:-}"

if [ -z "$change_id" ]; then
  echo "Usage: scripts/check-openspec-gate.sh <change-id>"
  exit 1
fi

base="openspec/changes/$change_id"

if [ ! -d "$base" ]; then
  echo "OpenSpec change not found: $base"
  exit 1
fi

missing=0

for file in proposal.md design.md tasks.md; do
  if [ ! -f "$base/$file" ]; then
    echo "Missing $base/$file"
    missing=1
  fi
done

if [ ! -d "$base/specs" ]; then
  echo "Missing $base/specs"
  missing=1
fi

if [ "$missing" -ne 0 ]; then
  exit 1
fi

echo "OpenSpec gate passed for $change_id"
EOF

cat > scripts/detect-change-id.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

changes_dir="openspec/changes"

if [ ! -d "$changes_dir" ]; then
  echo "openspec/changes not found"
  exit 1
fi

find "$changes_dir" -maxdepth 1 -mindepth 1 -type d \
  ! -name archive \
  -exec basename {} \; | sort
EOF

chmod +x scripts/check-crg-evidence.sh
chmod +x scripts/check-openspec-gate.sh
chmod +x scripts/detect-change-id.sh

echo ""
echo "AI Workflow Kit installed."
echo ""
echo "Files:"
echo "  .claude/commands/spcrd-{start,plan,dev,review,archive,bugfix,hotfix,refactor,audit}.md"
echo "  .claude/skills/project-development-workflow/SKILL.md"
echo "  scripts/{check-crg-evidence,check-openspec-gate,detect-change-id}.sh"
echo ""
echo "Next:"
echo "  1. Append the Project AI Workflow Kit section to your CLAUDE.md"
echo "  2. Ensure OpenSpec, Superpowers, and code-review-graph are set up"
echo "  3. Try: /spcrd-start <description>"
