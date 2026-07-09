# 上下文预算架构重设计（2026-07-08）

来源：Claude 对"85% 压缩跑步机"问题的根因分析与重设计。
性质：根目录外部评审草稿，**仅作评审输入，非权威事实源**。Codex 执行时从 `docs/06_tasks/TASK_LEDGER.md` 现取 `T-###`。
被采纳后处置：移入 `docs/09_frozen/external_agent_reports/` 并更新活跃指针（批次 B 内完成）。

---

## 1. 根因诊断：为什么会出现压缩跑步机

| 编号 | 缺陷 | 机理 |
|---|---|---|
| D1 | 85% 预警成了第二上限 | 预警本意是可见性，实际被当成必须达标的目标。有效预算从 32k 缩水为 27.2k，而多轮压缩后的稳态内容量约 29k——**目标本身不可达**，不是执行问题。 |
| D2 | 约 37/59 个活跃文件无预算 | 只有 22 个文件有字数上限，长尾约 9k 词只受总量检查约束。压缩时没有明确靶子（"没有明确的压缩规则"的直接原因），增长时没有单文件闸门。 |
| D3 | 依赖判断型压缩而非机械型轮转 | 字数压缩需要人/智能体判断保留什么，昂贵且不可复现；条目数轮转（移走最旧 N 条）是机械动作，可脚本化。现系统把日常维护押在前者上。 |
| D4 | 任务收尾无增长纪律 | 每个任务写台账+worklog+CURRENT_STATE+决策日志等 4~6 处，净增 200~400 词。2.7k 余量 ≈ 10 个任务的寿命，之后必然再压缩——**震荡是结构决定的**。 |

结论：问题无法靠"更努力地压缩"解决。需要把系统从"事后压缩总量"改为"**结构上有界**：日常增长只发生在定长窗口里，窗口靠机械轮转维持，任务完成后总量净增 ≈ 0"。

## 2. 目标架构：三类文件 + 机械轮转 + 结构性有界

每个活跃 Markdown 归入且仅归入一类：

| 类别 | 约束方式 | 增长方式 | 维护动作 |
|---|---|---|---|
| **FIXED**（规则/契约/产品文档） | 单文件字数上限 | 只在规则真变时编辑 | 罕见；改时遵守上限即可 |
| **WINDOW**（台账、worklog、决策日志） | **条目数上限**，非字数 | 每任务追加 1 条 | 超窗时跑轮转脚本，最旧条目原文移入冻结区——零判断 |
| **INDEX**（CURRENT_STATE、ROADMAP、各索引） | 单文件字数上限 + **替换语义** | 更新=替换旧事实行，不追加 | 无需周期性压缩 |

有界性论证：FIXED/INDEX 有单文件上限且不随任务数增长；WINDOW 条目数恒定、单条大小受行长检查约束（台账已有 700 字符行限）。因此**总量收敛于常数**，任务完成后净增 ≈ 0（新条目进、最旧条目出）。总量检查从"日常闸门"降级为"结构异常报警器"。

## 3. 批次 A：预算与轮转机制落地（一个任务，RED/GREEN）

改动集中在 `scripts/context-hygiene-check.mjs`、新文件 `scripts/context-rotate.mjs` 及各自测试。

### A-1 重定基线，废除 85% 语义

- `ACTIVE_MARKDOWN_TOTAL_LIMIT` 32,000 → **36,000**。这不是随手放宽：批次 B 之前的决策日志已预设触发条件（连续元审查 >90% 且无可安全削减项），现已满足；本次调整须引用该条件写入决策日志。调整后稳态约 29k ≈ 81%，回到平静区。
- **删除 85% 预警**。改为每次输出一行信息（无阈值语义）：`Active Markdown total: X / 36000 (NN%)`。
- 新增 95% 预警，语义明确为"**安排一次结构评审任务**"（检查是否有文件类别错配或窗口失效），而不是"立刻压缩"。仅 >100% 才 fail。
- 测试：96% 水位出预警且退出码 0；101% fail。

### A-2 预算全覆盖（消灭无预算长尾）

- 新增 `DEFAULT_WORD_LIMIT = 650`：任何活跃文件若不在 `WORD_LIMITS` 显式表中，按默认值检查。新文件从诞生起自动有闸门。
- 落地步骤：先干跑列出所有超默认值且无显式条目的文件（预计含 `docs/10_project_structure/README.md`、`PRODUCT_BRIEF.md`、`NAVIGATION_AND_FLOWS.md`、`SINGLE_AGENT_WORKFLOW.md` 等 5~8 个），**逐个给显式预算（现值向上取整百 + 100 词余量），不做压缩**。本批次目标是全覆盖，不是减重——避免再造一次压缩任务。
- 今后上调任何显式预算须附一行决策日志；新增活跃文件超默认值同理。
- 输出一行信息：`Budget coverage: 59/59 files (sum of caps: NN)`。注意：**不要求 Σ上限 ≤ 总上限**——单文件上限是防单点膨胀的护栏，总上限管实际值之和；强求解算式成立只会把上限压得不可用。此设计取舍写入脚本注释。
- 测试：fixture 中未列名文件超 650 → fail；未超 → 通过。

