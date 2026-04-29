# /spcrg-loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `/spcrg-loop` command that leverages Ralph Loop plugin for iterative development, replacing manual dev+review with an automated loop.

**Architecture:** New command file `.claude/commands/spcrg-loop.md` containing gate logic + navigator prompt; config update for loop defaults; script updates for installation verification; installer rebuild.

**Tech Stack:** Bash (gate scripts), Markdown (command file), JSON (config), Ralph Loop plugin (`/ralph-loop` command)

---

## Task 1: Create the command file

**Files:**
- Create: `.claude/commands/spcrg-loop.md`

- [ ] **Step 1: Write the command file**

```markdown
# Spcrg Loop: Ralph-Driven Iterative Development

Change ID:

$ARGUMENTS

Start a Ralph Loop that iteratively implements, tests, and verifies the planned work until archive-ready.

## Resolve change-id if missing

If `$ARGUMENTS` is empty:

1. Run `scripts/detect-change-id.sh`.
2. If exactly one active change exists, report it and ask the user to confirm before using it.
3. If multiple active changes exist, list them and ask the user to pick one.
4. If none exist, tell the user to run `/spcrg-start <description>` first, then stop.

Do not proceed until a concrete change-id is chosen.

## Gate: before loop

Before starting the loop, run:

```
scripts/check-openspec-gate.sh $ARGUMENTS
scripts/check-crg-evidence.sh $ARGUMENTS
```

If either command fails:

1. Do not start the Ralph Loop.
2. Report missing OpenSpec artifacts or CRG Evidence sections.
3. Fix missing evidence only if it can be produced safely from existing context.
4. Re-run both scripts.
5. Continue only after both pass.

## Verify Precision Plan exists

Read `openspec/changes/$ARGUMENTS/tasks.md` and confirm `## CRG Precision Plan` section exists with at least one Phase in the Phase Plan.

If missing: tell the user to run `/spcrg-plan $ARGUMENTS` first, then stop.

## Read loop configuration

Read `.ai-workflow-kit/config.json` for:
- `loop.maxIterations` (default: 10)
- `loop.completionPromise` (default: "ARCHIVE_READY")

## Start Ralph Loop

Invoke:

```
/ralph-loop "<navigator-prompt below>" --max-iterations <maxIterations> --completion-promise "<completionPromise>"
```

### Navigator Prompt

你正在执行 openspec/changes/$ARGUMENTS/ 下的开发计划。
这是一个 Ralph Loop 迭代——你每轮看到的文件状态就是上一轮你自己的工作成果。
按照下面的决策树判断当前该做什么。

---

#### 决策树（每轮从顶部开始判断）

##### 阶段 A：实现未完成的 Task

读 openspec/changes/$ARGUMENTS/tasks.md，检查 `- [ ]` 项。

如果存在未完成的 task：
1. 定位当前 phase（Phase Plan 中第一个含有未完成 task 的 phase）
2. 读该 phase 的 expected_files 和 expected_symbols
3. 对该 phase 内的每个未完成 task：
   - 使用 `superpowers:test-driven-development`：
     - RED：写一个精确描述 Required Change 的失败测试
     - GREEN：写最小实现让测试通过
     - REFACTOR：改进代码结构，确认测试仍通过
   - 多个独立 task 之间使用 `superpowers:subagent-driven-development` 并行执行
4. 每个 task 实现后标记 `- [x]`
5. 结束本轮（下一轮进入阶段 B）

如果所有 task 已 `[x]` → 跳到阶段 B

##### 阶段 B：验证测试全部通过

运行当前 phase 的 verification_command（从 Phase Plan 读取）。

如果有测试失败：
1. 使用 `superpowers:systematic-debugging`：
   - 提出假设
   - 收集证据（错误日志、堆栈、相关代码）
   - 验证假设
   - 修复根因
2. 重新运行 verification_command
3. 仍然失败 → 继续调试（本轮专注于修复）
4. 全部通过 → 结束本轮（下一轮进入阶段 C）

如果测试全部通过 → 跳到阶段 C

