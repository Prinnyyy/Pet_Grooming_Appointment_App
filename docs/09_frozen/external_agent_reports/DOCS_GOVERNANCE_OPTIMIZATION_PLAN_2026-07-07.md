# Markdown 文档治理体系优化计划

> 文档性质：外部评审提案（评审输入，非项目规范文件；不改变分支、任务编号、验证或产品状态）
> 编写日期：2026-07-07
> 状态基线：分支 `codex/pet-fit-structure-cleanup`；T-152~T-156 已提交，T-157（客户推送通知）进行中未提交；`main` 落后 76 个提交且含 1 个独有提交
> 审计方法：6 个文档族多智能体审计（根治理/记忆层/任务与决策/产品规则/后端契约/冻结档结构）+ 6 个横切维度（git/预算/自我优化/历史/规划/测试）主会话逐文件核实；所有结论均有 file:line 级证据
> 执行约定：本计划只提出改动，不直接修改规则文件。每项改动按 `docs/06_tasks/TASK_LEDGER.md` **执行时的下一可用编号**领号（本文用 G-xx 占位，正是为了避免第 3.2 节诊断的"预分配编号碰撞"缺陷）

---

## 1. 总诊断

这套文档体系的设计意图是好的（L0-L4 分层读取、字数软预算、滚动归档、卫生检查脚本），真正的问题集中在四个字：**只测形，不测真**。卫生脚本量尺寸、查链接，却从不校验事实；于是在记忆文档说错最新任务号的那几次收尾，它照样全绿通过。其余缺陷——双源维护、规则重复、外部计划成为事实路线图、git 规范缺失——都是这个根因的不同表现：**易变事实没有唯一属主，且没有任何机制在事实漂移时报警。**

按危害排序的四个结构性病灶：

1. **治理分叉（最危险）**：`main` 上存在独立提交 `2fddf7b "Repair markdown information architecture"`（2026-07-06），对 AGENTS.md/CLAUDE.md/记忆文档做了**另一套**重构（其 DECISION_LOG 在 `docs/00_memory/`，本分支在 `docs/07_decisions/`），与本分支 T-140~T-151 的重构互不知情。规则又禁止触碰 `main`，等于把一场全规则系统的合并冲突锁进了未来。
2. **事实路线图不受治理**：被 gitignore 的根文件 `V1.0_RELEASE_TASK_PLAN.md` 被 AGENTS.md 第 29 行宣布"非权威、仅评审输入"，但已执行的 T-152~T-157 与它逐一吻合；T-153 偏离该计划（通知中心从 1.1 提前）却无任何决策记录。规则与现实彻底脱节。
3. **记忆滞后无约束**：T-153 代码提交时（`5be228d`）记忆仍称 T-152；本次评审期间还目击了 T-151 vs T-156 的同类滞后。没有任何规则规定记忆必须与它描述的提交同步落盘。
4. **打补丁式自我修复**：卫生脚本里为单一历史凭据事件硬编码的四条正则（`STALE_CREDENTIAL_PATTERNS`）暴露了当前模式——每次事故后加一个专用补丁，而不是建一个通用机制。

---

## 2. 分维度诊断（证据保留）

### 2.1 活跃文档占用过多上下文（context_bloat）

