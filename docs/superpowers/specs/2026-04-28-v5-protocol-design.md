# AI Workflow Kit V5 Protocol — Design Spec

**Date:** 2026-04-28
**Status:** approved for implementation
**Scope:** Upgrade specpower-crg from V1 (gate-driven prompt wrappers) to V5 (decision-driven development OS)
**Based on:** Feishu doc "AI Workflow Kit V5 设计实施方案" + current V1 implementation in this repo

---

## 0. One-line definition

V5 is not "run more CRG tools and paste the output into docs." It upgrades CRG from an evidence collector into a **code navigator + risk verifier**. The loop is:

```
Requirement / OpenSpec
  → CRG NAVIGATE (where to look)
  → Agent READ (actual source code)
  → Agent DECIDE (what to change)
  → Superpowers DO (TDD red/green/refactor)
  → CRG VERIFY (actual impact)
  → OpenSpec ARCHIVE (long-term memory)
```

Core rule: **CRG tells where; read code decides what; CRG verifies after.**

---

## 1. Starting state (V1)

The repository already ships:

- 9 `spcrg-*` slash commands in `.claude/commands/`
- Project skill at `.claude/skills/project-development-workflow/SKILL.md`
- 3 gate scripts: `check-openspec-gate.sh`, `check-crg-evidence.sh`, `detect-change-id.sh`
- `verify-install.sh`, `build-installer.sh`, `install-ai-workflow-kit.sh`
- `CLAUDE.md`, `README.md`

V1 correctly put gate scripts inside commands (not just as advisory scripts) and adopted the `spcrg` prefix. Its weakness is that CRG is used mechanically: tool names are listed, `check-crg-evidence.sh` only greps for those names, and each phase re-runs the same searches. V5 fixes the mechanism without changing the top-level UX (same 9 commands, same names).

---

## 2. V5 design goals and principles

**Product goal.** Team members keep typing the same 9 commands. The behavior behind each command upgrades:

| Command | V1 behavior | V5 behavior |
|---|---|---|
| `/spcrg-start` | propose + list CRG tools + brainstorm | Discovery Protocol + mandatory source reading + structured Decision Evidence |
| `/spcrg-plan` | re-run broad CRG queries + write tasks | inherit Discovery + Precision Mapping + function-level TDD tasks via `superpowers:writing-plans` |
| `/spcrg-dev` | ritualistic pre-phase CRG checks | Delta Check (skip if continuous) + Post-Phase Verification with `PASS\|BLOCKING\|NEEDS_HUMAN_DECISION` verdict |
| `/spcrg-review` | list findings | Quantified Review with numeric thresholds and `archive_ready` gate |
| `/spcrg-archive` | run checks + /opsx:verify | same + enforce Quantified Review's `archive_ready=yes` |
| `/spcrg-audit` | grep tool names | call structured check scripts + semantic audit |
| `/spcrg-bugfix/hotfix/refactor` | workflow hints | + explicit "Read Before Decide" clause |

**Seven design principles.**

1. **CRG Navigation First** — CRG answers "where to look," not "what to change."
2. **Read Before Decide** — every CRG hit is paired with real source reading.
3. **Decision Evidence, Not Raw Evidence** — OpenSpec docs record structured decisions, not raw tool output.
4. **No Repeated Blind Search** — a later phase inherits earlier evidence; it does not re-search from scratch.
5. **Delta Over Ritual** — Dev Pre-Phase only runs CRG delta checks when context may have changed.
6. **Verification Has Teeth** — Review and Post-Phase produce `PASS | BLOCKING | NEEDS_HUMAN_DECISION`.
7. **Scripts Enforce Shape, Commands Enforce Thinking** — shell scripts validate evidence structure and numeric consistency; command files constrain agent reasoning and stop conditions.

---

## 3. Clarifying decisions (locked)

Eight load-bearing decisions were made during brainstorming:

| # | Question | Decision | Rationale |
|---|---|---|---|
| 1 | V5 delivery scope | Phase 1+2+3 in one shot (protocol text + structured scripts + installer rebuild). Phase 4 (real-project dry run) is user-driven, out of scope for this spec. | All three phases compose a shippable unit; intermediate states are awkward. |
| 2 | Verdict computation | Hybrid (C): Agent writes verdict, scripts perform **numeric consistency checks** against thresholds. | Avoids agent self-consistent lying (option A) without fragile markdown parsing (option B). |
| 3 | Thresholds storage | `.ai-workflow-kit/config.json`, read by `jq` (preferred) or `python3` (fallback), else hardcoded defaults. | Single source of truth; team-configurable; no mandatory new binary dependency. |
| 4 | V1 compatibility mode | None. V1 evidence fails V5 gates by design. | No downstream installations yet; compatibility mode is YAGNI. |
| 5 | Script layout | 5 scripts total: upgrade `check-crg-evidence.sh`, add `check-v5-review.sh` + `check-command-protocols.sh`, keep `check-openspec-gate.sh` and `detect-change-id.sh`. | Clear separation of concerns; no overlap between `check-v5-evidence` and the upgraded `check-crg-evidence`. |
| 6 | Read Before Decide enforcement | Medium strictness: section must exist, Code Reading Summary table must have ≥ `discoveryMinReadings` rows (default 2), Precision Plan Change Map ≥ `precisionPlanMinTasks` rows (default 1), all required columns non-empty. | Blocks obvious hand-waving without forcing semantic parsing. |
| 7 | Dev session continuity | State file `.ai-workflow-kit/state/<change-id>.json` with `sessionId`, `treeHash`, and phase history. | Survives restarts; matches doc §5.3 intent; keeps Delta Check cheap. |
| 8 | Script testing | `tests/fixtures/` + `scripts/run-tests.sh` with good/bad case pairs. Naming convention `good-*` / `bad-*` determines expected exit code. | Provides regression safety as scripts grow beyond V1 simple grep. |

---

## 4. Architecture

### 4.1 Layers

| Layer | Purpose | Input | Output |
|---|---|---|---|
| Command layer (`.claude/commands/`) | Constrain agent reasoning and stop conditions | `$ARGUMENTS`, OpenSpec files, CRG tools | Updated OpenSpec files + structured Evidence |
| Gate script layer (`scripts/`) | Structural validation + numeric consistency checks | Evidence markdown + `config.json` | Pass/fail with line-level location |
| Config layer (`.ai-workflow-kit/config.json`) | Single source of truth for thresholds and gate switches | Installer writes defaults; users tune | Scripts read via jq/python3 |
| State layer (`.ai-workflow-kit/state/`) | Per-change phase progression, session continuity | Agent writes at each phase completion | Dev Delta Check reads |
| Installer layer | Packaging and distribution | All of the above | Self-contained shell installer |
| Test layer (`tests/fixtures/` + `run-tests.sh`) | Script regression protection | good/bad fixture evidence | Pass/fail |

