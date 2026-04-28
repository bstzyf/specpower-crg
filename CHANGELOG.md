# Changelog

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