| # | 缺陷 | 证据 |
|---|---|---|
| B1 | 字数预算表**双源维护**：`CONTEXT_AND_RECOVERY.md` 第 79-95 行的表与 `scripts/context-hygiene-check.mjs` 第 7-21 行的 `WORD_LIMITS` 各存一份，必然漂移 | 两文件逐行比对 |
| B2 | 预算只覆盖 13 个文件；最大活跃文档全部无预算：`REORGANIZATION_LOG.md` 2,124 词、`SCREEN_INVENTORY.md` 1,279 词、`TOOLING_POLICY.md` 1,230 词、`CLAUDE.md`、根 `README.md`、`SUPABASE_CONTRACT.md` | `wc -w` 全量清点 vs `WORD_LIMITS` |
| B3 | 无**全局**活跃上下文总预算：13 个文件各自达标时总和仍可达约 1.4 万词 | 预算表求和 |
| B4 | 台账 Notes/Checks 单元格 200~1,209 字符、中英混杂、与 WORKLOG 重复，是预算爆表引擎：6 天内被迫归档 4 次（含同日 2 次） | T-153 行单行 1,209 字符实测；`docs/09_frozen/task_ledgers/` 四个分片日期 |
| B5 | `REORGANIZATION_LOG.md` 是纯追加历史却常驻活跃区，且不在预算清单 | L3 层定义 vs 实际内容 |
| B6 | "targeted top sections" 读取规则依赖各文件保持特定结构，但没有任何文件被要求锁定其头部结构 | `CONTEXT_AND_RECOVERY.md` L0 定义 |

### 2.2 规则冲突（rule_conflict）

| # | 缺陷 | 证据 |
|---|---|---|
| C1 | 台账表头写死"continue T-157 remote apply/deploy"默认指令，与同文件行内"须显式授权"的门控矛盾，也与 CLAUDE.md"无活跃任务"矛盾 | `TASK_LEDGER.md` 表头 vs T-157 行 vs `CLAUDE.md:15` |
| C2 | "契约先行"（PRODUCT_BRIEF 第 77 行：backend state 先入 SUPABASE_CONTRACT.md）与契约文件自身"事后更新"规则互斥；T-153~T-157 两者都没执行：8 个新 public RPC、3 张新表未入契约 | 迁移目录 grep vs `SUPABASE_CONTRACT.md` |
| C3 | AGENTS.md 与 SINGLE_AGENT_WORKFLOW.md 大段规则原文重复（一任务一运行/先查 git status/禁子代理/停止条件），改一处漏一处 | 两文件比对 |
| C4 | 四份产品文档仍把推送通知列为 deferred/须停止询问，而 T-157 正在实现它——按现行规则，执行中的任务本身就是违规 | `PRODUCT_BRIEF.md:64,83`、`NAVIGATION_AND_FLOWS.md:114`、`DESIGN_SYSTEM.md:86`、`UI_IMPLEMENTATION_NOTES.md:78` |

### 2.3 历史记录不连贯（history_incoherence）

| # | 缺陷 | 证据 |
|---|---|---|
| H1 | 记忆滞后：`5be228d` 提交 T-153 代码时记忆仍称 T-152；评审期间再现 T-151 vs T-156 滞后 | git log + 两次工作树快照 |
| H2 | FEATURE_INDEX 漏更新 T-152（Offers 行不指向新的 `Features/Groomer/Offers/` 代码面），却抢先记录了未提交的 T-157 | `FEATURE_INDEX.md` vs 代码树 |
| H3 | T-157 磁盘上有 4 个迁移（1 主 + 3 个同日 fix），台账与 CURRENT_STATE 只记 1 个 | `supabase/migrations/2026070*` 未跟踪文件 |
| H4 | 记忆是**分支本地**的：`main` 的 CURRENT_STATE 停在 T-048/T-050（落后约 108 个任务）且无任何过期警示 | `git show main:docs/00_memory/CURRENT_STATE.md` |
| H5 | 冻结档索引两处维护已分叉：`docs/10_project_structure/README.md` 漏 `external_agent_reports/` 族 | 与 `docs/09_frozen/` 实际目录比对 |
| H6 | 历史检索昂贵：查 T-120 需 3-4 跳、经过 28.7k 词分片、默认搜索零命中（.rgignore 屏蔽冻结区） | 实测检索路径 |
| H7 | REORGANIZATION_LOG 违反自身"每次归档必记录"契约：最近几次台账归档无日志条目 | 日志末尾 vs 归档文件日期 |
| H8 | CURRENT_STATE 的 Risks/Validation 段正退化为与 WORKLOG 重复的逐任务流水账，背离"fast path"自我定位 | 文件头部自述 vs 正文 |

