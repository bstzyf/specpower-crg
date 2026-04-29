---
name: project-development-workflow
description: Use for all feature work, bugfixes, hotfixes, refactors, OpenSpec OPSX changes, CRG evidence checks, and Superpowers-driven development in this project.
---

# Project Development Workflow

Use OpenSpec OPSX, Superpowers, and CRG together.

## V5 Core Principle

CRG tells where; read code decides what; CRG verifies after.

- CRG is a navigator + verifier, not an evidence collector.
- Every CRG hit MUST be paired with actual source reading before deciding.
- Evidence is structured decisions, not raw tool output.
- Later phases inherit earlier phases' evidence; do NOT re-search from scratch.
- Dev Pre-Phase uses Delta Check, not ritualistic re-queries.
- Verdicts are numeric-consistent; scripts enforce the shape, the agent enforces the thinking.

## Responsibilities

- OpenSpec defines intended behavior.
- CRG defines code facts, dependencies, execution flows, architecture hotspots, and test coverage.
- Superpowers defines execution discipline.

## Core Rules

1. New features and significant changes start with `/spcrg-start`.
2. Do not implement until OpenSpec artifacts and CRG Evidence exist.
3. Use `superpowers:brainstorming` after OpenSpec proposal and CRG Discovery Pass.
4. Use `superpowers:writing-plans` before implementation.
5. Use `superpowers:subagent-driven-development` for implementation.
6. Use CRG Pre-Phase and Post-Phase checks around every implementation phase.
7. Run OpenSpec compliance review, CRG Quantified Review, and Superpowers review before archive.
8. Run `/opsx:verify` before `/opsx:archive` when available.
9. Every CRG hit requires actual source reading before any decision is made.
10. Evidence must use structured schemas — do not record raw tool output as evidence.
11. Later phases inherit earlier phases' evidence; do not re-run Discovery searches from scratch.
12. Dev Pre-Phase runs Delta Check; skip re-queries if the change is continuous from the prior phase.

## Session & State

Each change has a state file at `.ai-workflow-kit/state/<change-id>.json`.

When `/spcrg-*` commands start:
1. Generate or reuse `$AIWK_SESSION_ID` (uuidgen fallback).
2. Compute current tree hash: `git ls-files --stage | sha256sum | cut -c1-16`.
3. Read state to determine phase progression and continuity.
4. Write state at end of each phase completion.

The state file is gitignored — per-developer runtime data.

## Config

Thresholds and gate behavior live in `.ai-workflow-kit/config.json`.
Scripts read via jq (preferred) or python3 (fallback).
If neither available, scripts fall back to hardcoded defaults.
Do not hardcode thresholds in command prose — reference config field names.

## Command Map

