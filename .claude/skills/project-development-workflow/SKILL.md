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
