# specpower-crg

AI Workflow Kit for Claude Code — wraps OpenSpec OPSX + Superpowers + code-review-graph (CRG) into project-level slash commands with the `spcrd` prefix.

The kit's core value isn't just the commands — each command embeds **gate scripts** as its first step, so a phase can't start until the OpenSpec artifacts and CRG evidence from the previous phase actually exist.

## What's inside

```
.claude/commands/
  spcrd-start.md       # propose + CRG Context Pass + brainstorming; gate runs at the END before approval
  spcrd-plan.md        # rewrite tasks.md with TDD + CRG Planning Analysis; gate runs FIRST
  spcrd-dev.md         # subagent-driven TDD with CRG pre/post phase checks; gate runs FIRST
  spcrd-review.md      # OpenSpec + CRG + Superpowers review; gate runs FIRST
  spcrd-archive.md     # verification + CRG Archive Gate + /opsx:verify + /opsx:archive; gate runs FIRST and again before /opsx:verify
  spcrd-bugfix.md      # systematic debugging + CRG diagnosis (no gate for plain bugfix)
  spcrd-hotfix.md      # minimal production fix + CRG fast diagnosis (gate if OpenSpec hotfix record exists)
  spcrd-refactor.md    # CRG refactor assessment + Superpowers brainstorming
  spcrd-audit.md       # CRG evidence completeness audit; gate runs FIRST but is report-only

.claude/skills/
  project-development-workflow/SKILL.md

scripts/
  install-ai-workflow-kit.sh   # self-contained installer (auto-generated)
  build-installer.sh           # regenerates the installer from source
  verify-install.sh            # §14 acceptance checks
  check-crg-evidence.sh        # CRG evidence gate
  check-openspec-gate.sh       # OpenSpec artifact gate
  detect-change-id.sh          # list active changes (used for $ARGUMENTS-missing flow)
```

## Install into another project

From the target project root:

```bash
bash /path/to/specpower-crg/scripts/install-ai-workflow-kit.sh
```

The installer runs `scripts/verify-install.sh` at the end and exits non-zero if any acceptance check fails.

Then append the **Project AI Workflow Kit** section from `CLAUDE.md` to your project's `CLAUDE.md`.

## Editing the kit

After changing any command, skill, or gate script, regenerate the installer:

```bash
./scripts/build-installer.sh
./scripts/verify-install.sh .
```

Both should finish green before committing.

## Prerequisites

- OpenSpec — `npm install -g @fission-ai/openspec@latest`
- Superpowers — `/plugin install superpowers@claude-plugins-official`
- code-review-graph — `pipx install code-review-graph && code-review-graph install && code-review-graph build`

See `CLAUDE.md` for detailed setup and gate enforcement matrix.

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

Missing `<change-id>` is handled automatically via `scripts/detect-change-id.sh`.

## Why `spcrd`

`spcrd` = **Sp**ec-driven + **C**ode **R**eview graph **D**evelopment. Short, unique, unlikely to collide with other plugin commands.