### 4.2 End-to-end data flow (feature)

```
/spcrg-start
  → /opsx:propose                                  creates openspec/changes/<id>/{proposal,design,specs,tasks}.md
  → CRG Discovery Protocol                         reads actual source
  → write design.md#CRG Discovery                  Section 6.1 schema
  → superpowers:brainstorming                      refines proposal/design/specs/tasks
  → optional CRG Recheck                           only if Decision Synthesis changed
  → gate scripts pass                              check-openspec-gate + check-crg-evidence --shape-only
  → write .ai-workflow-kit/state/<id>.json         phase=start, completed
  → request human approval

/spcrg-plan
  → gate scripts pass                              check-openspec-gate + check-crg-evidence
  → read design.md#CRG Discovery                   no re-search
  → CRG Precision Mapping Protocol                 callers/callees + read code + tests_for
  → superpowers:writing-plans                      input includes Precision Mapping output
  → write tasks.md#CRG Precision Plan              Section 6.2 schema, file:function granularity, TDD steps
  → update state                                   phase=plan
  → request execution approval

/spcrg-dev (per phase)
  → gate scripts pass
  → read state → Delta Check                       continuous vs resumed
  → TDD red/green/refactor                         superpowers:subagent-driven-development + test-driven-development
  → CRG Post-Phase Verification                    detect_changes + impact + tests_for + flows + gaps
  → write tasks.md#CRG Post-Phase Verification: Phase N   Section 6.3 schema
  → apply verdict rules                            PASS → continue; BLOCKING/NEEDS_HUMAN_DECISION → STOP
  → update state.phases.dev.phaseHistory

/spcrg-review
  → gate scripts pass                              check-openspec-gate + check-crg-evidence (check-v5-review is NOT in entry gate — it is this command's output)
  → OpenSpec compliance
  → CRG Quantified Review                          aggregate all phases
  → write design.md#CRG Quantified Review          Section 6.4 schema
  → Superpowers code review
  → self-check: scripts/check-v5-review.sh         must pass before output
  → output archive_ready and blockers

/spcrg-archive
  → gate scripts pass                              check-openspec-gate + check-crg-evidence + **check-v5-review**
  → assert archive_ready == yes                    from Quantified Review
  → superpowers:verification-before-completion
  → project checks                                 tests/lint/typecheck/build/E2E
  → CRG Archive Gate                               re-run relevant CRG tools
  → re-run gate scripts                            last chance
  → /opsx:verify
  → /opsx:archive
  → update state                                   phase=archive
```

---

## 5. File layout (V5)

```
specpower-crg/
├── README.md                                    [changed]
├── CLAUDE.md                                    [changed]
├── CHANGELOG.md                                 [new]
├── .gitignore                                   [changed] add .ai-workflow-kit/state/
├── .ai-workflow-kit/                            [new]
│   ├── config.json                              [new] shipped default
│   └── state/                                   [new, gitignored] per-change runtime data
│       └── <change-id>.json
├── .claude/
│   ├── commands/
│   │   ├── spcrg-start.md                       [rewrite] Discovery Protocol
│   │   ├── spcrg-plan.md                        [rewrite] Precision Mapping
│   │   ├── spcrg-dev.md                         [rewrite] Delta Check + Post-Phase
│   │   ├── spcrg-review.md                      [rewrite] Quantified Review
│   │   ├── spcrg-archive.md                     [changed] add check-v5-review gate + state
│   │   ├── spcrg-bugfix.md                      [minor] Read Before Decide clause
│   │   ├── spcrg-hotfix.md                      [minor] Read Before Decide clause
│   │   ├── spcrg-refactor.md                    [minor] Read Before Decide clause
│   │   └── spcrg-audit.md                       [rewrite] structured evidence audit
│   └── skills/
│       └── project-development-workflow/
│           └── SKILL.md                         [changed] V5 Core Principle + Session/State + Config
├── scripts/
│   ├── build-installer.sh                       [changed] include new scripts + config
│   ├── install-ai-workflow-kit.sh               [regenerated] conditional config creation
│   ├── verify-install.sh                        [changed] add step 5 (protocol keywords)
│   ├── check-openspec-gate.sh                   [unchanged]
│   ├── check-crg-evidence.sh                    [upgraded] structured schema validation + --shape-only
│   ├── check-v5-review.sh                       [new]
│   ├── check-command-protocols.sh               [new]
│   ├── detect-change-id.sh                      [unchanged]
│   └── run-tests.sh                             [new]
├── tests/
│   └── fixtures/                                [new, not bundled in installer]
│       ├── good-discovery-minimal/
│       ├── good-precision-plan/
│       ├── good-post-phase-pass/
│       ├── good-quantified-review-archive-ready/
│       ├── bad-missing-discovery/
│       ├── bad-discovery-one-row/
│       ├── bad-discovery-empty-col/
│       ├── bad-precision-plan-no-phase/
│       ├── bad-precision-plan-bad-target/
│       ├── bad-post-phase-verdict-inconsistent/
│       ├── bad-post-phase-missing-field/
│       ├── bad-quantified-review-archive-yes-with-blocker/
│       ├── bad-quantified-review-drift-over-threshold/
│       └── config.json
└── docs/
    └── superpowers/
        └── specs/
            └── 2026-04-28-v5-protocol-design.md   ← this file
```

**Change volume:** ~15 files changed, ~20 files new.

`.gitignore` addition: `.ai-workflow-kit/state/`. `config.json` is committed (team-shared).

`tests/fixtures/` is **not** packaged by `install-ai-workflow-kit.sh`. Those fixtures live only in this repo, for framework developers.

---

## 6. Evidence data contracts (THE CORE SCHEMA)

All downstream scripts and commands depend on these four schemas. Any change to a schema is a breaking change.

### 6.1 `design.md#CRG Discovery` — produced by `/spcrg-start`