### A-3 机械轮转脚本 `scripts/context-rotate.mjs`（自动化核心）

职责：把"超窗归档"从判断题变成一条命令。

- 默认**干跑**：打印将移动的条目与目标冻结文件路径；`--apply` 才执行写入。
- 轮转规则（全部确定性，无判断分支）：
  - `TASK_LEDGER.md`：表格行 > 12 时，把最旧的 **completed** 行（永不动 active/blocked 行）原文移入 `docs/09_frozen/task_ledgers/TASK_LEDGER_<ID>_<日期>.md`，沿用现有命名。
  - `WORKLOG.md`：条目 > 8 时，最旧条目原文移入 `docs/09_frozen/worklogs/`，沿用现有命名。
  - `DECISION_LOG.md`：保留最新 **8** 条完整决策；更旧的整条移入冻结决策日志文件，活跃文件内替换为单行索引（标题 + 日期 + 冻结路径）。
- 复用 `CONTEXT_HYGIENE_PROJECT_ROOT` 机制做 fixture 测试；不依赖 rg；输出全英文。
- 与卫生检查的关系：hygiene 只读、报告超窗；rotate 执行归档。收尾流程 = `hygiene 发现超窗 → rotate --apply → 再跑 hygiene 确认绿`。
- 测试（RED/GREEN）：13 行 fixture 台账干跑列出 1 行、apply 后活跃 12 行且冻结文件含原文；blocked 行永不被移动；决策日志轮转后索引行存在。

### A-4 卫生脚本窗口常量对齐

- `TASK_LEDGER_ROW_LIMIT` = 12、`WORKLOG_ENTRY_LIMIT` = 8（若上一批次已改则确认即可）；新增 `DECISION_LOG` 完整条目数检查（> 8 fail），与 rotate 规则一一对应。**窗口值必须在两个脚本间用同一常量来源**（rotate 从 hygiene 导入或提取共享模块），杜绝双处漂移。

**批次 A 验证**：`node --test tests/docs/`（两套测试）；`node scripts/context-rotate.mjs`（干跑）；必要时 `--apply` 后 `node scripts/context-hygiene-check.mjs` 全绿；`CONTEXT_HYGIENE_FORCE_NO_RG=1` 复跑；`git diff --check`。

## 4. 批次 B：规则文档对齐（一个任务，走规则变更流程）

涉及 `docs/05_workflow/CONTEXT_AND_RECOVERY.md` 与 `AGENTS.md`，须独立任务 + 决策日志。

### B-1 CONTEXT_AND_RECOVERY.md 的 Context Hygiene 节重写

- 手工滚动归档说明替换为：超窗时运行 `node scripts/context-rotate.mjs --apply`；保留一段"脚本不可用时的手工等价步骤"作为回退。
- 写入三类文件模型（第 2 节的表格，压缩为几行）与**收尾写入纪律**：任务收尾只写台账 + worklog（各 1 条，轮转消化）；CURRENT_STATE 一律替换语义（改行不加行）；DECISION_LOG 仅真决策；其余文件非本任务主题不碰。
- 给 FIXED 文件写一次性**压缩判据**（回应"没有明确的压缩规则"，供罕见的确需压缩时用）：① 指针替代复述——已被更权威文件覆盖的内容改为一行指针；② 一个事实只在属主文件出现；③ 删除叙述历史（属冻结区）；④ 示例与长解释移冻结区。四条判据之外不压缩。

### B-2 AGENTS.md Completion 节

- "Archive old active memory/task rows immediately if thresholds are exceeded" 改为指向 rotate 命令。增量 ≤ 20 词。

### B-3 决策日志条目

- 记录：总上限 36k 重定基线（引用既有触发条件）、三类文件模型、85% 预警废除、决策日志 8 条窗口。一条决策覆盖全部，不拆多条。

**批次 B 验证**：`git diff --check`；`node scripts/context-hygiene-check.mjs`；归档本计划至 `docs/09_frozen/external_agent_reports/CONTEXT_BUDGET_REDESIGN_PLAN_2026-07-08.md`。

## 5. 新稳态下的日常（说明，非任务）

- 普通任务收尾：跑 hygiene → 若报超窗，跑 `rotate --apply` → 再跑 hygiene。**没有压缩环节**，总量净增 ≈ 0。
- 总量信息行常年在 78~84% 波动属正常，不需任何动作。
- 触发 95% 预警 = 结构出了问题（某文件类别错配、INDEX 文件被当成日志追加），开一个结构评审任务定位，而不是启动压缩。
- 元审查（cadence 照旧）检查的是结构而非字数：类别标注是否仍准确、预算覆盖是否 59/59、rotate 是否被正常使用。

## 6. 全局约束

- 每批次一个主任务、一个提交，`T-xxx: <type>: <summary>`。
- 全部为 docs+scripts 范围，不触碰 Swift/Supabase/运行时。
- rotate 脚本 `--apply` 移动的一切内容必须**原文保留**在冻结区，禁止任何删改；干跑输出须在提交信息或 worklog 中留痕。
- 本文与活跃事实源冲突时，以活跃事实源为准并停下报告。