### 2.4 规则不清晰（rule_clarity）

| # | 缺陷 | 证据 |
|---|---|---|
| R1 | "下一个可用任务号"没有算法定义（归档后表头过期即有复用风险，且这一失效模式已实际发生过） | 台账表头历史 |
| R2 | WORKLOG 留存规则凭判断（"8-10 条"仅是散文建议），冻结分片从 242KB 到 7KB 不等 | `docs/09_frozen/worklogs/` 实测 |
| R3 | ADR 流程死信：README 要求 ADR、模板存在、实际 0 份；DECISION_LOG 无编号、无状态、且有 06-20/06-25 乱序条目，基于日期的"后者覆盖前者"语义失效 | `docs/07_decisions/` 全目录 |
| R4 | HANDOFF/REVIEW 模板成孤儿，与 CONTEXT_AND_RECOVERY 的内联检查点格式竞争，无文档引用它们 | 全库引用搜索 |
| R5 | `CLAUDE_reference/` 孤立：其自述的"CLAUDE.md 中的指针"已不存在，仅剩 2026-06-20 的 T-002 时代过期快照 | `CLAUDE_INDEX.md:15-16` |
| R6 | CLAUDE.md 定位"评审角色"，但条文全是实现者口吻的 Groomly UI 切片时代规则；不写当前分支名（靠会话记忆补救） | `CLAUDE.md` 全文 |

### 2.5 不会自我优化（self_optimization）

| # | 缺陷 | 证据 |
|---|---|---|
| S1 | 卫生脚本只测尺寸/链接/忽略路径/一组硬编码凭据正则，**从不校验事实**——在记忆出错的收尾时刻全绿通过 | `context-hygiene-check.mjs` 全文 |
| S2 | 无跨文件一致性断言：分支名散布在 ≥4 个文件（AGENTS/GITHUB_RULES/CURRENT_STATE/TASK_LEDGER），最新任务号散布在 ≥3 个文件，无一被机器校验 | 全库 grep |
| S3 | 脚本第 57-60 行 `rg` spawn 失败路径未处理，无 rg 的机器上直接崩栈而非干净报错 | 源码审阅 + 沙箱复现 |
| S4 | 无周期性元审查任务类型、无规则变更流程（谁可改 AGENTS.md？改动记到哪？）、任务失败教训无回流规则的通道 | 工作流文档全查 |

### 2.6 git 规则缺陷（git_rules）

| # | 缺陷 | 证据 |
|---|---|---|
| G1 | GITHUB_RULES.md 全文仅 43 行；提交信息规范只有一句 "Use a clear message" → 历史里四种风格并存："T-155 ..."、"feat: ..."、"chore: ..."、中文"补充新文件" | `git log --format=%s` |
| G2 | 无"任务号入提交信息"要求 → git 历史与台账无法机器对账 | 同上 |
| G3 | 无 `main` 对账节奏；`main` 落后 76 个提交且含 1 个独有提交（即 2fddf7b 治理分叉） | `git rev-list --left-right --count` |
| G4 | 3 个已合并 `codex/*` 分支本地+远端未清理，无分支生命周期规则 | `git branch -a` |
| G5 | 无 WIP/检查点提交政策：T-157 跨 app+backend+tests 的大体量改动长期未提交，一次误操作即全损 | `git status` |
| G6 | 无 tag/发布规则（V1.0 计划要求 `v1.0.0` tag 出包，但规则层无对应条文） | GITHUB_RULES 全文 |
| G7 | 当前分支名硬编码在 ≥4 个文件，切分支时必须人肉同步 | S2 同源 |

### 2.7 项目规划规则缺陷（planning_rules）

