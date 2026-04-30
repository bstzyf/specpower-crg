# Changelog

## [5.1.0] - 2026-04-30

### Added
- **`/spcrg-loop` command** — Ralph-driven iterative development mode that
  replaces manual `/spcrg-dev` + `/spcrg-review` with a single self-iterating
  command. Wraps the installed ralph-loop plugin with an 8-stage navigator
  prompt (A: implement → B: verify → C: coverage/E2E → D: Post-Phase
  Verification → E: phase completion check → F: code review + Quantified
  Review → G: self-check → H: complete). Coexists with manual dev+review.
- `loop.maxIterations` (default: 10) and `loop.completionPromise` (default:
  `ARCHIVE_READY`) in `.ai-workflow-kit/config.json`.
- `tests/integration/` with 17 real-Claude integration tests
  (`real-integration-tests.sh`) across 5 categories: Gate behavior (G1–G3),
  State detection (S1–S3), Skill invocation (K1–K5), Output/side-effects
  (O1–O3), Error recovery (E1–E3). Plus 34-case static suite (`run-loop-tests.sh`).
- CRG Discovery table schema for `/spcrg-plan.md` (7 columns: Task | Target
  | Current Behavior | Required Change | Tests | Reference Pattern | Risk)
  now validated by the gate script.

### Fixed
- `scripts/check-crg-evidence.sh` column-positioning: previously hardcoded
  Target=col 1, Risk=col 5, which only matched the legacy fixture schema
  and conflicted with the spcrg-plan documented schema (Target=col 2, Risk=col 7).
  Now parses the header row to locate "Target" and "Risk" columns by name,
  supporting both schemas.
- `/spcrg-loop` Stage A: replaced ambiguous "并行执行" phrasing that caused
  Claude to select `superpowers:dispatching-parallel-agents` instead of
  `superpowers:subagent-driven-development`. Now clearly names
  subagent-driven-development as the plan-execution orchestrator with TDD
  as the per-task driver.
- `/spcrg-loop` placeholder substitution: the `/ralph-loop` invocation
  template used `<maxIterations>`/`<completionPromise>` placeholders that
  Claude could treat as literal strings. Added explicit variable binding
  instructions and a concrete resolved-command example.

### Changed
- `scripts/verify-install.sh`: acceptance checks updated to include
  `spcrg-loop.md` in required commands and gated commands.
- `scripts/check-command-protocols.sh`: validates `Ralph Loop`,
  `Navigator Prompt`, and `ARCHIVE_READY` keywords in `spcrg-loop.md`.
- `scripts/build-installer.sh`: regenerates installer including the new
  command (installer grew from 2991 to 3024 lines).

## [5.0.0] - 2026-04-28

### Breaking changes
- Evidence schema completely changed. V1 evidence does NOT pass V5 gates.
  Reinstall into downstream projects; in-flight changes should be
  restarted from /spcrg-start.
- New required directory `.ai-workflow-kit/` (config + state).

### Added
- CRG Discovery Protocol with mandatory Read Before Decide
- Precision Mapping Protocol for /spcrg-plan (inherits Discovery)
- Delta Check Protocol for /spcrg-dev (state-based continuous vs resumed)
- Post-Phase Verification with PASS|BLOCKING|NEEDS_HUMAN_DECISION verdicts
- Quantified Review with archive_ready gate
- `.ai-workflow-kit/config.json` for team-configurable thresholds
- `.ai-workflow-kit/state/<change-id>.json` for phase progression
- `scripts/check-v5-review.sh` — Quantified Review validation
- `scripts/check-command-protocols.sh` — V5 keyword verification
- `scripts/run-tests.sh` + `tests/fixtures/` for script regression

### Changed
- `scripts/check-crg-evidence.sh` upgraded from grep-based to
  structured schema validation with --shape-only mode
- `scripts/verify-install.sh` adds step 5 (V5 protocol keywords)
- All 9 `spcrg-*` commands updated to V5 protocols

### Removed
- V1-style "just list CRG tool names" evidence pattern

## [1.0.0] - 2026-04-27

- Initial spcrg-prefixed AI Workflow Kit with gate enforcement
