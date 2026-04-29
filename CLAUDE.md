# Project AI Workflow Kit

This project uses OpenSpec OPSX, Superpowers, and code-review-graph together.

Use project commands instead of ad-hoc long prompts:

- `/spcrg-start <description>`
- `/spcrg-plan <change-id>`
- `/spcrg-dev <change-id>`
- `/spcrg-loop <change-id>`
- `/spcrg-review <change-id>`
- `/spcrg-archive <change-id>`
- `/spcrg-bugfix <bug description>`
- `/spcrg-hotfix <incident description>`
- `/spcrg-refactor <goal>`
- `/spcrg-audit <change-id>`

## Responsibilities

- OpenSpec defines intended behavior, requirements, specs, and long-term history.
- CRG defines actual code structure, dependency impact, execution flows, architecture hotspots, and test coverage.
- Superpowers defines execution discipline: brainstorming, planning, TDD, subagents, review, verification.

## Rules

1. New features and significant changes must start with `/spcrg-start`.
2. Implementation must not start until OpenSpec artifacts and CRG Evidence exist.
3. Superpowers planning and development must preserve OpenSpec scope.
4. CRG Evidence is mandatory at phase transitions.
5. If CRG is unavailable or evidence is missing, stop and report.
6. If unexpected blast radius appears, stop and report.
7. If behavior or scope changes, update OpenSpec artifacts before continuing.
8. Archive only after review, tests, CRG Archive Gate, and `/opsx:verify` pass.
9. CRG tells where, read code decides what, CRG verifies after.
10. Evidence is structured decisions, not raw tool output.
11. Later phases inherit earlier phases' evidence; no blind re-search.
12. Verdicts must be numeric-consistent with the data.

## Gate enforcement

Gates are not advisory — they run as the **first step** (or, for `/spcrg-start`, as the **last step before approval**) of each phase command.

| Command | Gate timing | On failure |
|---|---|---|
| `/spcrg-start` | after propose + CRG + brainstorm + write-back | do not request approval; fix artifacts/evidence; re-run |
| `/spcrg-plan` | first step | do not run `superpowers:writing-plans` |
| `/spcrg-dev` | first step | do not run `superpowers:subagent-driven-development` |
| `/spcrg-loop` | first step | do not start Ralph Loop |
| `/spcrg-review` | first step | do not enter final review |
| `/spcrg-archive` | first step and again right before `/opsx:verify` (includes `check-v5-review.sh`) | do not run `/opsx:verify` or `/opsx:archive` |
| `/spcrg-audit` | first step | **report-only**, no auto-repair unless requested |
| `/spcrg-bugfix` | not required for plain bugfixes | if upgraded to an OpenSpec change, feature-style gates apply |
| `/spcrg-hotfix` | before archive/release sign-off, only if a hotfix OpenSpec record exists | do not mark ready to ship |

If `$ARGUMENTS` is missing for a command that needs a change-id, Claude will run `scripts/detect-change-id.sh` and either confirm the single active change, list multiple active changes for selection, or ask the user to run `/spcrg-start` first.

## CRG tool names

Tool names may appear with or without the `_tool` suffix in Claude Code. Use the actual names exposed by the CRG MCP server and record the exact names used inside CRG Evidence so `/spcrg-audit` can verify usage later.

## Prerequisites

### OpenSpec

```
npm install -g @fission-ai/openspec@latest
cd your-project
openspec init
```

For expanded workflow (`/opsx:verify` etc.):

```
openspec config profile
openspec update
```

### Superpowers

Inside Claude Code:

```
/plugin install superpowers@claude-plugins-official
```

Fallback:

```
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

### jq / python3

```
# macOS
brew install jq

# Linux
apt-get install jq   # or yum install jq
```

`jq` (recommended) or `python3` (fallback) is required for reading `.ai-workflow-kit/config.json`.
If neither is available, gate scripts fall back to hardcoded defaults.

### CRG (code-review-graph)

```
pipx install code-review-graph
# or: pip install code-review-graph

