# Design: Add User Search

## CRG Discovery

### Discovery Metadata
- generated_at: 2026-04-28T01:00:00Z
- generated_by: /spcrg-start
- crg_graph_status: fresh
- source_requirement: Add user search with email and name filters

### Search Queries
- "user search" → top hits: 8
- "email filter" → top hits: 3

### Code Reading Summary
| File | Symbol | Why Read | Finding | Decision |
|---|---|---|---|---|
| src/services/UserService.ts | searchUsers | semantic top hit | Only supports name filter | modify |
| src/services/UserService.ts | findByName | callers reference | Shows pagination pattern | reuse-pattern |
| tests/services/UserService.test.ts | (file) | tests_for searchUsers | 3 existing cases for name | extend |

### Involved Modules
- services/user — main search logic — modify
- components/UserList — display layer — add

### Entry Points
- src/services/UserService.ts:searchUsers — API entry — caller count: 7

### Existing Patterns
- pagination via cursor — reference src/services/UserService.ts:findByName — adopt

### Risk Boundary
- expected_changed_files: 4
- expected_changed_symbols: 6
- expected_affected_flows: [UserListFlow]
- hub_nodes: none
- bridge_nodes: [src/services/UserService.ts]

### Open Questions
- none

## CRG Quantified Review

### Review Metadata
- generated_at: 2026-04-28T03:00:00Z
- generated_by: /spcrg-review
- based_on_phases: [1]

### Scope Drift
- planned_files: 4
- actual_files: 4
- drift_percent: 0
- verdict: PASS

### Changed Function Test Coverage
- changed_symbols: 6
- tested_symbols: 6
- coverage_percent: 100
- threshold_percent: 80
- verdict: PASS

### Flow Impact
- affected_flows: [UserListFlow]
- flows_with_e2e: [UserListFlow]
- flows_missing_e2e: []
- verdict: PASS

### Knowledge Gaps
- critical: []
- medium: []
- verdict: PASS

### Final CRG Verdict
- archive_ready: yes
- blockers: []
- human_decisions_required: []