```markdown
## CRG Discovery

### Discovery Metadata
- generated_at: <ISO 8601 UTC>
- generated_by: /spcrg-start
- crg_graph_status: fresh | rebuilt | stale | unavailable
- source_requirement: <requirement summary>

### Search Queries
- <query text> → top hits: <N>
- ...

### Code Reading Summary
| File | Symbol | Why Read | Finding | Decision |
|---|---|---|---|---|
| <path> | <symbol or (file)> | <reason> | <finding> | modify \| add \| reuse \| reuse-pattern \| avoid \| read-only |

### Involved Modules
- <module> — <reason> — modify | add | read-only

### Entry Points
- <file:function> — <purpose> — caller count: <N>

### Existing Patterns
- <pattern name> — reference <file:function> — adopt | avoid

### Risk Boundary
- expected_changed_files: <integer>
- expected_changed_symbols: <integer>
- expected_affected_flows: <list or []>
- hub_nodes: <list or none>
- bridge_nodes: <list or none>

### Open Questions
- <human-answerable question, or "none">
```

**Validation rules (`check-crg-evidence.sh`):**

| Check | Requirement |
|---|---|
| `## CRG Discovery` present | required |
| All 7 subsections present | Discovery Metadata / Search Queries / Code Reading Summary / Involved Modules / Entry Points / Existing Patterns / Risk Boundary |
| Discovery Metadata 4 fields complete | all non-empty |
| `crg_graph_status` valid enum | `fresh\|rebuilt\|stale\|unavailable` |
| Code Reading Summary rows ≥ `config.thresholds.discoveryMinReadings` (default 2) | |
| All 5 columns (File/Symbol/Why Read/Finding/Decision) non-empty per row | |
| `Risk Boundary.expected_changed_files` is positive integer | |
| `Open Questions` section present (value may be "none") | |

### 6.2 `tasks.md#CRG Precision Plan` — produced by `/spcrg-plan`

```markdown
## CRG Precision Plan

### Mapping Metadata
- based_on_discovery: <timestamp from Discovery Metadata>
- generated_by: /spcrg-plan
- generated_at: <ISO 8601 UTC>

### Function-Level Change Map
| Task | Target | Current Behavior | Required Change | Tests | Reference Pattern | Risk |
|---|---|---|---|---|---|---|
| <id> | <file:symbol> | <text> | <text> | <test path or "none-with-justification"> | <file:symbol> | low \| medium \| high |

### Test Coverage Plan
| Changed Symbol | Existing Test | New Test Case | Verification Command |
|---|---|---|---|

### Phase Plan

#### Phase N: <name>
- expected_files: [...]
- expected_symbols: [...]
- required_tests: [...]
- verification_command: `<command>`
- crg_post_phase_checks: [<tool names to run in Post-Phase Verification>]
```

**Validation rules:**

| Check | Requirement |
|---|---|
| `## CRG Precision Plan` present | required |
| 4 subsections present | Mapping Metadata / Function-Level Change Map / Test Coverage Plan / Phase Plan |
| Change Map rows ≥ `config.thresholds.precisionPlanMinTasks` (default 1) | |
| All 7 columns non-empty per row | |
| Target column matches `^[^:\s]+:[^:\s]+$` regex | file:symbol |
| Risk column valid enum | `low\|medium\|high` |
| At least one `#### Phase <N>` subsection | |
| Each Phase has 5 fields | expected_files / expected_symbols / required_tests / verification_command / crg_post_phase_checks |

### 6.3 `tasks.md#CRG Post-Phase Verification: Phase N` — produced by `/spcrg-dev`

```markdown
### CRG Post-Phase Verification: Phase <N>

- generated_at: <ISO 8601 UTC>
- actual_changed_files: [...]
- expected_changed_files: [...]
- scope_drift_percent: <0-100 integer>
- changed_symbols: [...]
- tested_changed_symbols: [...]
- changed_symbol_test_coverage: <0-100 integer>
- affected_flows: [...]
- e2e_required: yes | no
- e2e_status: existing-coverage | planned | missing
- knowledge_gaps: [{severity: critical|medium, description: ...}, ...]
- surprising_connections: [...]
- verdict: PASS | BLOCKING | NEEDS_HUMAN_DECISION
- action_taken: <text>
```

**Validation rules:**

| Check | Requirement |
|---|---|
| One `### CRG Post-Phase Verification: Phase N` per completed phase | required |
| All 14 fields present | required |
| `scope_drift_percent` in 0-100 | integer |
| `changed_symbol_test_coverage` in 0-100 | integer |
| `verdict` valid enum | `PASS\|BLOCKING\|NEEDS_HUMAN_DECISION` |
| **Verdict consistency** | `scope_drift > config.thresholds.scopeDriftPercent` AND `verdict=PASS` → fail; `coverage < config.thresholds.changedSymbolTestCoveragePercent` AND `verdict=PASS` → fail; `knowledge_gaps` contains any `severity=critical` AND `verdict=PASS` → fail |
| BLOCKING or NEEDS_HUMAN_DECISION → `action_taken` non-empty | required |

### 6.4 `design.md#CRG Quantified Review` — produced by `/spcrg-review`

```markdown
## CRG Quantified Review

### Review Metadata
- generated_at: <ISO 8601 UTC>
- generated_by: /spcrg-review
- based_on_phases: [<list of phase numbers>]

### Scope Drift
- planned_files: <N>
- actual_files: <M>
- drift_percent: <0-100>
- verdict: PASS | BLOCKING | NEEDS_HUMAN_DECISION
- explanation: <required if not PASS>

### Changed Function Test Coverage
- changed_symbols: <N>
- tested_symbols: <M>
- coverage_percent: <0-100>
- threshold_percent: <from config>
- verdict: PASS | BLOCKING | NEEDS_HUMAN_DECISION
- explanation: <required if not PASS>

### Flow Impact
- affected_flows: [...]
- flows_with_e2e: [...]
- flows_missing_e2e: [...]
- verdict: PASS | BLOCKING | NEEDS_HUMAN_DECISION
- explanation: <required if not PASS>

### Knowledge Gaps
- critical: [...]
- medium: [...]
- verdict: PASS | BLOCKING | NEEDS_HUMAN_DECISION
- explanation: <required if not PASS>

### Final CRG Verdict
- archive_ready: yes | no
- blockers: [...]
- human_decisions_required: [...]
```

**Validation rules (`check-v5-review.sh`):**