##### 阶段 C：确保测试覆盖率和 E2E 达标

检查：
- changed_symbol_test_coverage ≥ 80%（对照 Phase Plan 中的 changed_symbols 列表）
- affected_flows 是否有 E2E 覆盖

如果 coverage 不足：
1. 对未覆盖的 symbol，使用 `superpowers:test-driven-development` 补充单测
2. 重新计算 coverage

如果 E2E 缺失：
1. 根据 affected_flows 设计真实场景的 E2E 用例
2. 模拟真实环境（真实数据库/API 调用，不用 mock 替代核心路径）
3. 实现并运行 E2E 测试
4. 验证 E2E 通过

全部达标 → 结束本轮（下一轮进入阶段 D）

##### 阶段 D：写 Post-Phase Verification

检查 tasks.md 中是否已有当前 phase 的 `### CRG Post-Phase Verification: Phase N`。

如果未写：
1. 运行 CRG 工具：detect_changes, get_impact_radius, query_graph tests_for, get_affected_flows, get_knowledge_gaps
2. 计算 scope_drift_percent, changed_symbol_test_coverage
3. 严格按 V5 schema 写入 tasks.md（14 个必填字段）
4. 按 verdict 规则判定：
   - scope_drift > 阈值 且无解释 → BLOCKING
   - coverage < 阈值 → BLOCKING
   - critical knowledge_gaps → BLOCKING
   - 否则 → PASS
5. 结束本轮

如果已写：
- verdict = PASS → 跳到阶段 E
- verdict = BLOCKING → 回到阶段 B/C 修复对应问题，修复后删除旧的 Verification 重写
- verdict = NEEDS_HUMAN_DECISION → 标记原因，跳过该 phase，跳到阶段 E

##### 阶段 E：检查是否所有 Phase 完成

读 tasks.md 的 Phase Plan，检查是否每个 phase 都有 verdict=PASS 的 Post-Phase Verification。

如果有 phase 未完成 → 回到阶段 A（针对下一个 phase）

如果所有 phase 完成 → 跳到阶段 F

##### 阶段 F：Code Review + CRG Quantified Review

1. 使用 `superpowers:requesting-code-review` 自查：
   - TDD 合规性
   - 最小实现（无投机性代码）
   - DRY（无重复逻辑）
   - 函数简短聚焦
   - 发现问题 → 修复后重新验证（回到阶段 B）

2. 如果 code review 通过，写 CRG Quantified Review：
   - 聚合所有 phase 的 Post-Phase Verification 数据
   - 计算 aggregate scope_drift, coverage, affected_flows, knowledge_gaps
   - 每个子章节给出 verdict（PASS / BLOCKING / NEEDS_HUMAN_DECISION）
   - 计算 Final CRG Verdict: archive_ready = yes/no
   - 写入 design.md 的 `## CRG Quantified Review`

3. 结束本轮（下一轮进入阶段 G）

##### 阶段 G：自检通过

运行 scripts/check-v5-review.sh $ARGUMENTS。

如果失败：
- 读失败信息
- 修复 Quantified Review 中的数值矛盾/缺失字段
- 重新运行直到通过
- 结束本轮

如果通过 → 跳到阶段 H

##### 阶段 H：完成判定

使用 `superpowers:verification-before-completion` 做最终确认：
- 运行完整测试套件
- 确认 lint/typecheck/build 通过
- 确认所有 tasks [x]
- 确认 archive_ready = yes

全部确认 → 输出：
<promise>ARCHIVE_READY</promise>

如果 archive_ready = no 且有 BLOCKING → 回到对应阶段修复
如果 archive_ready = no 且仅有 NEEDS_HUMAN_DECISION → 输出：
<promise>ARCHIVE_READY</promise>
并在最终报告中列出需要人工决策的项目。

---

#### 不可违反的规则

