# SpecPower-CRG：AI 驱动的开发工作流框架

> 把 OpenSpec + Superpowers + code-review-graph 三件套封装成 Claude Code 项目级命令，让团队从"复制长 prompt"变成"输入短命令"，从"靠人记流程"变成"靠脚本强制门禁"。

---

## 这是什么

SpecPower-CRG 是一个 **Claude Code 项目级工作流框架**。它通过 9 个 slash 命令（以 `/spcrg-` 为前缀），把从需求分析到归档的完整开发流程产品化。

**核心循环：**

```
需求 → CRG 定位（去哪里看）→ Agent 读源码 → Agent 做决策
    → Superpowers 驱动 TDD → CRG 验证影响 → OpenSpec 归档
```

**一句话理解 V5：** CRG 不是"跑一堆工具把结果贴进文档"的证据收集器，而是**代码导航器 + 风险验证器**——先告诉你该看哪些代码，你读完做判断，开发完后 CRG 再验证你改对了没。

---

## 三大支柱

| 工具 | 角色 | 负责什么 |
|---|---|---|
| **OpenSpec** | 意图层 | 定义需求、规格、设计、任务、长期记忆。proposal → design → specs → tasks → archive 的完整生命周期。 |
| **CRG (code-review-graph)** | 事实层 | 分析代码结构、依赖关系、调用链、测试覆盖、模块社区、架构热点。告诉你"代码实际长什么样"。 |
| **Superpowers** | 纪律层 | 驱动 brainstorming、plan writing、TDD（红-绿-重构）、subagent 并行开发、code review、verification。 |

**三者协作关系：**

```
OpenSpec 说：我们要做什么、为什么做
CRG 说：代码现在是什么样、改哪里影响什么
Superpowers 说：怎么做才能高质量地做到
```

---

## 9 个命令总览

| 命令 | 用途 | 适用场景 |
|---|---|---|
| `/spcrg-start <描述>` | 启动新变更 | 新功能、大改动 |
| `/spcrg-plan <change-id>` | 制定实施计划 | start 完成后 |
| `/spcrg-dev <change-id>` | TDD 执行开发 | plan 审批后 |
| `/spcrg-review <change-id>` | 量化审查 | 开发完成后 |
| `/spcrg-archive <change-id>` | 验证并归档 | review 通过后 |
| `/spcrg-bugfix <bug 描述>` | 修复 bug | 小型修复，不改变行为 |
| `/spcrg-hotfix <问题描述>` | 生产热修复 | 紧急线上问题 |
| `/spcrg-refactor <目标>` | 重构 | 保持行为不变的结构改善 |
| `/spcrg-audit <change-id>` | 审计证据完整性 | 随时检查 |

---

## 完整工作流详解

### 场景一：新功能开发（最常见）

假设你要给一个 TODO API 添加搜索功能。

#### 第 1 步：启动 `/spcrg-start`

```
/spcrg-start 添加一个搜索端点，支持按标题子串过滤 TODO 项
```

**Claude 会做什么：**

1. 调用 `/opsx:propose` 创建 OpenSpec 变更目录：
   ```
   openspec/changes/add-todo-search/
   ├── proposal.md    （提案：做什么、为什么）
   ├── design.md      （设计：怎么做）
   ├── specs/         （规格：GIVEN/WHEN/THEN）
   └── tasks.md       （任务清单）
   ```

2. 运行 **CRG Discovery Protocol**（核心区别于 V1）：
   - 用需求关键词做语义搜索，找到相关代码
   - **强制阅读源码**（不是只看 CRG 摘要）
   - 记录：读了什么、发现了什么、做了什么决策
   - 确定：涉及哪些模块、入口函数是什么、现有模式是什么、风险边界多大

