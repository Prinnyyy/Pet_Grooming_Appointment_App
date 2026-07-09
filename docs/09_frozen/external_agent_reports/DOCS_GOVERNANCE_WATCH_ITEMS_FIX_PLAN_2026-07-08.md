# 治理观察项修复计划（2026-07-08）

来源：Claude 对 T-174~T-177 修复批次复审时提出的三个观察项。
性质：根目录外部评审草稿，**仅作评审输入，非权威事实源**。任务编号、分支、状态以 `docs/06_tasks/TASK_LEDGER.md` 与 `docs/00_memory/CURRENT_STATE.md` 为准；Codex 执行时从台账现取 `T-###`。
被采纳后处置：移入 `docs/09_frozen/external_agent_reports/` 并更新活跃指针（在批次 B 内完成）。

## 观察项与批次映射

| 编号 | 观察项 | 优先级 | 批次 | 模式 |
|---|---|---|---|---|
| W-02 | 链接完整性检查空转：活跃文档 0 个 `[]()` 链接，反引号路径无人校验 | 中 | A | Quick |
| W-03 | 脚本报错文案中英混杂 | 低 | A | Quick |
| W-01 | 活跃 Markdown 总量 29,284/32,000（91.5%），余量仅约 2.7k 词 | 中 | B | Quick |

批次顺序：A → B。理由：A 给脚本加上水位预警和路径校验后，B 的削减动作能立即被新校验覆盖验证；且 B 若触发路径失效（归档移动文件），A 的新检查恰好能兜住。

---

## 批次 A：卫生脚本 v5（一个任务，RED/GREEN）

三项改动都在 `scripts/context-hygiene-check.mjs` + `tests/docs/context-hygiene-check.test.mjs`，同属"脚本检查面补全"，合并为一个任务。先写失败测试再实现。

### W-02 反引号路径存在性检查

**问题**：项目文档风格用反引号路径（`docs/...`）而非 markdown 链接，`checkMarkdownLinks` 在 59 个活跃文件上实际检查数为 0。路径失效（归档移动、重命名）目前只有 Feature Index 一处受检，其余文档的悬空引用无人发现。

**实现**：新增 `checkBacktickPathIntegrity(files)`，对每个活跃文件：

1. 提取所有行内反引号片段：`` /`([^`\n]+)`/g ``（围栏代码块内的内容不含行内反引号，天然不会误匹配）。
2. 判定为"待校验路径"须满足其一：
   - 以 `docs/`、`scripts/`、`supabase/`、`ios/`、`tests/` 开头；
   - 等于根文件名 `AGENTS.md`、`README.md`、`CLAUDE.md`；
   - 以 `../` 开头（相对当前文件目录解析，如 ROADMAP 中的 `../00_memory/CURRENT_STATE.md`）；
   - 以 `./` 开头（按仓库根解析，覆盖 `./scripts/ios-build.sh` 类验证命令引用）。
3. 跳过规则（防误报）：片段含 `*`、`<`、`>`、`#`、空格、`{`、`}` 任一字符即跳过（通配示例、占位符、命令行）。
4. 解析后 `fs.existsSync` 不存在即 fail，报出所在文件与原始片段。目录路径（以 `/` 结尾或指向目录）按目录存在性判定。
5. 预留一个 `BACKTICK_PATH_ALLOWLIST` 常量（初始为空数组），用于未来有意引用不存在路径的示例；加入即须写注释说明原因。
6. 输出统计行：`Backtick paths checked: N`，让检查面可见（对照 W-01 教训：不可见的检查等于没有）。

**预检**：实现前先对当前活跃文档做一次干跑（可临时脚本），把现存的悬空路径在同一任务内修正或加入 allowlist——避免 GREEN 阶段被存量问题卡住。

**测试**：fixture 含一个指向不存在文件的反引号路径 → fail；含 `*`/占位符片段 → 不报；`../` 相对路径正确解析 → 通过。

### W-03 报错文案统一为英文

**问题**：T-175 的失败关闭文案照抄了修复计划里的中文模板（`checkCurrentFacts` 6 处、`checkMetaReviewCadence` 2 处），脚本其余输出为英文。

**实现**：

1. 统一替换为英文，建议格式：`CURRENT_STATE.md is missing an extractable <fact name> (wording may have drifted from the expected pattern)`。
2. 同步更新 `tests/docs/context-hygiene-check.test.mjs` 中对这些文案的断言。
3. 顺带在脚本头部加一行注释约定：`// All console/failure output is English.`

### 附带：总量水位预警（W-01 的脚本侧半件）

**问题**：总量检查只在 100% 时变红，91.5% 的水位曾长期不可见。

