# specpower-crg

AI Workflow Kit for Claude Code — wraps OpenSpec OPSX + Superpowers + code-review-graph (CRG) into project-level slash commands with the `spcrd` prefix.

## What's inside

```
.claude/commands/
  spcrd-start.md       # propose + CRG Context Pass + brainstorming
  spcrd-plan.md        # rewrite tasks.md with TDD + CRG Planning Analysis
  spcrd-dev.md         # subagent-driven TDD with CRG pre/post phase checks
  spcrd-review.md      # OpenSpec + CRG + Superpowers review
  spcrd-archive.md     # verification + CRG Archive Gate + /opsx:verify + /opsx:archive
  spcrd-bugfix.md      # systematic debugging + CRG diagnosis
  spcrd-hotfix.md      # minimal production fix + CRG fast diagnosis
  spcrd-refactor.md    # CRG refactor assessment + Superpowers brainstorming
  spcrd-audit.md       # CRG evidence completeness audit

.claude/skills/
  project-development-workflow/SKILL.md

scripts/
  install-ai-workflow-kit.sh   # one-shot installer (all of the above)
  check-crg-evidence.sh        # CRG evidence gate
  check-openspec-gate.sh       # OpenSpec artifact gate
  detect-change-id.sh          # list active changes
```

## Install into another project

From the target project root:

```bash
bash /path/to/specpower-crg/scripts/install-ai-workflow-kit.sh
```

Or copy the files directly.

Then append the **Project AI Workflow Kit** section from `CLAUDE.md` to your project's `CLAUDE.md`.

## Prerequisites

- OpenSpec — `npm install -g @fission-ai/openspec@latest`
- Superpowers — `/plugin install superpowers@claude-plugins-official`
- code-review-graph — `pipx install code-review-graph && code-review-graph install && code-review-graph build`

See `CLAUDE.md` for detailed setup.

## Daily commands

```
/spcrd-start <description>
/spcrd-plan <change-id>
/spcrd-dev <change-id>
/spcrd-review <change-id>
/spcrd-archive <change-id>
/spcrd-bugfix <bug>
/spcrd-hotfix <incident>
/spcrd-refactor <goal>
/spcrd-audit <change-id>
```

## Why `spcrd`

`spcrd` = **Sp**ec-driven + **C**ode **R**eview graph **D**evelopment. Short, unique, unlikely to collide with other plugin commands.