3. 把 CRG Discovery 结果写入 `design.md`：

   ```markdown
   ## CRG Discovery

   ### Discovery Metadata
   - generated_at: 2026-04-29T02:35:00Z
   - generated_by: /spcrg-start
   - crg_graph_status: fresh
   - source_requirement: 添加搜索端点，支持按标题子串过滤

   ### Code Reading Summary
   | File | Symbol | Why Read | Finding | Decision |
   |---|---|---|---|---|
   | src/services/todo.js | TodoService | 语义搜索命中 | 5个方法，内存数组存储 | modify |
   | src/services/todo.js | TodoService.list | 最接近搜索的现有模式 | 直接返回引用 | reuse-pattern |
   | src/services/todo.js | TodoService.remove | 使用 Array.filter() | 同样的模式适合搜索 | reuse-pattern |
   | src/index.js | (file) | HTTP 路由层 | 无 query string 解析 | modify |
   | tests/run.js | (file) | 测试文件 | 自定义 assert 框架 | modify |

   ### Risk Boundary
   - expected_changed_files: 3
   - expected_changed_symbols: 4
   - hub_nodes: TodoService
   - bridge_nodes: none
   ```

4. 运行 `superpowers:brainstorming` 澄清需求边界

5. **运行门禁脚本**（在请求你批准之前）：
   ```
   scripts/check-openspec-gate.sh add-todo-search    → 验证文件齐全
   scripts/check-crg-evidence.sh add-todo-search     → 验证 Discovery 结构完整
   ```

6. 停下，等你确认。

**你需要做什么：** 看 proposal/design/specs/tasks 是否合理，确认后告诉 Claude 继续。

---

#### 第 2 步：制定计划 `/spcrg-plan`

```
/spcrg-plan add-todo-search
```

**Claude 会做什么：**

1. 运行门禁（确保 Discovery 存在）
2. **继承** Discovery 的结论（不重新搜索）
3. 对每个入口函数：查询调用者/被调用者 → 阅读源码 → 决定修改方案
4. 对每个改动符号：查询已有测试 → 阅读测试代码 → 决定测试策略
5. 调用 `superpowers:writing-plans` 生成 TDD 驱动的任务列表

**产出物 `tasks.md` 示例（函数级粒度）：**

```markdown
## CRG Precision Plan

### Function-Level Change Map
| Task | Target | Current Behavior | Required Change | Tests | Reference Pattern | Risk |
|---|---|---|---|---|---|---|
| 1.1 | tests/run.js:search-unit-tests | 不存在 | 添加搜索单测 | tests/run.js | tests/run.js:assert | low |
| 1.2 | src/services/todo.js:TodoService.search | 不存在 | 添加 search() 方法 | tests/run.js | TodoService.remove | low |
| 2.1 | tests/run.js:search-integration-tests | 不存在 | 添加 HTTP 集成测试 | tests/run.js | tests/run.js:assert | low |
| 2.2 | src/index.js:searchHandler | 不存在 | 添加 GET /todos/search 路由 | tests/run.js | src/index.js:listHandler | medium |

### Phase Plan

#### Phase 1: Service 层 + 单测
- expected_files: [src/services/todo.js, tests/run.js]
- expected_symbols: [TodoService.search, search-unit-tests]
- verification_command: `node tests/run.js`

#### Phase 2: HTTP 端点 + 集成测试
- expected_files: [src/index.js, tests/run.js]
- expected_symbols: [GET /todos/search handler]
- verification_command: `node tests/run.js`
```

注意和 V1 的区别：
- V1 的任务是 `"修改 UserService"` 这种模块级
- V5 的任务精确到 `src/services/todo.js:TodoService.search`，带 TDD 步骤、验证命令、参考模式

---

#### 第 3 步：执行开发 `/spcrg-dev`

```
/spcrg-dev add-todo-search
```

**Claude 会做什么：**

1. 运行门禁
2. **Delta Check**：检测是否是同一会话连续开发
   - 同会话 → 跳过 CRG 前置检查，直接读目标文件开始 TDD
   - 恢复会话 / 工作树变化 → 运行 detect_changes 检测是否有影响
3. 对每个 Phase 的每个 Task 执行 TDD：
   - 写失败测试 → 确认红 → 写最小实现 → 确认绿 → 重构
