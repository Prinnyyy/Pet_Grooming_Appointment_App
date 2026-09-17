# 文档治理审查修复计划（2026-07-08）

来源：Claude 对 T-163~T-173 治理改革结果的批判性复审。
性质：按 `AGENTS.md` 约定，本文件是根目录外部评审草稿，**仅作评审输入，非权威事实源**。任务编号、分支、状态一律以 `docs/06_tasks/TASK_LEDGER.md` 与 `docs/00_memory/CURRENT_STATE.md` 为准。
执行方式：Codex 从台账取下一个可用 `T-###`（执行时现查，不要照抄本文推测的编号）。每个批次是一个独立主任务；F 编号仅是本文内部引用。
被采纳后处置：将本文移入 `docs/09_frozen/external_agent_reports/` 并更新活跃指针（同一任务内完成）。

---

## 发现与修复映射总表

| 编号 | 问题 | 优先级 | 批次 | 模式 |
|---|---|---|---|---|
| F-01 | 巨型提交违反"一任务一提交"规则，需补豁免决策 | 高 | A | Quick |
| F-05 | DECISION_LOG 已达预算 95%，需预归档 | 中 | A | Quick |
| F-02 | 卫生脚本硬依赖 rg 二进制，缺失时全线误报 | 高 | B | Quick |
| F-04 | checkCurrentFacts 失败开放：正则不匹配即静默跳过 | 中 | B | Quick |
| F-07 | 元审查触发器无追踪机制 | 中 | B | Quick |
| F-06 | 台账 Notes 单行超长（1369 字符），无约束 | 中 | B | Quick |
| F-03 | AGENTS.md 硬编码分支名且处于校验盲区 | 高 | C | Quick |
| F-08 | CLAUDE.md 阅读地图缺失新治理文件 | 低 | C | Quick |
| F-09 | .rgignore 死条目；根目录草稿双副本 | 低 | D | Quick |
| F-10 | ROADMAP DoD 压缩成单句，不可逐项核对；R 编号乱序 | 低 | D | Quick |

批次顺序：A → B → C → D。理由：A 先释放 DECISION_LOG 空间（后续批次都要写决策日志）；B 是脚本改动，先于 C 才能让新增校验立即覆盖 C 的文档改动；C 是治理文档改动（按规则须独立任务）；D 是无依赖清理。

---

## 批次 A：决策日志补记与预归档（一个任务）

### F-01 补记巨型提交豁免

**问题**：提交 `01c80e4`（标注 T-166，实含 T-163~T-166 四个任务）与 `6d1da33`（标注 T-173，实含 T-167~T-173 七个任务）违反 `docs/05_workflow/GITHUB_RULES.md` 第 13 行 "Use one task per commit"。历史不重写，但需补记，否则规则可信度受损。

**步骤**：

1. 在 `docs/07_decisions/DECISION_LOG.md` 新增一条决策，要点：
   - Context：T-163~T-173 治理序列在两个批量授权提交中落地，早于/同期于该规则生效。
   - Decision：`01c80e4` 与 `6d1da33` 记录为一次性历史豁免；此后所有提交严格一任务一提交，包括治理任务。
   - Linked files：`docs/05_workflow/GITHUB_RULES.md`。
2. 不做任何 rebase、revert、amend 或 force push。

**验收**：决策日志含该条目；`git log` 未被改写。

### F-05 DECISION_LOG 预归档

**问题**：2379/2500 词（95%），F-01 及后续批次的新条目会触顶。

**步骤**：

1. 按 `docs/05_workflow/CONTEXT_AND_RECOVERY.md` 第 86 行既有规则：把 pre-trim 全文快照到 `docs/09_frozen/` 对应家族（沿用现有 decision 归档目录命名；若不存在则新建并更新 `docs/09_frozen/README.md`）。
2. 活跃文件保留：最近的治理决策（T-163~T-173 相关）+ 仍约束当前实现的产品/架构决策；历史决策压缩为单行索引（标题 + 日期 + 指向冻结快照）。
3. 目标水位：归档后活跃文件 ≤ 1500 词，为后续留出 1000 词余量。
4. 同一任务内更新 `docs/09_frozen/README.md` 等索引指针。

**验收**：`node scripts/context-hygiene-check.mjs` 通过；DECISION_LOG ≤ 1500 词；冻结快照逐字保留原文。

**批次 A 验证**：`git status --short`；`git diff --check`；`node scripts/context-hygiene-check.mjs`。

---

## 批次 B：卫生脚本 v4（一个任务，RED/GREEN）

四项改动都落在 `scripts/context-hygiene-check.mjs` + `tests/docs/context-hygiene-check.test.mjs`，属同一主题（脚本自身的失效模式），可合并为一个任务。先写失败测试再实现。

