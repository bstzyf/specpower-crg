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

- `/spcrd-start <description>` — propose + CRG Context Pass + brainstorming (gate runs at the **end**, before asking for approval)
- `/spcrd-plan <change-id>` — rewrite tasks.md with TDD + CRG checks (gate runs **first**)
- `/spcrd-dev <change-id>` — subagent-driven TDD execution with CRG pre/post checks (gate runs **first**)
- `/spcrd-review <change-id>` — OpenSpec + CRG + Superpowers review (gate runs **first**)
- `/spcrd-archive <change-id>` — verification + CRG Archive Gate + /opsx:verify + /opsx:archive (gate runs **first**, and re-checks right before `/opsx:verify`)
- `/spcrd-bugfix <bug>` — lightweight systematic debugging + CRG diagnosis. No OpenSpec gate for plain bugfixes; upgrade to `/opsx:propose fix-...` if behavior changes, then feature-style gates apply.
- `/spcrd-hotfix <incident>` — minimal production fix + CRG fast diagnosis. If a hotfix OpenSpec record is created, gates apply before archive / release-readiness.
- `/spcrd-refactor <goal>` — CRG refactor assessment + Superpowers brainstorming
- `/spcrd-audit <change-id>` — CRG evidence completeness audit (gate runs but is **report-only**)

## Gate Script Matrix

| Command | When to run gate scripts | Must-run scripts | On failure |
|---|---|---|---|
| `/spcrd-start` | after propose + CRG + brainstorm + write-back | `check-openspec-gate.sh`, `check-crg-evidence.sh` | do not request approval; repair and re-run |
| `/spcrd-plan` | first step | `check-openspec-gate.sh`, `check-crg-evidence.sh` | do not run `superpowers:writing-plans` |
| `/spcrd-dev` | first step | `check-openspec-gate.sh`, `check-crg-evidence.sh` | do not run `superpowers:subagent-driven-development` |
| `/spcrd-review` | first step | `check-openspec-gate.sh`, `check-crg-evidence.sh` | do not enter final review |
| `/spcrd-archive` | first step, and re-check right before `/opsx:verify` | `check-openspec-gate.sh`, `check-crg-evidence.sh` | do not run `/opsx:verify` or `/opsx:archive` |
| `/spcrd-audit` | first step | `check-openspec-gate.sh`, `check-crg-evidence.sh` | report only; no auto-repair unless requested |
| `/spcrd-bugfix` | not required for plain bugfix | n/a | if upgraded to OpenSpec change, gates apply |
| `/spcrd-hotfix` | before archive/release sign-off, only if OpenSpec hotfix record exists | `check-openspec-gate.sh`, `check-crg-evidence.sh` | do not mark ready to ship |

## Missing change-id handling

If `$ARGUMENTS` is empty for `/spcrd-plan`, `/spcrd-dev`, `/spcrd-review`, `/spcrd-archive`, `/spcrd-audit`:

1. Run `scripts/detect-change-id.sh`.
2. One active change → confirm with the user before using it.
3. Multiple active changes → list them and ask the user to pick.
4. No active changes → instruct the user to run `/spcrd-start` first.

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
- A gate script keeps failing after a repair attempt.