4. **Phase 完成后做 CRG Post-Phase Verification**：

   ```markdown
   ### CRG Post-Phase Verification: Phase 1

   - actual_changed_files: [src/services/todo.js, tests/run.js]
   - expected_changed_files: [src/services/todo.js, tests/run.js]
   - scope_drift_percent: 0
   - changed_symbol_test_coverage: 100
   - verdict: PASS
   - action_taken: 继续 Phase 2
   ```

5. 如果 verdict = BLOCKING（比如范围漂移 > 20%），**立即停止**

---

#### 第 4 步：审查 `/spcrg-review`

```
/spcrg-review add-todo-search
```

**Claude 会做什么：**

1. OpenSpec 合规检查（specs 是否满足、tasks 是否完成）
2. **CRG 量化审查**（聚合所有 Phase 的数据）：

   ```markdown
   ## CRG Quantified Review

   ### Scope Drift
   - planned_files: 3
   - actual_files: 3
   - drift_percent: 0
   - verdict: PASS

   ### Changed Function Test Coverage
   - changed_symbols: 4
   - tested_symbols: 4
   - coverage_percent: 100
   - verdict: PASS

   ### Final CRG Verdict
   - archive_ready: yes
   - blockers: []
   ```

3. Superpowers 代码审查（TDD 合规、最小实现、YAGNI、DRY）
4. 输出最终结论：`archive_ready: yes` 或者列出阻断项

---

#### 第 5 步：归档 `/spcrg-archive`

```
/spcrg-archive add-todo-search
```

**Claude 会做什么：**

1. 三重门禁：OpenSpec gate + CRG evidence gate + **V5 Review gate**（必须 archive_ready=yes）
2. 检查所有 tasks 标记为 `[x]`（完成）
3. 运行项目检查：单测、集成测试、E2E、lint、typecheck、build
4. CRG Archive Gate（最终影响确认）
5. `/opsx:verify` → `/opsx:archive`（归档到 openspec/changes/archive/）

---

### 场景二：修 Bug

```
/spcrg-bugfix 登录态过期后刷新页面报 500
```

**特点：**
- **不创建 OpenSpec change**（除非发现行为需要改变）
- 不跑 OpenSpec gate（轻量级）
- 仍然使用 CRG 定位问题代码
- 仍然遵循 **Read Before Decide**（读源码再判断）
- 必须写回归测试

**如果发现修复需要改变预期行为：**
- 停止 bugfix 流程
- 升级为 `/spcrg-start fix-{bug-name}`（走完整 V5 流程：Discovery + brainstorming + gates）
- 从此按特性流程走（plan → dev → review → archive）

---

### 场景三：生产热修复

```
/spcrg-hotfix 支付回调超时导致订单状态未更新
```

**特点：**
- **最小修复**，禁止趁机重构或清理
- 必须产出回滚计划
- 必须添加回归测试
- CRG 快速诊断（精准定位问题函数）
- 如果爆炸半径超出预期 → 立即停止

---

### 场景四：重构

```
/spcrg-refactor 把 UserService 里的大函数拆分，保持行为不变
```

**特点：**
- CRG 做重构评估（找到大函数、hub 节点、桥接节点）
- Superpowers brainstorming 确认范围和风险
- 如果发现需要改变对外行为/API → 升级为 `/opsx:propose`

---

### 场景五：审计证据完整性

```
/spcrg-audit add-todo-search
```

**产出表格示例：**

```
| Section                        | Exists | Schema Valid | Notes              |
|-------------------------------|--------|-------------|--------------------|
| ## CRG Discovery              | ✓      | ✓           | 8 行 Code Reading  |
| ## CRG Precision Plan         | ✓      | ✓           | 4 tasks, 2 phases  |
| Post-Phase Verification P1    | ✓      | ✓           | verdict=PASS       |
| Post-Phase Verification P2    | ✓      | ✓           | verdict=PASS       |
| ## CRG Quantified Review      | ✓      | ✓           | archive_ready=yes  |
```

