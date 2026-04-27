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

## Gate scripts

- `scripts/check-openspec-gate.sh <change-id>` — verifies proposal / design / tasks / specs exist.
- `scripts/check-crg-evidence.sh <change-id>` — verifies CRG evidence and baseline tool names appear.
- `scripts/detect-change-id.sh` — lists active change ids under `openspec/changes/`.

## Success criteria

- No one copies long prompts anymore.
- All features start from `/spcrd-start`.
- CRG Evidence is a product of every phase.
- Superpowers automatically drives brainstorm / plan / dev / review / verify.
- OpenSpec stores the long-term memory of proposals / design / specs / tasks / archive.
- `/spcrd-audit` can verify evidence completeness before review.
- Gate scripts can verify readiness before archive.