### F-02 rg 缺失时的回退

**问题**：脚本 `activeMarkdownFiles()`（约 111 行）等 5 处 `spawnSync("rg", ...)` 在无 ripgrep 二进制的环境（如本机普通 shell）全部 ENOENT。Codex 环境能过，但 META_REVIEW 要求的周期检查可能在其他环境运行。

**方案（推荐）**：分层降级。

1. 新增探测：脚本启动时 `spawnSync("rg", ["--version"])`，记录 `rgAvailable`。
2. `rgAvailable === false` 时：
   - 文件清单改用 `git ls-files -- AGENTS.md README.md docs`，再用脚本内硬编码的排除前缀过滤（`docs/09_frozen/`、`docs/02_architecture/test_resources/T-129_`、`docs/08_design/Groomly`）。排除前缀列表与 `.rgignore` 内容保持同步，并加注释互相指向。
   - `checkIgnoredPaths()`（.rgignore 行为检查）跳过，并打印显式警告行 `warn: rg unavailable, .rgignore behavior checks skipped`。跳过必须可见，不得静默。
3. 备选最小方案（若不想加回退逻辑）：启动探测失败即单条清晰报错 `ripgrep is required: brew install ripgrep` 并退出 1，同时在 `docs/06_tasks/META_REVIEW_TEMPLATE.md` 的 Required Checks 前注明 ripgrep 前置依赖。二选一，不要两者都不做。

**测试**：fixture 环境用 `PATH=/nonexistent` 或注入探测结果，断言回退清单非空且警告行出现（或最小方案下断言报错文案）。

### F-04 事实提取改为失败关闭

**问题**：`checkCurrentFacts()`（约 393-417 行）全部是 `if (a && b && a !== b)`——正则因措辞漂移提取失败时检查静默消失。

**步骤**：

1. 对 6 个提取值（CURRENT_STATE 的 latest/next/branch，TASK_LEDGER 的 next/branch，台账最新 completed 行）逐一判空：任一为 `null` 时 `failures.push("<文件> 缺少可提取的 <事实名>（措辞可能已漂移，检查正则与文档措辞是否同步）")`。
2. `checkMigrationMirrorCount`、`checkLastVerifiedDates` 已是失败关闭，不动。

**测试**：fixture 中把 "Latest completed task:" 改成 "Last completed task:"，断言脚本失败并指出缺失事实。

### F-07 元审查追踪

**问题**："每 10 个任务或每周"（`docs/06_tasks/META_REVIEW_TEMPLATE.md` 第 7 行）无任何标记记录上次元审查，脚本不校验，全靠智能体记忆——这是"不会自我优化"缺陷的残留。

**步骤**：

1. 在 `docs/00_memory/CURRENT_STATE.md` 的 Active Workflow State 节加一行：`- Last meta-review: T-### on YYYY-MM-DD.`（首次值：本轮治理序列内完成了等效审查的任务号，如 T-171 或本修复计划对应任务）。
2. 脚本新增 `checkMetaReviewCadence()`：
   - 提取该行任务号与全台账（含冻结归档，复用 `allLedgerRows()`）最新 completed 任务号；差值 ≥ 10 时 fail。
   - 提取不到该行本身即 fail（与 F-04 同口径）。
   - **不做日历周检查**：项目空闲时不应导致卫生检查变红；"每周"条款保留为 META_REVIEW_TEMPLATE 中对人的提醒。此取舍写入决策日志。
3. 元审查任务的收尾动作加入 META_REVIEW_TEMPLATE 的 Closeout：更新该标记行。

**测试**：fixture 设任务差 10，断言失败；差 9 通过；标记行缺失时失败。

### F-06 台账行长约束

**问题**：T-160/T-157 行分别 1369/1368 字符，Notes 复述 WORKLOG 验证叙事。总词数达标只是因为行数少；每个 Deep 任务都会再造一行怪物。

**步骤**：

1. 脚本 `checkRollingWindowSizes()` 附近新增：台账任一表格行 > 700 字符即 fail，报出行号与当前长度。
2. `docs/06_tasks/TASK_LEDGER.md` 顶部说明段加一句：Notes 只写结论与指针，验证细节属于 `WORKLOG.md`（此句为 06_tasks 文件内容，不触发 05_workflow 规则变更流程）。
3. 现有 T-160/T-157 行压缩到限内：保留结论（应用到哪个项目、什么被部署/阻塞、剩余风险指针），验证清单细节移到对应 WORKLOG 冻结条目（若已存在则直接引用，不重复迁移）。**T-157 是活跃 blocked 任务，压缩时不得丢失四个 APNs 秘密变量名与解锁条件。**

**测试**：fixture 造一条 800 字符行，断言失败。