---

## 门禁系统（Gate）

门禁不是建议——它们是命令文件的**第一步**。每个阶段命令启动时先跑脚本，不通过就不允许继续。

### 门禁脚本

| 脚本 | 职责 |
|---|---|
| `check-openspec-gate.sh` | 验证 proposal/design/tasks/specs 文件存在；archive 模式下验证所有 tasks 标记为 [x] |
| `check-crg-evidence.sh` | 验证 CRG Discovery 结构完整（7 个子章节、表格行数、字段非空）；strict 模式还验证 Precision Plan 和 Post-Phase |
| `check-v5-review.sh` | 验证 Quantified Review 存在、verdict 枚举合法、数值一致性（drift > 20% 但 verdict=PASS → 失败） |
| `check-command-protocols.sh` | 验证命令文件包含 V5 协议关键词（安装验收用） |

### 门禁执行矩阵

| 命令 | 何时跑门禁 | 跑哪些 | 失败时 |
|---|---|---|---|
| `/spcrg-start` | 末尾（产出证据后） | openspec-gate + crg-evidence (shape-only) | 不请求审批，先修复 |
| `/spcrg-plan` | 首步 | openspec-gate + crg-evidence (strict) | 不跑 writing-plans |
| `/spcrg-dev` | 首步 | openspec-gate + crg-evidence (strict) | 不跑开发 |
| `/spcrg-review` | 首步 | openspec-gate + crg-evidence (strict) | 不进入审查 |
| `/spcrg-archive` | 首步 + /opsx:verify 前 | openspec-gate (archive mode) + crg-evidence + v5-review | 不归档 |
| `/spcrg-audit` | 首步 | 三个脚本全跑 | **仅报告**，不阻断 |

### 数值一致性检查

门禁脚本不是只检查"章节存在"——它还做**数值一致性验证**：

```
如果 scope_drift_percent = 35（超过阈值 20%）
且 verdict = PASS
→ 门禁失败："drift=35 > 20 但 verdict=PASS，矛盾"

如果 changed_symbol_test_coverage = 60（低于阈值 80%）
且 verdict = PASS
→ 门禁失败："coverage=60 < 80 但 verdict=PASS，矛盾"

如果 archive_ready = yes
但某子章节 verdict = BLOCKING
→ 门禁失败："archive_ready=yes 但存在 BLOCKING，矛盾"
```

这防止了 Agent "自洽地撒谎"——数据说不行但结论说行。

---

## 配置系统

`.ai-workflow-kit/config.json`（提交到 git，团队共享）：

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

| 配置项 | 含义 | 默认值 |
|---|---|---|
| `scopeDriftPercent` | 允许的范围漂移上限，超过则 verdict 不能为 PASS | 20% |
| `changedSymbolTestCoveragePercent` | 改动函数的测试覆盖率下限 | 80% |
| `discoveryMinReadings` | CRG Discovery 至少读几个源文件 | 2 |
| `precisionPlanMinTasks` | Precision Plan 至少有几个任务行 | 1 |
| `maxCallChainDepth` | Agent 展开调用链的建议深度 | 2 |
| `requireE2EForAffectedFlows` | 受影响用户流是否强制要求 E2E | true |
| `allowHumanOverride` | verdict=BLOCKING 时是否允许人工豁免 | true |
| `requireReviewBeforeArchive` | 归档前是否强制要求 Quantified Review | true |

**团队自定义：** 直接编辑 config.json，所有脚本会读取最新值。

---

## 状态管理

`.ai-workflow-kit/state/<change-id>.json`（gitignore，每个开发者本地）：

```json
{
  "phases": {
    "start": { "status": "completed", "sessionId": "...", "treeHash": "..." },
    "plan": { "status": "completed", "plannedPhases": 2 },
    "dev": {
      "status": "completed",
      "currentPhase": 2,
      "phaseHistory": [
        { "phaseNumber": 1, "verdict": "PASS", "scopeDriftPercent": 0, "changedSymbolCoveragePercent": 100 },
        { "phaseNumber": 2, "verdict": "PASS", "scopeDriftPercent": 0, "changedSymbolCoveragePercent": 100 }
      ]
    },
    "review": { "status": "completed" },
    "archive": { "status": "completed" }
  }
}
```