| # | 缺陷 | 证据 |
|---|---|---|
| P1 | 唯一存在的前瞻计划（V1.0_RELEASE_TASK_PLAN.md，24 任务/里程碑/DoD）被 gitignore + rgignore + 宣布非权威，却在被逐字执行 | git log T-152~T-157 vs 计划 |
| P2 | 无受管路线图位置（docs/06_tasks/ 无 PLAN/ROADMAP 文件），无"外部报告→受管计划"的采纳机制 | 目录清点 |
| P3 | 台账无里程碑/DoD 维度，无法回答"1.0 还差几项" | 台账 schema |
| P4 | 计划偏离无记录义务：T-153 范围提前无决策条目（与 R3 死信 ADR 互为因果） | DECISION_LOG 全查 |
| P5 | 外部计划预分配任务号（T-152~T-175）与台账自然领号并行，存在碰撞风险 | 两套编号源并存 |

### 2.8 测试规则缺陷（testing_rules）

| # | 缺陷 | 证据 |
|---|---|---|
| T1 | 新增 `tests/migrations/` 与 `tests/functions/` 无任何文档、脚本或工作流步骤要求运行它们——写了测试但没有人/流程会跑 | 全库引用搜索 |
| T2 | 无"每个新 RPC/迁移/Store 必须附测试"的规则；红/绿实践存在于历史任务记录中但未成文为义务 | 工作流文档全查 |
| T3 | MIGRATION_RULES.md 缺 Edge Function 部署、APNs/Edge 密钥管理、pg_cron 任务校验规则——T-154/T-157 恰好全需要 | 该文件 vs 新迁移内容 |
| T4 | 架构文档无 Edge Function/定时任务/推送分发层，违反 ARCHITECTURE.md 自身的更新义务 | `docs/02_architecture/` 全查 |

---

## 3. 目标信息架构

### 3.1 单一事实源矩阵（核心原则：易变事实只有一个属主，其余文件只准链接、不准复制）

| 易变事实 | 唯一属主 | 现状违规复制点（改为链接） |
|---|---|---|
| 当前分支名 | `CURRENT_STATE.md` | AGENTS.md、GITHUB_RULES.md、TASK_LEDGER.md 表头、docs/README.md |
| 最新完成/进行中任务号 | `TASK_LEDGER.md` | CURRENT_STATE.md（可保留但由脚本断言一致）、CLAUDE.md、根 README.md |
| 字数预算 | `context-hygiene-check.mjs`（代码即规范） | CONTEXT_AND_RECOVERY.md 的预算表（删除，改为"运行脚本查看"） |
| 项目阶段/范围状态 | `PRODUCT_BRIEF.md`（加盖 last-verified 日期戳） | CLAUDE.md、根 README.md 的 Active Phase 段 |
| 路线图/里程碑 | 新建 `docs/06_tasks/ROADMAP.md`（受管、入库） | 根目录外部计划草稿降级为其输入 |

### 3.2 结构调整

- **CLAUDE.md 瘦身**为三段：角色（评审）+ 红线边界 + 一行"其余规则见 AGENTS.md 与 CURRENT_STATE.md"。删除一切会过期的阶段性事实陈述。
- **AGENTS.md 与 SINGLE_AGENT_WORKFLOW.md 去重**：AGENTS.md 只留启动序列与硬边界，流程细节单归工作流文件。
- **ROADMAP.md 采纳机制**：外部报告（根目录 gitignore 草稿）→ 用户批准 → 摘要进 ROADMAP.md（里程碑、DoD、任务映射表）→ 台账领号执行 → 每完成一个里程碑任务，同一提交内勾销 ROADMAP 对应行。计划偏离必须在 DECISION_LOG 落一条带编号的记录。
- **台账 schema 减负**：Notes 列限 ≤160 字符、单语言；证据细节全部归 WORKLOG，台账行只留指针。
- **REORGANIZATION_LOG、CLAUDE_reference/ 移入冻结区**；HANDOFF/REVIEW 模板二选一：接入工作流或归档。
- **DECISION_LOG 条目规范**：`D-NNN | 日期 | 状态(active/superseded by D-MMM) | 一句话决定 | 指针`；ADR 模板保留给重大架构决策，README 不再强制"每个决策一份 ADR"。