code-review-graph install
code-review-graph build
```

Recommended `.code-review-graphignore`:

```
node_modules/**
dist/**
build/**
coverage/**
vendor/**
tmp/**
.cache/**
*.generated.*
openspec/changes/archive/**
```

## Layout

```
.
├── CLAUDE.md
├── CHANGELOG.md
├── .ai-workflow-kit/
│   ├── config.json
│   └── state/                   (gitignored — per-developer runtime data)
│       └── <change-id>.json
├── .claude/
│   ├── commands/
│   │   ├── spcrg-start.md
│   │   ├── spcrg-plan.md
│   │   ├── spcrg-dev.md
│   │   ├── spcrg-review.md
│   │   ├── spcrg-archive.md
│   │   ├── spcrg-bugfix.md
│   │   ├── spcrg-hotfix.md
│   │   ├── spcrg-refactor.md
│   │   └── spcrg-audit.md
│   └── skills/
│       └── project-development-workflow/
│           └── SKILL.md
├── scripts/
│   ├── install-ai-workflow-kit.sh
│   ├── build-installer.sh
│   ├── verify-install.sh
│   ├── check-crg-evidence.sh
│   ├── check-openspec-gate.sh
│   ├── check-v5-review.sh
│   ├── check-command-protocols.sh
│   └── detect-change-id.sh
├── tests/
│   └── fixtures/
└── openspec/
```

## Daily usage

New feature (manual mode):

```
/spcrg-start 添加用户搜索，支持姓名和邮箱搜索，需要分页和权限控制
/spcrg-plan add-user-search
/spcrg-dev add-user-search
/spcrg-review add-user-search
/spcrg-archive add-user-search
```

New feature (loop mode — Ralph-driven iterative development):

```
/spcrg-start 添加用户搜索，支持姓名和邮箱搜索，需要分页和权限控制
/spcrg-plan add-user-search
/spcrg-loop add-user-search
/spcrg-archive add-user-search
```

Bugfix:

```
/spcrg-bugfix 登录态过期后刷新页面报 500
```

Hotfix:

```
/spcrg-hotfix 生产支付回调失败导致订单未完成
```

Refactor:

```
/spcrg-refactor 拆分 user service 中的大函数并保持行为不变
```

CRG evidence audit:

```
/spcrg-audit add-user-search
```

## Reading V5 Evidence

Check change progress:

```
cat .ai-workflow-kit/state/<change-id>.json | jq .
```

Verify evidence completeness:

```
scripts/check-crg-evidence.sh <change-id>
scripts/check-v5-review.sh <change-id>
```

Full framework test (developers):

```
scripts/run-tests.sh
```

## Gate & utility scripts

- `scripts/check-openspec-gate.sh <change-id>` — verifies proposal / design / tasks / specs exist.
- `scripts/check-crg-evidence.sh <change-id>` — verifies CRG evidence and baseline tool names appear.
- `scripts/detect-change-id.sh` — lists active change-ids under `openspec/changes/`.
- `scripts/verify-install.sh [root]` — acceptance checks (§14.1–14.3); exits non-zero if any command, script, or embedded gate is missing.
- `scripts/build-installer.sh` — regenerates `install-ai-workflow-kit.sh` from the current source files (run after editing commands or scripts).

## Dry run acceptance

After installing into a fresh project:

```
scripts/verify-install.sh .
/spcrg-start test workflow kit with a tiny harmless change
scripts/detect-change-id.sh
scripts/check-openspec-gate.sh <change-id>
scripts/check-crg-evidence.sh <change-id>
/spcrg-plan <change-id>   # confirm plan runs the gate first
```

## Success criteria

- No one copies long prompts anymore.
- All features start from `/spcrg-start`.
- CRG Evidence is a product of every phase.
- Superpowers automatically drives brainstorm / plan / dev / review / verify.
- OpenSpec stores the long-term memory of proposals / design / specs / tasks / archive.
- `/spcrg-audit` can verify evidence completeness before review.
- Gate scripts are invoked automatically by the commands — not by trust.
- Plan tasks are at file:function granularity, not module-level TODOs.
- Dev produces per-phase Post-Phase Verification with verdict.
- Review gives `archive_ready: yes/no` with quantified backing.
- Scripts enforce shape; commands enforce thinking.