| Command | V5 Protocol | Produces Evidence | Gate Scripts |
|---|---|---|---|
| `/spcrg-start <description>` | Discovery Protocol: CRG navigate → agent Read → agent Decide → structured Decision Evidence | `openspec/changes/<id>/design.md#CRG Discovery Evidence` | `check-openspec-gate.sh`, `check-crg-evidence.sh` (run after propose + CRG + brainstorm + write-back, before approval) |
| `/spcrg-plan <change-id>` | Precision Mapping: inherit Discovery + CRG Precision Pass → function-level TDD tasks | `openspec/changes/<id>/tasks.md#CRG Precision Mapping` | `check-openspec-gate.sh`, `check-crg-evidence.sh` (first step) |
| `/spcrg-dev <change-id>` | Delta Check (continuous vs resumed) + TDD red/green/refactor + CRG Post-Phase Verification per phase | `tasks.md#CRG Post-Phase Verification: Phase N` per phase | `check-openspec-gate.sh`, `check-crg-evidence.sh` (first step) |
| `/spcrg-loop <change-id>` | Ralph-Driven Loop: iterative implement → test → verify → review cycle until archive_ready | `tasks.md#CRG Post-Phase Verification` per phase + `design.md#CRG Quantified Review` | `check-openspec-gate.sh`, `check-crg-evidence.sh` (first step) |
| `/spcrg-review <change-id>` | OpenSpec compliance + CRG Quantified Review (aggregate all phases) + Superpowers code review | `design.md#CRG Quantified Review` with `archive_ready` verdict | `check-openspec-gate.sh`, `check-crg-evidence.sh` (first step; `check-v5-review.sh` is this command's OUTPUT, not entry gate) |
| `/spcrg-archive <change-id>` | Assert `archive_ready == yes` + verification + CRG Archive Gate + `/opsx:verify` + `/opsx:archive` + state update | state `phase=archive` | `check-openspec-gate.sh`, `check-crg-evidence.sh`, `check-v5-review.sh` (first step and again before `/opsx:verify`) |
| `/spcrg-bugfix <bug>` | Read Before Decide on diagnosis; CRG fast diagnosis; no OpenSpec gate for plain bugfix | diagnosis notes (informal) | none required for plain bugfix; if upgraded to OpenSpec change, feature gates apply |
| `/spcrg-hotfix <incident>` | Read Before Decide; CRG fast diagnosis; minimal production fix | hotfix notes (informal) | `check-openspec-gate.sh`, `check-crg-evidence.sh` before archive/release sign-off only if a hotfix OpenSpec record exists |
| `/spcrg-refactor <goal>` | Read Before Decide; CRG refactor assessment + Superpowers brainstorming | refactor scope assessment | none required unless OpenSpec record created |
| `/spcrg-audit <change-id>` | Structured evidence completeness audit across all phases | audit report | `check-openspec-gate.sh`, `check-crg-evidence.sh` (first step; report-only, no auto-repair unless requested) |

## Gate Script Matrix

| Command | When to run gate scripts | Must-run scripts | On failure |
|---|---|---|---|
| `/spcrg-start` | after propose + CRG + brainstorm + write-back | `check-openspec-gate.sh`, `check-crg-evidence.sh` | do not request approval; repair and re-run |
| `/spcrg-plan` | first step | `check-openspec-gate.sh`, `check-crg-evidence.sh` | do not run `superpowers:writing-plans` |
| `/spcrg-dev` | first step | `check-openspec-gate.sh`, `check-crg-evidence.sh` | do not run `superpowers:subagent-driven-development` |
| `/spcrg-loop` | first step | `check-openspec-gate.sh`, `check-crg-evidence.sh` | do not start Ralph Loop |
| `/spcrg-review` | first step | `check-openspec-gate.sh`, `check-crg-evidence.sh` | do not enter final review |
| `/spcrg-archive` | first step, and re-check right before `/opsx:verify` | `check-openspec-gate.sh`, `check-crg-evidence.sh`, `check-v5-review.sh` | do not run `/opsx:verify` or `/opsx:archive` |
| `/spcrg-audit` | first step | `check-openspec-gate.sh`, `check-crg-evidence.sh` | report only; no auto-repair unless requested |
| `/spcrg-bugfix` | not required for plain bugfix | n/a | if upgraded to OpenSpec change, gates apply |
| `/spcrg-hotfix` | before archive/release sign-off, only if OpenSpec hotfix record exists | `check-openspec-gate.sh`, `check-crg-evidence.sh` | do not mark ready to ship |

## Missing change-id handling

If `$ARGUMENTS` is empty for `/spcrg-plan`, `/spcrg-dev`, `/spcrg-review`, `/spcrg-archive`, `/spcrg-audit`:

1. Run `scripts/detect-change-id.sh`.
2. One active change → confirm with the user before using it.
3. Multiple active changes → list them and ask the user to pick.
4. No active changes → instruct the user to run `/spcrg-start` first.

## CRG tool names

Tool names in Claude Code may appear with or without the `_tool` suffix. Use whatever name the CRG MCP server actually exposes, and record the exact tool names used in CRG Evidence so later audits can verify usage.

## Stop Conditions

Stop and report if:

- CRG is unavailable.
- CRG evidence is missing.
- OpenSpec and code disagree.
- Unexpected blast radius appears.
- Required tests cannot be found or run.
- E2E is required but unavailable.
- A subagent needs to exceed OpenSpec scope.
- A gate script keeps failing after repair.
- Gate script keeps failing after repair attempt.