**批次 B 验证**：RED/GREEN `node --test tests/docs/context-hygiene-check.test.mjs`；`node scripts/context-hygiene-check.mjs`；`git diff --check`。

---

## 批次 C：治理文档修订（一个任务，须走规则变更流程）

按 `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md` Rule Change Tasks 节：独立任务 + 决策日志条目 + 卫生检查。两处改动同为"入口文档与事实源对齐"，可并入一个治理任务。

### F-03 消除 AGENTS.md 分支名第三副本

**问题**：分支名存在三处——`AGENTS.md` 第 35 行（硬编码）、`TASK_LEDGER.md` 第 5 行、`CURRENT_STATE.md` 第 31 行。脚本只校验后两者一致。叠加 T-172 规则后，每次分支轮换要么触发一次治理任务、要么让 AGENTS.md 变陈旧。

**步骤**：

1. `AGENTS.md` 第 35 行改为指针写法（与 `GITHUB_RULES.md` 第 8 行同口径）：

   ```text
   - Work branch baseline comes from `docs/00_memory/CURRENT_STATE.md`; do not continue work from another branch unless the user names it.
   ```

2. 不给 AGENTS.md 加脚本校验——消除副本优于校验副本。
3. 决策日志记录：分支名事实源唯一化为 CURRENT_STATE，台账第 5 行保留（已有脚本校验对齐）。

### F-08 CLAUDE.md 阅读地图补全

**问题**：`CLAUDE.md` 第 26-46 行阅读规则与第 70-79 行 Source of Truth 均未提及 T-167~T-173 新建的治理文件；Claude 职责含规划与治理评审，入口图落后于改革。

**步骤**：

1. Current Task Reading Rules 追加两行条件入口：
   - `docs/06_tasks/ROADMAP.md` when planning or milestone review matters
   - `docs/07_decisions/DECISION_LOG.md` when reviewing rule or scope decisions
2. Source of Truth 列表追加：
   - Managed roadmap: `docs/06_tasks/ROADMAP.md`
   - Git rules: `docs/05_workflow/GITHUB_RULES.md`
   - Decisions: `docs/07_decisions/DECISION_LOG.md`
3. 控制增量 ≤ 60 词（CLAUDE.md 预算 600，当前 419，余量充足）。

**批次 C 验证**：`git diff --check`；`node scripts/context-hygiene-check.mjs`；决策日志新增条目。

---

## 批次 D：低优清理（一个任务）

### F-09 .rgignore 死条目与草稿双副本

**步骤**：

1. 删除 `.rgignore` 中 `DOCS_GOVERNANCE_OPTIMIZATION_PLAN.md` 行（该文件已归档，根目录不存在）。`.gitignore` 若有同名行一并删除。
2. 根目录 `APP_STATUS_OVERVIEW.md` / `V1.0_RELEASE_TASK_PLAN.md` 与其 2026-07-06 冻结快照并存：**不删除根副本**（属用户工作产物），但在本批次决策或 worklog 里记一句"根副本为活草稿，冻结件为定稿快照，采纳以冻结件为准"，消除口径歧义。
3. 若本修复计划已被采纳执行，同步将本文移入 `docs/09_frozen/external_agent_reports/DOCS_GOVERNANCE_REVIEW_FIX_PLAN_2026-07-08.md`，并从 `.rgignore`/`.gitignore` 清理对应条目（如有）。

### F-10 ROADMAP DoD 展开为清单

**步骤**：

1. `docs/06_tasks/ROADMAP.md` 第 20 行的单句 DoD 拆为可逐项打勾的列表（每行一个标准，约 12-15 行）：占位 UI、必填字段持久化、授权图片渲染、过期/回填/取消恢复、通知、前台聊天、账号删除、隐私/支持 URL、Privacy Manifest、App Store 材料、构建/测试/E2E 门禁、Supabase advisor 无新发现。
2. 候选表按 R 编号重排（R-016/R-017 移到序位）；编号本身不改。
3. ROADMAP 预算 1800 词、当前 635，展开清单增量约 100 词，安全。

**批次 D 验证**：`git diff --check`；`node scripts/context-hygiene-check.mjs`。

---

## 全局约束（执行时逐条对照）

- 每批次一个主任务、一个提交，提交格式 `T-xxx: <type>: <summary>`（本计划本身就是对该规则的修复，不得再违反）。
- 不 rebase、不改写历史、不动 `main`、不合并 `2fddf7b`。
- 提交/推送仍需用户逐次授权。
- 不修改任何 Swift/Supabase/运行时行为；全部批次均为 docs+scripts 范围。
- 批次 B、C 完成后各跑一次完整卫生检查确认新校验为绿。
- 若执行中发现本文与活跃事实源冲突，以活跃事实源为准并停下报告，不要按本文强行执行。
