# specpower-crg

AI Workflow Kit for Claude Code — wraps OpenSpec OPSX + Superpowers + code-review-graph (CRG) into project-level slash commands with the `spcrg` prefix.

The kit's core value isn't just the commands — each command embeds **gate scripts** as its first step, so a phase can't start until the OpenSpec artifacts and CRG evidence from the previous phase actually exist.

> **V5:** CRG upgraded from evidence collector to code navigator + risk verifier.

## What's inside

```
.claude/commands/
  spcrg-start.md       # propose + CRG Context Pass + brainstorming; gate runs at the END before approval
  spcrg-plan.md        # rewrite tasks.md with TDD + CRG Planning Analysis; gate runs FIRST
  spcrg-dev.md         # subagent-driven TDD with CRG pre/post phase checks; gate runs FIRST
  spcrg-review.md      # OpenSpec + CRG + Superpowers review; gate runs FIRST
  spcrg-archive.md     # verification + CRG Archive Gate + /opsx:verify + /opsx:archive; gate runs FIRST and again before /opsx:verify
  spcrg-bugfix.md      # systematic debugging + CRG diagnosis (no gate for plain bugfix)
  spcrg-hotfix.md      # minimal production fix + CRG fast diagnosis (gate if OpenSpec hotfix record exists)
  spcrg-refactor.md    # CRG refactor assessment + Superpowers brainstorming
  spcrg-audit.md       # CRG evidence completeness audit; gate runs FIRST but is report-only

.claude/skills/
  project-development-workflow/SKILL.md

scripts/
  install-ai-workflow-kit.sh   # self-contained installer (auto-generated)
  build-installer.sh           # regenerates the installer from source
  verify-install.sh            # §14 acceptance checks
  check-crg-evidence.sh        # CRG evidence gate (structured schema validation)
  check-openspec-gate.sh       # OpenSpec artifact gate
  check-v5-review.sh           # Quantified Review validation (archive_ready gate)
  check-command-protocols.sh   # V5 keyword verification across all commands
  detect-change-id.sh          # list active changes (used for $ARGUMENTS-missing flow)
  run-tests.sh                 # script regression test runner (framework-dev only)

.ai-workflow-kit/
  config.json                  # team-configurable thresholds (committed)
  state/<change-id>.json       # per-developer phase progression (gitignored)

tests/fixtures/                # regression fixtures for gate scripts (framework-dev only)
```

## V5 Workflow

```
Requirement → CRG NAVIGATE → Agent READ → Agent DECIDE
           → Superpowers DO → CRG VERIFY → OpenSpec ARCHIVE
```

Each phase builds on the previous phase's evidence. No blind re-search.

## V5 vs V1

| Aspect | V1 | V5 |
|---|---|---|
| CRG role | Evidence collector (list tools) | Code navigator + risk verifier |
| Evidence format | Free-text with tool names | Structured schemas with required fields |
| Plan granularity | Module-level tasks | file:function with TDD steps |
| Dev pre-phase | Ritualistic broad CRG queries | Delta Check (skip if continuous) |
| Review output | Advisory list | Quantified verdict with archive_ready gate |

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
./scripts/run-tests.sh
```

All three should finish green before committing.

## Prerequisites

- OpenSpec — `npm install -g @fission-ai/openspec@latest`
- Superpowers — `/plugin install superpowers@claude-plugins-official`
- code-review-graph — `pipx install code-review-graph && code-review-graph install && code-review-graph build`

See `CLAUDE.md` for detailed setup and gate enforcement matrix.

## Daily commands

```
/spcrg-start <description>
/spcrg-plan <change-id>
/spcrg-dev <change-id>
/spcrg-review <change-id>
/spcrg-archive <change-id>
/spcrg-bugfix <bug>
/spcrg-hotfix <incident>
/spcrg-refactor <goal>
/spcrg-audit <change-id>
```

Missing `<change-id>` is handled automatically via `scripts/detect-change-id.sh`.

## Why `spcrg`

`spcrg` = **Sp**ec-driven + **C**ode **R**eview **G**raph. Maps directly to the `specpower-crg` repo name. Short, unique, unlikely to collide with other plugin commands.
