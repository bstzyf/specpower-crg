# Project AI Workflow Kit

This project uses OpenSpec OPSX, Superpowers, and code-review-graph together.

Use project commands instead of ad-hoc long prompts:

- `/spcrd-start <description>`
- `/spcrd-plan <change-id>`
- `/spcrd-dev <change-id>`
- `/spcrd-review <change-id>`
- `/spcrd-archive <change-id>`
- `/spcrd-bugfix <bug description>`
- `/spcrd-hotfix <incident description>`
- `/spcrd-refactor <goal>`
- `/spcrd-audit <change-id>`

## Responsibilities

- OpenSpec defines intended behavior, requirements, specs, and long-term history.
- CRG defines actual code structure, dependency impact, execution flows, architecture hotspots, and test coverage.
- Superpowers defines execution discipline: brainstorming, planning, TDD, subagents, review, verification.

## Rules

1. New features and significant changes must start with `/spcrd-start`.
2. Implementation must not start until OpenSpec artifacts and CRG Evidence exist.
3. Superpowers planning and development must preserve OpenSpec scope.
4. CRG Evidence is mandatory at phase transitions.
5. If CRG is unavailable or evidence is missing, stop and report.
6. If unexpected blast radius appears, stop and report.
7. If behavior or scope changes, update OpenSpec artifacts before continuing.
8. Archive only after review, tests, CRG Archive Gate, and `/opsx:verify` pass.

## Gate enforcement

Gates are not advisory — they run as the **first step** (or, for `/spcrd-start`, as the **last step before approval**) of each phase command.

| Command | Gate timing | On failure |
|---|---|---|
| `/spcrd-start` | after propose + CRG + brainstorm + write-back | do not request approval; fix artifacts/evidence; re-run |
| `/spcrd-plan` | first step | do not run `superpowers:writing-plans` |
| `/spcrd-dev` | first step | do not run `superpowers:subagent-driven-development` |
| `/spcrd-review` | first step | do not enter final review |
| `/spcrd-archive` | first step and again right before `/opsx:verify` | do not run `/opsx:verify` or `/opsx:archive` |
| `/spcrd-audit` | first step | **report-only**, no auto-repair unless requested |
| `/spcrd-bugfix` | not required for plain bugfixes | if upgraded to an OpenSpec change, feature-style gates apply |
| `/spcrd-hotfix` | before archive/release sign-off, only if a hotfix OpenSpec record exists | do not mark ready to ship |

If `$ARGUMENTS` is missing for a command that needs a change-id, Claude will run `scripts/detect-change-id.sh` and either confirm the single active change, list multiple active changes for selection, or ask the user to run `/spcrd-start` first.

## CRG tool names

Tool names may appear with or without the `_tool` suffix in Claude Code. Use the actual names exposed by the CRG MCP server and record the exact names used inside CRG Evidence so `/spcrd-audit` can verify usage later.

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
├── .claude/
│   ├── commands/
│   │   ├── spcrd-start.md
│   │   ├── spcrd-plan.md
│   │   ├── spcrd-dev.md
│   │   ├── spcrd-review.md
│   │   ├── spcrd-archive.md
│   │   ├── spcrd-bugfix.md
│   │   ├── spcrd-hotfix.md
│   │   ├── spcrd-refactor.md
│   │   └── spcrd-audit.md
│   └── skills/
│       └── project-development-workflow/
│           └── SKILL.md
├── scripts/
│   ├── install-ai-workflow-kit.sh
│   ├── build-installer.sh
│   ├── verify-install.sh
│   ├── check-crg-evidence.sh
│   ├── check-openspec-gate.sh
│   └── detect-change-id.sh
└── openspec/
```

## Daily usage

New feature:

```
/spcrd-start 添加用户搜索，支持姓名和邮箱搜索，需要分页和权限控制
/spcrd-plan add-user-search
/spcrd-dev add-user-search
/spcrd-review add-user-search
/spcrd-archive add-user-search
```

Bugfix:

```
/spcrd-bugfix 登录态过期后刷新页面报 500
```

Hotfix:

```
/spcrd-hotfix 生产支付回调失败导致订单未完成
```

Refactor:

```
/spcrd-refactor 拆分 user service 中的大函数并保持行为不变
```

CRG evidence audit:

```
/spcrd-audit add-user-search
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
/spcrd-start test workflow kit with a tiny harmless change
scripts/detect-change-id.sh
scripts/check-openspec-gate.sh <change-id>
scripts/check-crg-evidence.sh <change-id>
/spcrd-plan <change-id>   # confirm plan runs the gate first
```

## Success criteria

- No one copies long prompts anymore.
- All features start from `/spcrd-start`.
- CRG Evidence is a product of every phase.
- Superpowers automatically drives brainstorm / plan / dev / review / verify.
- OpenSpec stores the long-term memory of proposals / design / specs / tasks / archive.
- `/spcrd-audit` can verify evidence completeness before review.
- Gate scripts are invoked automatically by the commands — not by trust.