| Check | Requirement |
|---|---|
| `## CRG Quantified Review` present | required |
| 5 subsections + Final Verdict | Review Metadata / Scope Drift / Changed Function Test Coverage / Flow Impact / Knowledge Gaps / Final CRG Verdict |
| Each subsection has `verdict` field | required |
| All verdict values valid enum | |
| Verdict consistency: `drift_percent > threshold` AND `verdict=PASS` → fail | |
| Verdict consistency: `coverage_percent < threshold` AND `verdict=PASS` → fail | |
| Verdict consistency: `flows_missing_e2e` non-empty AND `config.gates.requireE2EForAffectedFlows=true` AND `verdict=PASS` → fail | |
| Verdict consistency: `critical` non-empty AND `verdict=PASS` → fail | |
| Any verdict != PASS → `explanation` non-empty | required |
| `Final CRG Verdict.archive_ready` valid enum | `yes\|no` |
| `archive_ready=yes` → all subsection verdicts must be PASS | required |

---

## 7. Config and State schemas

### 7.1 `.ai-workflow-kit/config.json` (committed)

```json
{
  "version": "5",
  "commandPrefix": "spcrg",
  "thresholds": {
    "scopeDriftPercent": 20,
    "changedSymbolTestCoveragePercent": 80,
    "discoveryMinReadings": 2,
    "precisionPlanMinTasks": 1,
    "maxCallChainDepth": 2
  },
  "gates": {
    "requireE2EForAffectedFlows": true,
    "allowHumanOverride": true,
    "requireReviewBeforeArchive": true
  }
}
```

**Read strategy (all scripts):**

```bash
_read_config() {
  local key="$1" default="$2" config=".ai-workflow-kit/config.json"
  if [ ! -f "$config" ]; then echo "$default"; return; fi
  if command -v jq &>/dev/null; then
    jq -r "$key // empty" "$config" 2>/dev/null || echo "$default"
  elif command -v python3 &>/dev/null; then
    python3 -c "import json,sys; c=json.load(open('$config')); keys='$key'.lstrip('.').split('.'); v=c
for k in keys: v=v[k]
print(v)" 2>/dev/null || echo "$default"
  else
    echo "$default"
  fi
}
```

Callers pass the canonical default matching the committed config.json so the system degrades gracefully.

### 7.2 `.ai-workflow-kit/state/<change-id>.json` (gitignored)

```json
{
  "changeId": "<string>",
  "version": "5",
  "lastUpdatedAt": "<ISO 8601>",
  "lastSessionId": "<uuid>",
  "phases": {
    "start": {
      "status": "completed|in_progress|pending",
      "completedAt": "<ISO 8601 or null>",
      "sessionId": "<uuid>",
      "treeHash": "<sha256 short>"
    },
    "plan": {
      "status": "...",
      "completedAt": "...",
      "sessionId": "...",
      "treeHash": "...",
      "plannedPhases": <integer>
    },
    "dev": {
      "status": "...",
      "currentPhase": <integer>,
      "phaseHistory": [
        {
          "phaseNumber": <integer>,
          "completedAt": "...",
          "sessionId": "...",
          "treeHash": "...",
          "verdict": "PASS|BLOCKING|NEEDS_HUMAN_DECISION",
          "scopeDriftPercent": <integer>,
          "changedSymbolCoveragePercent": <integer>
        }
      ]
    },
    "review": { "status": "..." },
    "archive": { "status": "..." }
  }
}
```

**Session ID derivation:**

```bash
session_id="${AIWK_SESSION_ID:-$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$RANDOM$RANDOM$RANDOM")}"
export AIWK_SESSION_ID="$session_id"
```

Each fresh agent conversation generates a new session id because `AIWK_SESSION_ID` does not persist across sessions.

**Tree hash derivation:**

```bash
tree_hash=$(git ls-files --stage 2>/dev/null | sha256sum | cut -c1-16)
# Non-git repo fallback
[ -z "$tree_hash" ] && tree_hash="no-git"
```

**Dev Delta Check logic:**

```
state = read state file (null if missing)
current_session = $AIWK_SESSION_ID
current_tree = git ls-files --stage | sha256sum
last_phase = state?.phases.dev.phaseHistory[-1]

if state is null or last_phase is null:         → resumed → detect_changes
elif last_phase.sessionId != current_session:    → resumed → detect_changes
elif last_phase.treeHash != current_tree:        → tree changed → detect_changes
else:                                             → continuous → skip broad CRG pre-check
```

On "resumed", run `detect_changes`. If it reports files affecting the current task's `expected_files`, run `get_impact_radius`, read changed code, and decide whether Precision Plan must be updated before continuing.

On "continuous", read current task's target files directly and start TDD.

---

## 8. Script designs

### 8.1 `scripts/check-crg-evidence.sh` (upgraded)

**Scope:** Validate Discovery, Precision Plan, and Post-Phase Verification sections.
Does NOT validate Quantified Review (that's `check-v5-review.sh`'s job).

**Modes:**

- Default (strict): require Precision Plan. Used by `/spcrg-plan`, `/spcrg-dev`, `/spcrg-review`, `/spcrg-archive`, `/spcrg-audit` gates.
- `--shape-only` (via `AIWK_CHECK_CRG_MODE=shape-only`): only validate Discovery. Used by `/spcrg-start` end-gate.

**Flow:**

1. Argument validation + directory existence (reuse V1)
2. Read `config.json` → thresholds (discoveryMinReadings, precisionPlanMinTasks)
3. Validate `design.md`:
   - `## CRG Discovery` present
   - 7 subsections present
   - Discovery Metadata 4 fields non-empty
   - `crg_graph_status` valid enum
   - Code Reading Summary rows ≥ `discoveryMinReadings`
   - Each row has all 5 columns non-empty
   - `Risk Boundary.expected_changed_files` positive integer
   - `Open Questions` section present
4. Validate `tasks.md` (skipped in `--shape-only` mode):
   - `## CRG Precision Plan` present
   - 4 subsections present
   - Change Map rows ≥ `precisionPlanMinTasks`, 7 columns non-empty
   - `Target` column regex-matches `^[^:\s]+:[^:\s]+$`
   - `Risk` valid enum
   - ≥ 1 Phase subsection with 5 fields each
5. Validate each existing Post-Phase Verification:
   - 14 fields present, numeric fields in range, verdict valid enum
   - Verdict consistency check against thresholds
   - BLOCKING/NEEDS_HUMAN_DECISION → action_taken non-empty
6. Output machine-friendly: `CHECK: <description>   PASS|FAIL (<location>)`, then `SUMMARY: N checks, M passed, K failed`, exit non-zero on any FAIL.

### 8.2 `scripts/check-v5-review.sh` (new)

**Scope:** Quantified Review section + verdict consistency + archive_ready gate.

