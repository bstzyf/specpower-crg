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

Read `.ai-workflow-kit/config.json` and extract:
- `loop.maxIterations` → bind to variable `MAX_ITERATIONS` (fallback: `10`)
- `loop.completionPromise` → bind to variable `COMPLETION_PROMISE` (fallback: `ARCHIVE_READY`)

## Start Ralph Loop

Invoke `/ralph-loop` with the exact argument values from the previous step.
Substitute `MAX_ITERATIONS` and `COMPLETION_PROMISE` with their actual values
(the angle-bracketed names below are placeholders, NOT literal strings):

```
/ralph-loop "<navigator-prompt from next section>" --max-iterations MAX_ITERATIONS --completion-promise "COMPLETION_PROMISE"
```

With default config, this becomes:

```
/ralph-loop "<navigator-prompt>" --max-iterations 10 --completion-promise "ARCHIVE_READY"
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
3. 使用 `superpowers:subagent-driven-development` 驱动该 phase 的 task 执行（支持并行或顺序，每个 task 分派独立的 subagent）
4. 每个 task 内部，使用 `superpowers:test-driven-development` 完成 TDD 循环：
   - RED：写一个精确描述 Required Change 的失败测试
   - GREEN：写最小实现让测试通过
   - REFACTOR：改进代码结构，确认测试仍通过
5. 每个 task 实现后标记 `- [x]`
6. 结束本轮（下一轮进入阶段 B）

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