---

## 4. 分阶段任务表

> 领号规则：执行时从台账取下一可用编号，按下表顺序逐个映射（G-01 → 第一个可用号，依此类推）。一次运行一个任务；未经用户批准不提交/推送。

### 阶段 1 —— 真相止血（全部 Quick，1~2 天）

| 占位 | 任务 | 范围 | 验收标准 | 验证 |
|---|---|---|---|---|
| G-01 | 过期声明修正 | 修 CLAUDE.md:15、根 README.md:26 的"无活跃任务"；四份产品文档的推送 deferred 条目改为"scope promoted to T-157（见 DECISION_LOG D-xxx）"；补 T-153 范围提前的决策记录 | 全库 grep 无"push notifications deferred"残留；DECISION_LOG 新增 2 条带编号记录 | `git diff --check`；hygiene 脚本 |
| G-02 | 台账矛盾与滞后修复 | 删除表头"continue T-157"默认指令（改为中性的下一可用号说明）；T-157 行补齐 4 个迁移与 Edge Function 事实；FEATURE_INDEX 补 T-152 Offers 路由 | 台账/CURRENT_STATE/磁盘三方对 T-157 描述一致；C1 冲突消失 | 同上 |
| G-03 | 后端契约补账 | SUPABASE_CONTRACT.md 补 T-152~T-157 的 8 个 RPC、3 张表；统一契约更新语义为"实现与契约同一提交更新"（消除 C2 的先行/事后互斥） | 契约文件与 `supabase/migrations/` 对象清单一致 | 迁移目录 diff 清点 |

### 阶段 2 —— 机制建设（Quick/Standard 混合，1 周）

| 占位 | 任务 | Mode | 范围 | 验收标准 |
|---|---|---|---|---|
| G-04 | 卫生脚本升级 v2 | Standard | ① 预算单源化：删 CONTEXT_AND_RECOVERY 预算表；② 新增一致性断言：分支名跨文件一致、CURRENT_STATE 最新任务号 = 台账最高完成号、台账迁移记述数 = 磁盘迁移数（按 T-xxx 前缀）、FEATURE_INDEX 覆盖台账近 5 个 Standard 任务；③ 行数检查（WORKLOG ≤10 条、台账 ≤15 行）；④ 补预算：REORGANIZATION_LOG(归档前)/SCREEN_INVENTORY/TOOLING_POLICY/CLAUDE.md/根README；⑤ 全局总预算（活跃 md 总词数 ≤12,000）；⑥ 修 rg spawn 崩溃路径；⑦ 删硬编码凭据正则，改为通用"文件头 last-verified 日期超 30 天报警" | 用注入的假漂移（改错分支名/任务号）能让脚本变红；无 rg 时干净报错退出 |
| G-05 | GITHUB_RULES 重写 | Quick | 提交格式 `T-xxx: <type>: <summary>`（英文，type ∈ feat/fix/docs/chore/test/migration）；记忆文档与其描述的代码**同一提交**；Standard/Deep 任务结束必须留检查点提交（WIP 允许，禁长期未提交）；已合并分支清理流程；`main` 对账为显式专项任务（含 2fddf7b 治理分叉的合并策略预案：以本分支文档架构为准，逐文件裁决）；tag 规则（`vX.Y.Z` 需用户批准） | 新规则 ≤600 词；含一个正/反例提交信息对照 |
| G-06 | ROADMAP 采纳与规划规则 | Quick | 新建 `docs/06_tasks/ROADMAP.md`（从 V1.0 计划摘要迁入：里程碑、DoD、任务映射、完成勾销状态）；AGENTS.md 第 29 行改写为"外部报告经用户批准后按此流程采纳"；台账加一列 Milestone | ROADMAP 与已完成 T-152~T-156 状态一致；P1~P5 缺陷全部有对应条款 |
| G-07 | 测试规则补全 | Quick | IOS_BUILD_AND_TESTING.md 增设：新 RPC/迁移/Store 必附测试（红→绿留痕）；`tests/migrations/`、`tests/functions/` 接入 `scripts/preflight.sh` 与工作流验证矩阵；MIGRATION_RULES.md 补 Edge Function 部署/密钥/pg_cron 三节 | preflight 实际执行新测试目录并通过；T1~T4 各有对应条款 |
| G-08 | 结构减负与归档 | Quick | REORGANIZATION_LOG、CLAUDE_reference/ 按规程移入 `docs/09_frozen/`；冻结索引单源化（10_project_structure 只留指针）；孤儿模板裁决；补 H7 缺失的归档日志；DECISION_LOG 补 D-NNN 编号与状态列 | hygiene v2 全绿；活跃 md 总词数较基线下降 ≥15% |