**Flow:**

1. Argument validation
2. Read `config.json` (scopeDriftPercent, changedSymbolTestCoveragePercent, requireE2EForAffectedFlows)
3. Locate `## CRG Quantified Review` in `openspec/changes/<id>/design.md` or `review.md` (either works)
4. Validate 5 subsections present
5. Each has `verdict` field with valid enum
6. Verdict consistency checks (Section 6.4)
7. Non-PASS → `explanation` non-empty
8. `Final CRG Verdict.archive_ready` valid enum
9. If `archive_ready=yes`, all subsection verdicts must be PASS
10. Same output format as 8.1

### 8.3 `scripts/check-command-protocols.sh` (new)

**Scope:** Verify installed `.claude/commands/*.md` contain V5 protocol keywords. Prevents installing stale V1 files.

**Keyword contract:**

```
spcrg-start.md      ⊇ { "CRG Discovery Protocol", "Read Before Decide", "## CRG Discovery" }
spcrg-plan.md       ⊇ { "CRG Precision Mapping Protocol", "superpowers:writing-plans", "## CRG Precision Plan" }
spcrg-dev.md        ⊇ { "Delta Check Protocol", "CRG Post-Phase Verification", "PASS | BLOCKING | NEEDS_HUMAN_DECISION" }
spcrg-review.md     ⊇ { "CRG Quantified Review", "scope_drift", "archive_ready" }
spcrg-archive.md    ⊇ { "check-v5-review.sh", "/opsx:verify" }
spcrg-audit.md      ⊇ { "structured evidence", "Code Reading Summary", "Precision Plan" }

For all of { plan, dev, review, archive, audit }: also contain { "check-openspec-gate.sh", "check-crg-evidence.sh" }.
```

Keywords are defined as a top-of-file bash associative array so future CRG renames only touch one place.

**Called by:** `verify-install.sh` step 5.

### 8.4 `scripts/verify-install.sh` (upgraded)

V1 has 4 checks. V5 adds a 5th:

```
[1/5] commands exist                          (V1)
[2/5] gate scripts exist and executable       (V1; add check-v5-review.sh to required list)
[3/5] commands embed gate script calls        (V1)
[4/5] spcrg-start.md runs gate after artifacts (V1)
[5/5] command files contain V5 protocol keywords  ← delegates to check-command-protocols.sh
```

### 8.5 `scripts/run-tests.sh` (new)

Runs every directory under `tests/fixtures/` as one test case.

**Convention:**

- `good-*` → expected exit 0
- `bad-*` → expected exit non-zero

**Flow per fixture:**

1. `tmp_root=$(mktemp -d)`
2. Copy fixture's `change/` tree into `$tmp_root/openspec/changes/<fixture-name>/`
3. Copy `tests/fixtures/config.json` into `$tmp_root/.ai-workflow-kit/config.json`
4. Infer target script from fixture name:
   - contains `discovery` / `precision-plan` / `post-phase` → `check-crg-evidence.sh`
   - contains `quantified-review` → `check-v5-review.sh`
5. Run target script with fixture name as change-id
6. Compare actual exit code to expectation
7. For `bad-*` cases, assert output contains the fail reason expected from the fixture name
8. Aggregate: report pass/fail counts; exit non-zero if any failure

### 8.6 Script invocation graph

```
verify-install.sh
  ├── check-openspec-gate.sh       (smoke)
  ├── check-crg-evidence.sh        (smoke)
  ├── check-v5-review.sh           (smoke)
  └── check-command-protocols.sh   (primary delegator)

spcrg-plan gate, spcrg-dev gate, spcrg-audit gate
  ├── check-openspec-gate.sh
  └── check-crg-evidence.sh (strict)

spcrg-review gate (first-time entry — Quantified Review does not yet exist)
  ├── check-openspec-gate.sh
  └── check-crg-evidence.sh (strict)

spcrg-review self-check (at end, before returning to user)
  └── check-v5-review.sh

spcrg-archive gate (Quantified Review MUST exist by now)
  ├── check-openspec-gate.sh
  ├── check-crg-evidence.sh (strict)
  └── check-v5-review.sh         ← gates archive entry

spcrg-start end-gate
  ├── check-openspec-gate.sh
  └── check-crg-evidence.sh --shape-only

run-tests.sh
  ├── check-crg-evidence.sh
  └── check-v5-review.sh
```

---

## 9. Command file rewrites

### 9.1 `/spcrg-start` (major rewrite)

Replaces V1's "Run CRG Context Pass (list tools) + write evidence" section with:

```markdown
## CRG Discovery Protocol

### Step 1: Graph readiness
- Build or update CRG graph if missing or stale (>7d since last build).
- Record freshness in Discovery Metadata.

### Step 2: Divergent search
- Run `semantic_search_nodes` with 2-4 requirement-derived queries.
- Run `list_communities` to understand module boundaries.
- Record each query and top-hit count.

### Step 3: Mandatory Code Reading
For the top N hits (N ≤ `config.thresholds.maxCallChainDepth * 4`):
1. Read the actual source file.
2. Read the key symbol implementation.
3. Use callers/callees to identify upstream/downstream.
4. Read the key caller/callee implementations.
5. Record entries in the Code Reading Summary table with all 5 columns filled.

### Step 4: Decision Synthesis
Derive:
- Involved Modules
- Entry Points (with caller count)
- Existing Patterns (with reference file:function)
- Risk Boundary (expected_changed_files/symbols/flows, hub_nodes, bridge_nodes)
- Whether this should be split into multiple OpenSpec changes

### Step 5: Targeted Risk Tools
Run only if signals warrant:
- `get_impact_radius` once targets are confirmed
- `get_hub_nodes` if architecture-sensitive
- `get_bridge_nodes` if cross-module
- `get_knowledge_gaps` if information is incomplete
- `get_surprising_connections` if unexpected dependencies emerge

### Step 6: Write Structured Discovery
Write `## CRG Discovery` into `design.md` per the V5 schema.
Proposal.md gets a short summary and risks; never raw tool output.
```

Plus the V1 brainstorming step (unchanged), optional CRG Recheck (unchanged), and the V5-locked end-gate:

```markdown
## V5 Mandatory Rule: Read Before Decide

After `semantic_search_nodes` or community discovery, you MUST read the
actual source files for the top relevant hits before deciding target
modules or writing implementation guidance.

For every file/symbol included in `## CRG Discovery`, record:
- why it was selected
- what code was read
- what was learned
- the resulting decision: modify | add | reuse | reuse-pattern | avoid | read-only