1. 不扩展 tasks.md 中未列出的范围
2. 不修改 expected_files 之外的文件（除非 E2E 或 config 需要）
3. E2E 必须模拟真实环境，核心路径不允许用 mock
4. 每个 verdict 必须和数值一致（drift>阈值 不能写 PASS）
5. 遇到不可自修复的问题：标记 NEEDS_HUMAN_DECISION，跳过继续其他工作
6. 不伪造测试结果或 CRG 证据

## Post-loop validation

After the Ralph Loop ends (either via promise or max-iterations):

1. Run `scripts/check-v5-review.sh $ARGUMENTS` to confirm evidence integrity.
2. If it fails and the loop exited via max-iterations, report the incomplete state.

## State write

Update `.ai-workflow-kit/state/$ARGUMENTS.json`:

```json
{
  "phases": {
    "loop": {
      "status": "completed",
      "completedAt": "<ISO 8601 UTC>",
      "mode": "ralph-loop",
      "iterations": "<actual count>",
      "maxIterations": "<from config>",
      "archive_ready": "<true|false>",
      "skipped_tasks": [],
      "human_decisions_required": []
    }
  }
}
```

## Report

Output:
- Total iterations used
- Tasks completed vs skipped
- Post-Phase Verification verdicts
- archive_ready status
- Human decisions required (if any)
- Next step: `/spcrg-archive $ARGUMENTS` if archive_ready=yes

## Stop conditions

- Gate scripts fail and cannot be repaired → STOP before loop
- Precision Plan missing → STOP, recommend `/spcrg-plan` first
- Ralph Loop exhausts max-iterations → STOP, report partial progress
- CRG unavailable → STOP, do not fabricate evidence
```

- [ ] **Step 2: Verify the file was created correctly**

Run: `head -5 .claude/commands/spcrg-loop.md`
Expected: Shows the title and $ARGUMENTS line

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/spcrg-loop.md
git commit -m "feat: add /spcrg-loop command file"
```

---

## Task 2: Update config.json with loop defaults

**Files:**
- Modify: `.ai-workflow-kit/config.json`

- [ ] **Step 1: Add loop configuration**

Update `.ai-workflow-kit/config.json` to:

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
  },
  "loop": {
    "maxIterations": 10,
    "completionPromise": "ARCHIVE_READY"
  }
}
```

- [ ] **Step 2: Verify JSON is valid**

Run: `jq . .ai-workflow-kit/config.json`
Expected: Pretty-printed valid JSON with the `loop` key present

- [ ] **Step 3: Commit**

```bash
git add .ai-workflow-kit/config.json
git commit -m "feat: add loop configuration defaults to config.json"
```

---

## Task 3: Update verify-install.sh to include new command

**Files:**
- Modify: `scripts/verify-install.sh`

- [ ] **Step 1: Add spcrg-loop.md to the required_commands array**

In the `required_commands` array (after `spcrg-audit.md`), add:

```bash
  .claude/commands/spcrg-loop.md