**用途：**
- Dev 阶段的 **Delta Check** 通过比较 `sessionId` 和 `treeHash` 判断"同会话连续开发"还是"恢复开发"
- 同会话 → 跳过重复 CRG 检查，直接读文件开始 TDD
- 不同会话 / 工作树变化 → 跑 detect_changes 确认无意外变更

---

## 安装

### 前置依赖

```bash
# 1. OpenSpec（需求/规格管理）
npm install -g @fission-ai/openspec@latest
cd your-project
openspec init

# 2. code-review-graph（代码分析）
pipx install code-review-graph
code-review-graph install
code-review-graph build

# 3. Superpowers（Claude Code 插件）
# 在 Claude Code 内执行：
/plugin install superpowers@claude-plugins-official

# 4. jq（配置文件读取，推荐但非必需）
brew install jq  # macOS
# 没有 jq 会 fallback 到 python3
```

### 安装框架到项目

```bash
cd your-project
bash /path/to/specpower-crg/scripts/install-ai-workflow-kit.sh
```

安装器会：
- 写入 `.claude/commands/spcrg-*.md`（9 个命令）
- 写入 `.claude/skills/project-development-workflow/SKILL.md`
- 写入 `scripts/check-*.sh`（5 个门禁脚本）
- 创建 `.ai-workflow-kit/config.json`（如果不存在）
- 自动运行 `verify-install.sh` 验收

### 验证安装

```bash
./scripts/verify-install.sh .
```

期望输出 5/5 绿：
```
[1/5] commands exist                              ok
[2/5] gate scripts exist and executable           ok
[3/5] commands embed gate script calls            ok
[4/5] spcrg-start.md runs gate after artifacts    ok
[5/5] V5 protocol keywords present                ok
All acceptance checks passed.
```

---

## 产出物参考

一个完成的 change 目录结构：

```
openspec/changes/add-todo-search/
├── proposal.md         ← 做什么、为什么
├── design.md           ← 怎么做 + ## CRG Discovery + ## CRG Quantified Review
├── specs/
│   └── feature.md      ← GIVEN/WHEN/THEN 规格
└── tasks.md            ← ## CRG Precision Plan + Post-Phase Verifications + [x] 标记
```

归档后移动到：
```
openspec/changes/archive/add-todo-search/
```

---

## V5 vs V1 对比

| 维度 | V1 | V5 |
|---|---|---|
| CRG 角色 | 证据收集器（列工具名） | 代码导航器 + 风险验证器 |
| 证据格式 | 散文本 + 工具名 grep | 结构化 schema（必填字段、表格行数检查） |
| 任务粒度 | 模块级（"修改 UserService"） | 函数级（"src/services/todo.js:searchUsers"） |
| Dev 前置检查 | 每次仪式性地跑全量 CRG | Delta Check（同会话跳过、恢复时才检查） |
| Review 输出 | 列表建议 | 量化判定 + `archive_ready: yes/no` 门禁 |
| 门禁严格度 | grep CRG 字符串 | 结构化验证 + 数值一致性 + 任务完成检查 |
| 阶段继承 | 每阶段重新搜索 | 后阶段继承前阶段 evidence，不重复搜索 |

---

## 设计原则

1. **CRG Navigation First** — CRG 回答"该看哪里"，不直接回答"该改什么"
2. **Read Before Decide** — 所有 CRG 命中必须配套读真实源码，然后才能做判断
3. **Decision Evidence, Not Raw Evidence** — 记录结构化决策，不粘贴工具原始输出
4. **No Repeated Blind Search** — 后一阶段继承前一阶段的 evidence，不重新搜索
5. **Delta Over Ritual** — Dev Pre-Phase 只在上下文可能变化时做检查
6. **Verification Has Teeth** — verdict 必须是 PASS / BLOCKING / NEEDS_HUMAN_DECISION
7. **Scripts Enforce Shape, Commands Enforce Thinking** — 脚本管结构、命令管思考