### 阶段 3 —— 自我优化闭环（Quick，半天 + 长期例行）

| 占位 | 任务 | 范围 | 验收标准 |
|---|---|---|---|
| G-09 | 元审查任务模板 | 新建 `docs/06_tasks/META_REVIEW_TEMPLATE.md`：每 10 个任务（或每周）领号执行一次——跑 hygiene v2；抽查 3 个最旧 last-verified 的活跃文档做时效核对；检查 git log 与台账对账（凭 G-05 的 T-xxx 提交前缀机器比对）；把本周期的规则摩擦点记入 DECISION_LOG 或直接修正 | 模板 ≤300 词；首次元审查作为验收演练跑通 |
| G-10 | 规则变更流程 | AGENTS.md 增补：规则文件（AGENTS/CLAUDE/workflow/*）的任何修改必须 ① 单独任务 ② DECISION_LOG 留条 ③ 同提交更新所有链接方 ④ 跑 hygiene v2 | 流程条款落地；G-04~G-09 的历次规则改动可回溯 |

### 依赖关系

G-01~G-03 无依赖可立即执行；G-04 是 G-08/G-09 的验收工具，优先做；G-05 的提交格式是 G-09 对账能力的前提；`main` 对账（G-05 中的预案）建议在 T-157 收尾提交后、V1.0 提审材料前作为独立 Deep 任务执行。

---

## 5. 明确不做清单

- **不扩预算上限**来"解决"超标——超标的正确出路是归档或删重复，预算是约束不是弹簧。
- **不重写冻结档**：`docs/09_frozen/` 内容一律只读；H6 的检索问题靠索引单源化解决，不靠改历史。
- **不动产品红线**：请求优先模型、SwiftUI 不直连 Supabase、远程写入逐任务授权——本计划全部条款均在其内。
- **`main` 对账前不在 main 上做任何文档修改**，避免加深 2fddf7b 分叉。
- **不引入新工具链**（doc-lint CI、外部文档平台等）：现有 Node 脚本 + rg 足够，新依赖违反 AGENTS.md 无授权不加依赖的边界。

---

## 6. 成功度量

| 指标 | 基线（2026-07-07） | 目标 |
|---|---|---|
| 活跃 md 总词数（不含冻结/种子表） | 约 36,000 | ≤30,000（阶段 2 末） |
| 易变事实的复制点数（分支名/任务号/阶段状态） | ≥11 处 | 每事实 1 属主 + 纯链接 |
| hygiene 脚本可检出的漂移类型 | 2 类（尺寸/链接） | ≥6 类（+分支/任务号/迁移数/索引覆盖/总预算/时效） |
| 提交信息可机器对账率 | 约 40%（混合格式） | 100%（G-05 之后的新提交） |
| 计划偏离的决策留痕 | 0/1（T-153 无记录） | 每次偏离 1 条 D-NNN |
| 已确认的规则冲突（第 2.2 节） | 4 组 | 0 |