Do not write raw CRG output as evidence. Write decision evidence.
If the graph is unavailable or stale and cannot be rebuilt, STOP.
Do not fabricate a Discovery section.

## Gate: before requesting approval

scripts/check-openspec-gate.sh <change-id>
AIWK_CHECK_CRG_MODE=shape-only scripts/check-crg-evidence.sh <change-id>

On failure: identify missing sections/fields, repair using Discovery Protocol,
re-run scripts. Only when both pass, write state and request approval.

## State write
Write .ai-workflow-kit/state/<change-id>.json with phase=start, sessionId, treeHash, completedAt.
```

### 9.2 `/spcrg-plan` (major rewrite)

```markdown
## Gate: before planning
（check-openspec-gate + check-crg-evidence，V1 逻辑）

## CRG Precision Mapping Protocol

Do NOT repeat Start's broad discovery unless `design.md#CRG Discovery`
is missing or older than 7 days.

### Step 1: Inherit Discovery
Read `design.md#CRG Discovery`. Entry Points, Involved Modules, Risk
Boundary are starting state.

### Step 2: Expand via call graph
For each entry point:
- `query_graph callers/callees` (depth ≤ config.thresholds.maxCallChainDepth)
- Read actual code of every caller/callee flagged as modify candidate
- Record rows in Function-Level Change Map

### Step 3: Test coverage pass
For each symbol in the Change Map:
- `query_graph pattern="tests_for"`
- Read the existing test file
- Decide: extend | new file | explicit no-test-justification

### Step 4: Phase grouping
Group tasks into phases. Each phase:
- Touches ≤ 5 files
- Has a runnable verification_command
- Can complete Post-Phase Verification independently

### Step 5: Hand off to superpowers:writing-plans
Pass Precision Mapping output as input. Superpowers produces
TDD-structured tasks (red/green/refactor) with function-level context.

### Step 6: Write Evidence
Write `## CRG Precision Plan` into `tasks.md` per Section 6.2 schema.

## V5 Task Granularity Rule

Tasks MUST be written at file:function level.

BAD:  - [ ] Modify UserService
GOOD: - [ ] 1.2 Extend src/services/UserService.ts:searchUsers() to accept email filter
        - Current behavior: only filters by displayName
        - Required change: add optional email predicate; preserve pagination
        - Reference pattern: src/services/UserService.ts:findByName()
        - TDD: write failing test → red → minimal impl → green → refactor
        - Verification: pnpm test tests/services/UserService.test.ts
        - CRG evidence: design.md#CRG Discovery, tasks.md#CRG Precision Plan row 1.2

## State write
Write state phase=plan after approval.
```

### 9.3 `/spcrg-dev` (major rewrite)

```markdown
## Gate: before development
（check-openspec-gate + check-crg-evidence，V1 逻辑）

## Delta Check Protocol

Before each phase:
1. Generate/reuse $AIWK_SESSION_ID (uuidgen fallback).
2. Compute current_tree_hash.
3. Read state/<change-id>.json; get last = state.phases.dev.phaseHistory[-1].
4. Decide continuity (table in Section 7.2).
5. If continuous → read target files and start TDD.
   If resumed/changed → run detect_changes; on impact run impact_radius + read_changed_code + decide plan update.

## Execute phase via TDD
Use superpowers:subagent-driven-development + test-driven-development.
For each task: red → green → refactor. Update tasks.md task status.

## CRG Post-Phase Verification

After phase N completes:
- detect_changes
- get_impact_radius
- query_graph pattern="tests_for" for each changed symbol
- get_affected_flows
- get_knowledge_gaps (if config.gates.requireReviewBeforeArchive)

Compute: actual_changed_files, scope_drift_percent, changed_symbol coverage,
affected_flows, knowledge_gaps.

Write `### CRG Post-Phase Verification: Phase N` per Section 6.3 schema.

Verdict rules:
| Condition                                              | Verdict                 |
| scope_drift > threshold AND no explanation             | BLOCKING                |
| coverage < threshold                                   | BLOCKING                |
| critical knowledge_gaps                                | BLOCKING                |
| affected_flows need E2E but unavailable                | NEEDS_HUMAN_DECISION    |
| otherwise                                              | PASS                    |

Update state.phases.dev.phaseHistory with verdict + metrics.