---

## 框架开发者指南

如果你要修改这个框架本身（不是使用它）：

```bash
# 修改命令/脚本后，重建安装器
./scripts/build-installer.sh

# 验证安装完整性
./scripts/verify-install.sh .

# 跑 fixture 回归测试（13 个用例）
./scripts/run-tests.sh

# 三个都绿才能提交
```

### 项目结构

```
specpower-crg/
├── .ai-workflow-kit/
│   └── config.json                 ← 阈值配置（团队共享，入库）
├── .claude/
│   ├── commands/spcrg-*.md         ← 9 个命令文件
│   └── skills/.../SKILL.md         ← 项目级 Skill
├── scripts/
│   ├── check-openspec-gate.sh      ← OpenSpec 文件门禁
│   ├── check-crg-evidence.sh       ← CRG 证据结构门禁
│   ├── check-v5-review.sh          ← 量化审查门禁
│   ├── check-command-protocols.sh  ← V5 关键词验收
│   ├── verify-install.sh           ← 安装验收（5 步）
│   ├── detect-change-id.sh         ← 自动检测 active changes
│   ├── run-tests.sh                ← fixture 回归测试
│   ├── build-installer.sh          ← 生成安装器
│   └── install-ai-workflow-kit.sh  ← 自包含安装器（生成产物）
├── tests/fixtures/                 ← 门禁脚本的测试用例
├── docs/superpowers/
│   ├── specs/                      ← 设计 spec
│   └── plans/                      ← 实施 plan
├── CLAUDE.md                       ← 项目规则（安装到下游项目）
├── CHANGELOG.md                    ← 版本历史
└── README.zh-CN.md                 ← 本文件
```

---

## FAQ

**Q: 如果 CRG 不可用（比如图太旧或构建失败），会怎样？**

A: 命令会立即停止，输出 "CRG unavailable — STOP"。不允许伪造 CRG evidence。先运行 `code-review-graph build` 再继续。

**Q: 如果我的 change 里有未完成的 task，能归档吗？**

A: 不能。`check-openspec-gate.sh` 在 archive 模式下会检查 `tasks.md` 中所有 `- [ ]` 项。有一个未打勾就会 block。

**Q: 我可以跳过某个阶段吗？比如直接从 start 跳到 dev？**

A: 不行。`/spcrg-dev` 首步跑 `check-crg-evidence.sh`（strict 模式），会检查 `## CRG Precision Plan` 是否存在。没有 plan 就不让 dev。

**Q: verdict 是谁算的？脚本还是 Agent？**

A: Agent 看完数据后写 verdict，**脚本做数值一致性验证**。如果 Agent 写了 `verdict: PASS` 但数据 `coverage_percent: 60`（低于 80% 阈值），脚本会报矛盾并 fail。

**Q: 阈值 20% 和 80% 太严/太松怎么办？**

A: 编辑 `.ai-workflow-kit/config.json` 里的 `thresholds` 字段即可。所有脚本会读取最新配置。

**Q: 一个 bugfix 做着做着发现要改行为，怎么办？**

A: `/spcrg-bugfix` 命令里有明确指示：如果发现预期行为需要改变，停止 bugfix 工作流，升级为 `/opsx:propose fix-{bug-name}`，然后走 start → plan → dev → review → archive 全流程。

**Q: 框架安装到下游项目后，tests/fixtures/ 会不会也装过去？**

A: 不会。`install-ai-workflow-kit.sh` 只安装命令、脚本和配置。`tests/fixtures/` 和 `run-tests.sh` 是框架开发者专用，不分发到下游。

---

## 命令名称来源

`spcrg` = **Sp**ec-driven + **C**ode **R**eview **G**raph

取自仓库名 `specpower-crg`，简短、唯一、不会和其他插件命令冲突。