```

Also update the comment in section [1/5] — change "(9 slash commands)" references if present to "(10 slash commands)".

- [ ] **Step 2: Verify the script still passes**

Run: `scripts/verify-install.sh .`
Expected: All checks pass (including the new command file check)

- [ ] **Step 3: Commit**

```bash
git add scripts/verify-install.sh
git commit -m "feat: add spcrg-loop to install verification"
```

---

## Task 4: Update check-command-protocols.sh to validate new command

**Files:**
- Modify: `scripts/check-command-protocols.sh`

- [ ] **Step 1: Add protocol checks for spcrg-loop.md**

After the spcrg-audit.md section, add:

```bash
# ---------------------------------------------------------------------------
# spcrg-loop.md
# ---------------------------------------------------------------------------
f="$cmd_dir/spcrg-loop.md"
check "$f" "Ralph Loop"              "spcrg-loop contains 'Ralph Loop'"
check "$f" "Navigator Prompt"        "spcrg-loop contains 'Navigator Prompt'"
check "$f" "ARCHIVE_READY"           "spcrg-loop contains 'ARCHIVE_READY'"
```

Also add `spcrg-loop` to the `gated_files` and `gated_names` arrays so it validates embedded gate script calls:

```bash
gated_files=(
  "$cmd_dir/spcrg-plan.md"
  "$cmd_dir/spcrg-dev.md"
  "$cmd_dir/spcrg-review.md"
  "$cmd_dir/spcrg-archive.md"
  "$cmd_dir/spcrg-audit.md"
  "$cmd_dir/spcrg-loop.md"
)
gated_names=(
  "spcrg-plan"
  "spcrg-dev"
  "spcrg-review"
  "spcrg-archive"
  "spcrg-audit"
  "spcrg-loop"
)
```

- [ ] **Step 2: Run the protocol check script**

Run: `scripts/check-command-protocols.sh .claude/commands`
Expected: All checks PASS including the new spcrg-loop checks

- [ ] **Step 3: Commit**

```bash
git add scripts/check-command-protocols.sh
git commit -m "feat: add spcrg-loop protocol validation"
```

---

## Task 5: Update build-installer.sh to include new command

**Files:**
- Modify: `scripts/build-installer.sh`

- [ ] **Step 1: Add spcrg-loop to the command list**

In the `for cmd in` loop, add `spcrg-loop`:

```bash
for cmd in \
  spcrg-start spcrg-plan spcrg-dev spcrg-review spcrg-archive \
  spcrg-bugfix spcrg-hotfix spcrg-refactor spcrg-audit spcrg-loop
do
```

Also update the header comment from "(9 slash commands)" to "(10 slash commands)".

- [ ] **Step 2: Rebuild the installer**

Run: `scripts/build-installer.sh`
Expected: Output shows "Wrote scripts/install-ai-workflow-kit.sh (N lines)"

- [ ] **Step 3: Verify spcrg-loop is in the generated installer**

Run: `grep -c "spcrg-loop" scripts/install-ai-workflow-kit.sh`
Expected: At least 2 matches (the file emit and its content)

- [ ] **Step 4: Commit**

```bash
git add scripts/build-installer.sh scripts/install-ai-workflow-kit.sh
git commit -m "feat: include spcrg-loop in installer"
```

---

## Task 6: Update CLAUDE.md to document new command

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add /spcrg-loop to the command list**

In the command list near the top, add after `/spcrg-dev`:

```markdown
- `/spcrg-loop <change-id>`
```

- [ ] **Step 2: Add to Daily usage section**

In the "New feature" example flow, add an alternative path:

```markdown
Alternative (loop mode):

```
/spcrg-start 添加用户搜索，支持姓名和邮箱搜索，需要分页和权限控制
/spcrg-plan add-user-search
/spcrg-loop add-user-search
/spcrg-archive add-user-search
```
```

- [ ] **Step 3: Update Gate enforcement table**

Add a row for `/spcrg-loop`:

```markdown
| `/spcrg-loop` | first step | do not start Ralph Loop |
```

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add /spcrg-loop to project documentation"
```

---

## Task 7: Update the project skill SKILL.md

**Files:**
- Modify: `.claude/skills/project-development-workflow/SKILL.md`

- [ ] **Step 1: Add /spcrg-loop to the Command Map table**

Add after the `/spcrg-dev` row:

```markdown
| `/spcrg-loop <change-id>` | Ralph-Driven Loop: iterative implement → test → verify → review cycle until archive_ready | `tasks.md#CRG Post-Phase Verification` per phase + `design.md#CRG Quantified Review` | `check-openspec-gate.sh`, `check-crg-evidence.sh` (first step) |
```

- [ ] **Step 2: Add to Gate Script Matrix**

Add after the `/spcrg-dev` row:

```markdown
| `/spcrg-loop` | first step | `check-openspec-gate.sh`, `check-crg-evidence.sh` | do not start Ralph Loop |
```

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/project-development-workflow/SKILL.md
git commit -m "docs: add /spcrg-loop to project skill"
```

---

## Task 8: Run full verification suite

**Files:**
- No file changes — verification only

- [ ] **Step 1: Run verify-install.sh**

Run: `scripts/verify-install.sh .`
Expected: "All acceptance checks passed."