**实现**：`checkActiveMarkdownTotal` 增加预警阈值常量 `ACTIVE_MARKDOWN_WARN_RATIO = 0.85`；总量 ≥85% 时输出 `warn: active Markdown total at NN% of limit`（警告行，不入 failures）。≥100% 仍为 fail。测试：fixture 造 86% 水位断言警告行出现且退出码为 0。

**批次 A 验证**：RED/GREEN `node --test tests/docs/context-hygiene-check.test.mjs`；`node scripts/context-hygiene-check.mjs`；`CONTEXT_HYGIENE_FORCE_NO_RG=1 node scripts/context-hygiene-check.mjs`；`git diff --check`。

---

## 批次 B：活跃总量削减（一个任务）

### W-01 现状与目标

实测分布（2026-07-08，回退清单 59 个文件）：**没有单个巨型文件**，头部平坦——最大的 `SCREEN_INVENTORY.md` 仅 1279 词，前 10 名合计约 10.2k，长尾 34 个文件合计约 9.3k。因此削减是组合动作，单点无解。

- 目标水位：**≤ 27,200 词（85%）**，即净减约 2.1k 词。
- 策略取向：**先削减，不提限**。32k 上限本身是上下文预算的锚，轻易上调会让预算失去约束力。

### 削减动作（按预期收益排序）

1. **收紧滚动窗口（约 -500 词，一次动作长期有效）**：
   - 脚本常量 `TASK_LEDGER_ROW_LIMIT` 15 → **12**，`WORKLOG_ENTRY_LIMIT` 10 → **8**。
   - 两个值仍在 `CONTEXT_AND_RECOVERY.md` 已写明的 "12-15 rows / 8-10 entries" 区间内，**不构成 05_workflow 规则变更**，无需独立治理任务。
   - 同一提交内把超出的旧行/旧条目按既有惯例归档到 `docs/09_frozen/task_ledgers/`、`docs/09_frozen/worklogs/`。
2. **压缩 `docs/10_project_structure/README.md`（808 词，目标 ≤450，约 -350）**：结构索引应只列目录职责一行一条；逐目录的解释性段落下沉到各目录自己的 README 或删除。
3. **压缩 `docs/00_memory/CURRENT_STATE.md` Current Known Risks 节（约 -150）**：第 81 行附近的长枚举句改为"一类风险一行 + 指针"；已被 ROADMAP/台账覆盖的事实不重复陈述。
4. **长尾审计（34 个 <520 词的文件，合计约 9.3k，目标 -800 至 -1200）**：逐个问三个问题——是否仍被 Feature Index/工作流引用？内容是否已被更权威文件覆盖？是否属于历史记录该冻结？预期候选：各子目录 README 中与 `docs/README.md` 重复的导航段、`docs/07_decisions/ADR_TEMPLATE.md`（若从未被使用可冻结）、`docs/04_ios/` 下已稳定不变的运行手册中的背景段落。**审计结论（保留/压缩/冻结及理由）逐条记入 worklog，不得静默删除。**
5. **budget 防回涨**：`REORGANIZATION_LOG.md` 预算 2500 → **1200**（现 711 词，2500 是它还是全量日志时的旧额度）；`DECISION_LOG.md` 预算 2500 → **1800**（现 973，预归档后不应再涨回去）。预算收紧属脚本常量修改，随本任务提交。

### 决策日志条目（本批次必写）

记录削减决策及**未来提限的客观触发条件**，避免每次逼近上限都重新争论：

> 若连续两次元审查时总量均 >90% 且当次已无可安全削减项，则允许一次性将 `ACTIVE_MARKDOWN_TOTAL_LIMIT` 上调至 36,000，并记录新决策。在此之前一律以削减应对。

### 收尾

- 归档本计划至 `docs/09_frozen/external_agent_reports/DOCS_GOVERNANCE_WATCH_ITEMS_FIX_PLAN_2026-07-08.md`，清理根副本。
- 更新 `Last meta-review` 标记？**不更新**——本批次是定向修复，不是完整元审查；cadence 标记只在走完 `META_REVIEW_TEMPLATE.md` 全项时更新。

**批次 B 验证**：`node scripts/context-hygiene-check.mjs`（确认总量 ≤85%、无新警告、路径检查通过）；`node --test tests/docs/context-hygiene-check.test.mjs`；`git diff --check`。

---

## 全局约束

- 每批次一个主任务、一个提交，格式 `T-xxx: <type>: <summary>`。
- 全部为 docs+scripts 范围，不触碰 Swift/Supabase/运行时行为。
- 长尾审计只允许"压缩或冻结"，禁止删除任何仍被引用的文件；移动文件必须同任务更新所有活跃指针（批次 A 的路径检查会兜底验证）。
- 提交/推送仍需用户逐次授权。
- 若执行中发现本文与活跃事实源冲突，以活跃事实源为准并停下报告。