## STOP conditions
- verdict == BLOCKING → STOP
- verdict == NEEDS_HUMAN_DECISION → STOP + ask user
- Plan-external files changed, no explanation → STOP
- CRG unavailable → STOP, do not fabricate evidence
```

### 9.4 `/spcrg-review` (major rewrite)

```markdown
## Gate: before review
check-openspec-gate + check-crg-evidence
(check-v5-review.sh is NOT in the entry gate — Quantified Review is this command's OUTPUT)

## Phase 1: OpenSpec Compliance Review
（V1 保留）

## Phase 2: CRG Quantified Review
Aggregate all Post-Phase Verifications:
- Scope Drift: Σ planned_files vs Σ actual_files
- Changed Function Test Coverage
- Flow Impact: union of affected_flows, E2E coverage
- Knowledge Gaps

Apply thresholds from config.json. Per Section 6.4 rules, each subsection verdict must be numeric-consistent.

Write `## CRG Quantified Review` into design.md (append) or review.md.

Final CRG Verdict:
- archive_ready = yes only if all subsection verdicts = PASS
- blockers and human_decisions_required lists populated

## Phase 3: Superpowers Code Review
（V1 保留）

## Self-check
Run: scripts/check-v5-review.sh <change-id>
If fail → repair the written section, then re-run before reporting.

## Output
Blocking issues, non-blocking, missing tests, CRG risk summary, archive_ready verdict.
```

### 9.5 `/spcrg-archive` (moderate change)

V1 already has "first-step gate + pre-/opsx:verify re-gate". V5 adds:

1. Opening gate includes `check-v5-review.sh` (hard requirement).
2. After gate, assert `archive_ready == yes` by reading Quantified Review.
3. Keep all V1 sequence (superpowers:verification-before-completion → tests/lint/etc. → CRG Archive Gate → /opsx:verify → /opsx:archive).
4. On successful archive, write state.phases.archive = completed.

### 9.6 `/spcrg-bugfix`, `/spcrg-hotfix`, `/spcrg-refactor` (minor changes)

Each adds one paragraph:

```markdown
## V5 Rule: Read Before Decide
Before writing a diagnosis or decision, read the actual source files for
the relevant CRG hits. Use CRG to locate; use source reading to decide.
```

Additionally:
- `/spcrg-hotfix`: if a hotfix OpenSpec record is created, archiving/release sign-off must pass the same V5 gates (`check-openspec-gate` + `check-crg-evidence` + `check-v5-review`).
- `/spcrg-refactor`: explicitly read source before AND after `refactor_tool` preview.

### 9.7 `/spcrg-audit` (major rewrite)

```markdown
# Spcrg CRG Evidence Audit (V5)

Change ID: $ARGUMENTS

## Parameter resolution
(V1 logic: if $ARGUMENTS empty, run detect-change-id.sh and ask.)

## Run structured checks (report-only)

1. scripts/check-openspec-gate.sh <change-id>
2. scripts/check-crg-evidence.sh <change-id>
3. scripts/check-v5-review.sh <change-id>   (skip if Quantified Review not yet produced)

Capture each CHECK result. Do NOT auto-repair unless the user explicitly asks.

## Manual structural audit (semantic checks scripts can't do)

- Discovery.Existing Patterns references must point to files that actually exist
- Precision Plan Reference Pattern column likewise
- Post-Phase Verifications exist for every phase listed as completed in state

## Report

| Section                                     | Exists | Schema Valid | Notes |
|---|---|---|---|
| ## CRG Discovery                            | ✓    | ✓           | ... |
| ## CRG Precision Plan                       | ✓    | ✗           | Phase 2 missing verification_command |
| Post-Phase Verification Phase 1             | ✓    | ✓           | verdict=PASS |
| Post-Phase Verification Phase 2             | ✗    | —           | Not generated |
| ## CRG Quantified Review                    | ✗    | —           | Review phase not run |

Blocker list + next-phase readiness judgement.
```

---

## 10. SKILL, CLAUDE, README, CHANGELOG updates

### 10.1 SKILL.md new sections

**V5 Core Principle**

```markdown
## V5 Core Principle

CRG tells where; read code decides what; CRG verifies after.

- CRG is a navigator + verifier, not an evidence collector.
- Every CRG hit MUST be paired with actual source reading before deciding.
- Evidence is structured decisions, not raw tool output.
- Later phases inherit earlier phases' evidence; do NOT re-search from scratch.
- Dev Pre-Phase uses Delta Check, not ritualistic re-queries.
- Verdicts are numeric-consistent; scripts enforce the shape, the agent enforces the thinking.
```

**Session & State** (full text in Section 7.2 of this spec; the SKILL gets a condensed version)

**Config** (full text in Section 7.1; SKILL gets a pointer with usage reminder)

**Updated Command Map** (per Section 8 of this spec): every row adds V5 Protocol and Produces Evidence columns.

### 10.2 CLAUDE.md updates

- Rules: add rules 9-12 matching the V5 Core Principle.
- Gate enforcement matrix: update archive row to include `check-v5-review`.
- Prerequisites: add "jq (recommended) or python3 for config parsing".
- Layout: replace V1 tree with V5 tree from Section 5.
- Daily usage: add "Reading V5 Evidence" subsection explaining state/config files.
- Success criteria: append V5-specific bullets (file:function tasks, per-phase verdicts, archive_ready gate, shape-vs-thinking separation).

### 10.3 README.md updates

- Tagline: add V5 one-liner ("CRG from evidence collector to code navigator + risk verifier").
- What's inside: update scripts list (5 gate/test scripts total).
- New "V5 Workflow at a glance" section: the 7-step arrow diagram.
- New "V5 vs V1" table: 5-row summary.
- Editing the kit: add `./scripts/run-tests.sh` step.

### 10.4 CHANGELOG.md (new)

```markdown
# Changelog

## [5.0.0] - 2026-04-28

### Breaking changes
- Evidence schema completely changed. V1 evidence does NOT pass V5 gates.
- New required directory `.ai-workflow-kit/` (config + state).

### Added
- CRG Discovery Protocol with mandatory Read Before Decide
- Precision Mapping Protocol for /spcrg-plan
- Delta Check Protocol for /spcrg-dev (state-based continuity)
- Post-Phase Verification with PASS|BLOCKING|NEEDS_HUMAN_DECISION verdicts
- Quantified Review with archive_ready gate
- .ai-workflow-kit/config.json for team-configurable thresholds
- .ai-workflow-kit/state/<change-id>.json for phase progression
- scripts/check-v5-review.sh, scripts/check-command-protocols.sh
- scripts/run-tests.sh + tests/fixtures/

### Changed
- scripts/check-crg-evidence.sh upgraded from grep-based to structured schema validation
- All 9 spcrg-* commands updated to V5 protocols

### Removed
- V1-style "just list CRG tool names" evidence pattern

## [1.0.0] - 2026-04-27
- Initial spcrg-prefixed AI Workflow Kit
```

---

## 11. Installer behavior

**`build-installer.sh` changes:**
1. emit loop includes new gate/verify scripts: `check-v5-review.sh`, `check-command-protocols.sh`.
2. emit `.ai-workflow-kit/config.json` as a new resource.
3. Does NOT emit `tests/fixtures/` (framework-dev only), `scripts/run-tests.sh` (depends on fixtures, framework-dev only), or `.ai-workflow-kit/state/` (runtime).

In short: fixture tests and their runner live in this repo for framework developers; they are not shipped to downstream projects.

**`install-ai-workflow-kit.sh` (regenerated) changes:**
1. Same file writes as V1, plus new scripts.
2. New section for `.ai-workflow-kit/config.json`:
   ```bash
   if [ ! -f .ai-workflow-kit/config.json ]; then
     mkdir -p .ai-workflow-kit
     cat > .ai-workflow-kit/config.json <<'EOF'
     { ... default config ... }
     EOF
     echo "Created default .ai-workflow-kit/config.json"
   else
     echo "Keeping existing .ai-workflow-kit/config.json"
   fi
   ```
3. Self-verify step at the end remains; `verify-install.sh` now has 5 checks.

---

## 12. Fixture test matrix

14 fixtures under `tests/fixtures/`:

| Fixture | Target script | Expected exit | Reason/failure mode |
|---|---|---|---|
| `good-discovery-minimal` | check-crg-evidence.sh --shape-only | 0 | Valid Discovery, no Precision Plan required |
| `good-precision-plan` | check-crg-evidence.sh | 0 | Full Discovery + Precision Plan |
| `good-post-phase-pass` | check-crg-evidence.sh | 0 | Phase 1 Post-Phase with verdict=PASS and consistent numbers |
| `good-quantified-review-archive-ready` | check-v5-review.sh | 0 | All PASS + archive_ready=yes |
| `bad-missing-discovery` | check-crg-evidence.sh | non-0 | `## CRG Discovery` missing |
| `bad-discovery-one-row` | check-crg-evidence.sh | non-0 | Code Reading Summary only 1 row, below minimum |
| `bad-discovery-empty-col` | check-crg-evidence.sh | non-0 | A row's `Decision` column is empty |
| `bad-precision-plan-no-phase` | check-crg-evidence.sh | non-0 | Precision Plan has no `#### Phase N` subsection |
| `bad-precision-plan-bad-target` | check-crg-evidence.sh | non-0 | `Target` column not `file:symbol` format |
| `bad-post-phase-verdict-inconsistent` | check-crg-evidence.sh | non-0 | coverage=60% but verdict=PASS |
| `bad-post-phase-missing-field` | check-crg-evidence.sh | non-0 | `scope_drift_percent` field missing |
| `bad-quantified-review-archive-yes-with-blocker` | check-v5-review.sh | non-0 | archive_ready=yes but a subsection verdict=BLOCKING |
| `bad-quantified-review-drift-over-threshold` | check-v5-review.sh | non-0 | drift_percent=25 > 20 but Scope Drift verdict=PASS |
| `config.json` | — | — | Shared test config |

Each bad fixture's name encodes the expected failure reason; `run-tests.sh` greps for a corresponding substring in script output to confirm the right failure path was taken.

---

## 13. Implementation batching (top-down by layer)

### Batch 1 — Protocol layer (9 commands + SKILL)
- [ ] Rewrite spcrg-start.md (Discovery Protocol)
- [ ] Rewrite spcrg-plan.md (Precision Mapping + superpowers:writing-plans)
- [ ] Rewrite spcrg-dev.md (Delta Check + Post-Phase Verification)
- [ ] Rewrite spcrg-review.md (Quantified Review)
- [ ] Modify spcrg-archive.md (add check-v5-review + archive_ready assert + state)
- [ ] Minor updates to spcrg-bugfix/hotfix/refactor (Read Before Decide)
- [ ] Rewrite spcrg-audit.md (structured evidence audit)
- [ ] Update SKILL.md (V5 Core Principle, Session/State, Config, Command Map)

### Batch 2 — Script layer (5 scripts + config + fixtures)
- [ ] Create `.ai-workflow-kit/config.json` (committed default)
- [ ] Add `.ai-workflow-kit/state/` to `.gitignore`
- [ ] Upgrade check-crg-evidence.sh (structured schema + --shape-only mode)
- [ ] Add check-v5-review.sh
- [ ] Add check-command-protocols.sh
- [ ] Upgrade verify-install.sh (add step 5)
- [ ] Create tests/fixtures/ (14 fixtures + shared config.json)
- [ ] Add scripts/run-tests.sh

### Batch 3 — Packaging & docs
- [ ] Update build-installer.sh (include new scripts + conditional config)
- [ ] Regenerate install-ai-workflow-kit.sh
- [ ] Update CLAUDE.md (rules, matrix, prerequisites, layout, success criteria)
- [ ] Update README.md (tagline, workflow diagram, V5 vs V1, editing)
- [ ] Create CHANGELOG.md
- [ ] Optional: `.github/workflows/verify.yml` (CI runs verify-install + run-tests)

### Acceptance gate
```bash
./scripts/build-installer.sh      # regenerate installer
./scripts/verify-install.sh .     # all 5 checks pass
./scripts/run-tests.sh            # 14 fixtures all pass
```

Green on all three = V5 delivery complete. Phase 4 (real-project dry run) is user-driven and out of scope.

---

## 14. Risks and open issues

- **Markdown parsing fragility.** Scripts use grep/awk to extract fields and table rows. Table whitespace, markdown variants, and surrounding prose can confuse parsers. Mitigation: fixture coverage of common variations; parsers stay conservative (strict regex with clear failure messages).
- **CRG tool name drift.** `check-command-protocols.sh` checks literal keywords (e.g., `semantic_search_nodes`). If CRG renames tools, both commands and the script need updates. Mitigation: keyword table in one place at the top of the script.
- **Session ID fallback.** `uuidgen`/`date` both missing is extremely rare but possible. Fallback to `$RANDOM$RANDOM$RANDOM`; accuracy degrades gracefully.
- **Non-git repositories.** `git ls-files` fails; `treeHash=no-git` causes Delta Check to rely only on sessionId. Acceptable degradation.
- **Config read precedence.** jq preferred, python3 fallback, hardcoded default last resort. Document this in SKILL so team members understand why thresholds might differ across machines.
- **Agent lying past the verdict gate.** The numeric consistency check only catches contradictions the agent explicitly wrote. An agent could under-report `actual_changed_files` to keep drift low. This is a trust boundary the spec explicitly does not close — `/spcrg-audit`'s semantic section is the human-driven compensation.

---

## 15. Non-goals (explicit out-of-scope)

- Phase 4 (real-project dry run on a small feature) — user-driven validation after delivery.
- V1 legacy evidence compatibility mode.
- `/feature-*` aliases for `/spcrg-*`.
- Scope drift auto-calculation by scripts (kept as agent-written numbers with script-side consistency checks).
- Migration tool to upgrade V1 evidence in-place.
- Pluggable gate script framework (current 5-script count is fixed).

---

## 16. Success criteria

After V5 delivery:

1. `verify-install.sh` reports 5/5 checks green.
2. `run-tests.sh` reports 14/14 fixtures passing.
3. Installer, run in a fresh temp project, produces a layout whose `verify-install.sh .` is green.
4. Every `/spcrg-*` command contains the V5 protocol keywords required by `check-command-protocols.sh`.
5. Attempting `/spcrg-plan` on a change that only has V1 evidence correctly fails the gate, with a specific missing-section message.
6. `check-v5-review.sh` correctly fails a review where `drift_percent > 20` but `verdict=PASS`.
7. A Dev session can be resumed across agent restarts, and the Delta Check detects the session change.

---

## References

- Feishu design doc: `https://q7w8vltyes.feishu.cn/docx/VxJWdq1gvoehA4xbDdOcwCHpnBd`
- V1 implementation: commit `c397fa4` on `main`
- Original AI Workflow Kit doc: `https://q7w8vltyes.feishu.cn/docx/Xq3rdFtzwoKEs2xYXEjcvmCJnwb`