- [ ] **Step 2: Run check-command-protocols.sh**

Run: `scripts/check-command-protocols.sh .claude/commands`
Expected: "SUMMARY: N checks, N passed, 0 failed"

- [ ] **Step 3: Run the fixture test suite**

Run: `scripts/run-tests.sh`
Expected: All existing fixtures still pass (no regressions)

- [ ] **Step 4: Verify config is valid**

Run: `jq . .ai-workflow-kit/config.json`
Expected: Valid JSON with loop section

---

## Task 9: Create test project and run end-to-end validation

**Files:**
- Create: `tests/e2e-loop-test/` (temporary test project directory)

- [ ] **Step 1: Set up a minimal test project**

Create a minimal Node.js project with a simple feature to implement:

```bash
mkdir -p /tmp/spcrg-loop-test && cd /tmp/spcrg-loop-test
git init
mkdir -p src tests
cat > package.json << 'EOF'
{
  "name": "loop-test",
  "version": "1.0.0",
  "scripts": {
    "test": "node tests/run.js"
  }
}
EOF
cat > src/calculator.js << 'EOF'
class Calculator {
  add(a, b) { return a + b; }
  subtract(a, b) { return a - b; }
}
module.exports = Calculator;
EOF
cat > tests/run.js << 'EOF'
const Calculator = require('../src/calculator');
const c = new Calculator();
let pass = 0, fail = 0;
function assert(cond, msg) { if (cond) { pass++; } else { fail++; console.log('FAIL: ' + msg); } }
assert(c.add(1, 2) === 3, 'add basic');
assert(c.subtract(5, 3) === 2, 'subtract basic');
console.log(`Tests: ${pass} passed, ${fail} failed`);
process.exit(fail > 0 ? 1 : 0);
EOF
git add -A && git commit -m "init: basic calculator"
```

- [ ] **Step 2: Install the AI Workflow Kit into the test project**

```bash
cd /tmp/spcrg-loop-test
bash /Users/zhangyufeng/RawAI/self-github/specpower-crg/scripts/install-ai-workflow-kit.sh
```

Expected: "All acceptance checks passed."

- [ ] **Step 3: Set up OpenSpec and simulate /spcrg-start + /spcrg-plan output**

Create the OpenSpec structure manually (simulating what start+plan would produce):

```bash
mkdir -p openspec/changes/add-multiply/specs
```

Write `openspec/changes/add-multiply/proposal.md`, `design.md` (with CRG Discovery), `specs/feature.md`, and `tasks.md` (with CRG Precision Plan) that describe adding a `multiply` method.

- [ ] **Step 4: Run /spcrg-loop add-multiply**

In the test project, invoke:
```
/spcrg-loop add-multiply
```

Observe: Ralph Loop starts, iterates through implementation, testing, verification, and review.

- [ ] **Step 5: Verify outcomes**

Check:
- `tasks.md` has all items `[x]`
- Post-Phase Verification exists with verdict=PASS
- CRG Quantified Review exists with archive_ready=yes (or appropriate verdict)
- `src/calculator.js` now has a `multiply` method
- Tests pass including the new multiply tests
- `scripts/check-v5-review.sh add-multiply` passes

- [ ] **Step 6: Fix any issues discovered and re-verify**

If any verification step fails:
1. Identify the root cause (prompt issue, gate script issue, etc.)
2. Fix in the source framework (specpower-crg repo)
3. Re-install into test project
4. Re-run `/spcrg-loop add-multiply`
5. Loop until all verifications pass

- [ ] **Step 7: Clean up test project**

```bash
rm -rf /tmp/spcrg-loop-test
```

- [ ] **Step 8: Final commit if any fixes were made**

```bash
git add -A
git commit -m "fix: adjustments from e2e loop validation"
```

---

## Task 10: Push to remote

- [ ] **Step 1: Verify clean state**

Run: `git status`
Expected: Clean working tree, all changes committed

- [ ] **Step 2: Push**

Run: `git push origin main`
Expected: Push succeeds
