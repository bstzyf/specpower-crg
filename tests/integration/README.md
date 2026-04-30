# Integration Tests

Real Claude Code CLI integration tests for the spcrg framework.
These tests invoke actual `claude -p` instances against controlled OpenSpec states
and verify command behavior, skill invocation, and output semantics.

## Requirements
- `claude` CLI (v2.0+) in PATH
- OpenSpec CLI initialized project
- code-review-graph built

## How to run

The tests assume a test project at `/tmp/spcrg-loop-test` with the framework
installed and an `add-search` change configured. To rebuild the test project:

```bash
# From framework root:
mkdir -p /tmp/spcrg-loop-test
cd /tmp/spcrg-loop-test
git init
# ... create baseline Node.js project ...
bash /path/to/specpower-crg/scripts/install-ai-workflow-kit.sh
openspec init
code-review-graph build
# ... create add-search OpenSpec artifacts ...
cp /path/to/specpower-crg/tests/integration/real-integration-tests.sh .
cp /path/to/specpower-crg/tests/integration/run-loop-tests.sh .
./real-integration-tests.sh
```

## Test Categories

- **G1-G3**: Gate/refusal behavior (missing Precision Plan, missing Discovery, archive_ready=no)
- **S1-S3**: State detection (empty → Stage A; tasks done no PPV → Stage B/C/D/E; complete → Stage G/H)
- **K1-K5**: Skill invocation (TDD, subagent-driven-dev, systematic-debugging, requesting-code-review, verification-before-completion)
- **O1-O3**: Output/side-effects (max-iterations=10, completion-promise=ARCHIVE_READY, PPV schema 14 fields)
- **E1-E3**: Error recovery (invalid change-id, empty arg, NEEDS_HUMAN_DECISION)

## Current status: 17/17 passing
