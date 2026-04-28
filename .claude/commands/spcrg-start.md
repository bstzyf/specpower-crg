# Spcrg Start: OpenSpec OPSX + CRG Discovery Protocol

User input:

$ARGUMENTS

Start a new feature or significant change using the mandatory V5 project workflow.

## Parameter resolution

If `$ARGUMENTS` is empty, proceed — this command always creates a new change. The change-id will be assigned by `/opsx:propose`.

## Step 1: Create OpenSpec artifacts

Run:

```
/opsx:propose $ARGUMENTS
```

Do not implement code. After the proposal is created, identify the change-id and verify these files exist:

- `openspec/changes/<change-id>/proposal.md`
- `openspec/changes/<change-id>/design.md`
- `openspec/changes/<change-id>/specs/**`
- `openspec/changes/<change-id>/tasks.md`

## CRG Discovery Protocol

### Step 1: Graph readiness

- Build or update the CRG graph if it is missing or stale (more than 7 days since last build).
- Use `build_or_update_graph` if needed.
- Record graph freshness in Discovery Metadata as one of: `fresh | rebuilt | stale | unavailable`.

### Step 2: Divergent search

- Run `semantic_search_nodes` with 2–4 requirement-derived queries covering different aspects of the change.
- Run `list_communities` to understand module boundaries.
- Record each query and the count of top hits.

### Step 3: Mandatory Code Reading

For the top N hits (N ≤ `config.thresholds.maxCallChainDepth * 4`, default 8):

1. Read the actual source file containing the hit.
2. Read the key symbol implementation.
3. Use `query_graph callers/callees` to identify upstream and downstream code.
4. Read the key caller and callee implementations.
5. Record every file/symbol examined in the Code Reading Summary table with all 5 columns filled:
   - File, Symbol, Why Read, Finding, Decision.

Do not skip this step. Do not write raw CRG output. Write decision evidence.

### Step 4: Decision Synthesis

From the code you read, derive:

- **Involved Modules** — which modules are touched and whether they are modify / add / read-only
- **Entry Points** — key file:function pairs with caller counts
- **Existing Patterns** — patterns to adopt or avoid, each with a reference file:function
- **Risk Boundary** — expected_changed_files, expected_changed_symbols, expected_affected_flows, hub_nodes, bridge_nodes
- **Split decision** — whether this requirement should become multiple OpenSpec changes

### Step 5: Targeted Risk Tools

Run only when signals warrant:

- `get_impact_radius` once target files are confirmed
- `get_hub_nodes` if the change is architecture-sensitive
- `get_bridge_nodes` if the change crosses module boundaries
- `get_knowledge_gaps` if information is incomplete
- `get_surprising_connections` if unexpected dependencies appear

### Step 6: Write Structured Discovery

Write `## CRG Discovery` into `design.md` following the V5 schema exactly:

```
## CRG Discovery

### Discovery Metadata
- generated_at: <ISO 8601 UTC>
- generated_by: /spcrg-start
- crg_graph_status: fresh | rebuilt | stale | unavailable
- source_requirement: <requirement summary>

### Search Queries
- <query text> → top hits: <N>

### Code Reading Summary
| File | Symbol | Why Read | Finding | Decision |
|---|---|---|---|---|
| <path> | <symbol or (file)> | <reason> | <finding> | modify | add | reuse | reuse-pattern | avoid | read-only |

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

Write a short CRG Risk Summary into `proposal.md`. Never paste raw CRG tool output into any OpenSpec file.

## V5 Mandatory Rule: Read Before Decide

After `semantic_search_nodes` or community discovery, you MUST read the actual source files for the top relevant hits before deciding target modules or writing implementation guidance.

For every file/symbol included in `## CRG Discovery`, record:

- why it was selected
- what code was read
- what was learned
- the resulting decision: `modify | add | reuse | reuse-pattern | avoid | read-only`

Do not write raw CRG output as evidence. Write decision evidence.

If the graph is unavailable or stale and cannot be rebuilt, STOP. Do not fabricate a Discovery section.

## Brainstorming

Use `superpowers:brainstorming` with these inputs:

- `proposal.md`
- `design.md` (including `## CRG Discovery`)
- `specs/**`
- `tasks.md`

Brainstorming must clarify:

- requirement boundaries
- technical approach
- scope / out of scope
- measurable success criteria
- feature flag / migration / compatibility needs
- testing and E2E strategy
- CRG-discovered risks
- whether this should be split into multiple OpenSpec changes

After brainstorming, update `proposal.md`, `design.md`, `specs/**`, and `tasks.md`.

## Optional CRG Recheck

If brainstorming changes target modules, API boundaries, data models, permissions, testing strategy, E2E scope, or the task split decision, run a targeted CRG Recheck:

- `semantic_search_nodes` on the newly identified areas
- `query_graph callers/callees/imports/tests_for` for new entry points
- `get_impact_radius` if the scope changed
- `list_communities` / `get_community` if target modules changed
- `get_hub_nodes` / `get_bridge_nodes` / `get_surprising_connections` / `get_knowledge_gaps` for architecture or cross-module changes

Update `## CRG Discovery` if the recheck produced materially different findings.

## Gate: before requesting approval

After all artifacts, CRG Discovery, brainstorming, and optional recheck are complete, run:

```
scripts/check-openspec-gate.sh <change-id>
AIWK_CHECK_CRG_MODE=shape-only scripts/check-crg-evidence.sh <change-id>
```

On failure:

1. Do not tell the user you are "waiting for approval".
2. Do not implement code.
3. Identify the missing sections or fields.
4. Repair the missing content using the Discovery Protocol — do not expand scope.
5. Re-run both scripts.
6. Only when both pass, continue.

## State write

After both gate scripts pass, write `.ai-workflow-kit/state/<change-id>.json` with:

```json
{
  "changeId": "<change-id>",
  "version": "5",
  "lastUpdatedAt": "<ISO 8601 UTC>",
  "lastSessionId": "<AIWK_SESSION_ID>",
  "phases": {
    "start": {
      "status": "completed",
      "completedAt": "<ISO 8601 UTC>",
      "sessionId": "<AIWK_SESSION_ID>",
      "treeHash": "<git ls-files --stage | sha256sum | cut -c1-16>"
    }
  }
}
```

Then stop and ask for human approval. Do not implement code.

## Stop conditions

- CRG unavailable, stale, and cannot be rebuilt → STOP immediately. Do not fabricate a Discovery section.
- OpenSpec gate or CRG evidence gate fails repeatedly and cannot be repaired → STOP and report the specific failure.
- Brainstorming determines this requirement is too broad → STOP and recommend splitting into multiple `/spcrg-start` invocations.
