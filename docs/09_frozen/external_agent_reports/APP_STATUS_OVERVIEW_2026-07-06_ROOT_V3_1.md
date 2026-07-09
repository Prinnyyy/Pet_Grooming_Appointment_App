# Pet Groomer Marketplace（Groomly）应用完成状态介绍

> 文档性质：产品经理视角的完成状态评审报告（外部评审输入，非项目规范文件；不改变分支、任务编号、验证或产品状态）
> 编写日期：2026-07-06
> 状态基线：分支 **`codex/pet-fit-structure-cleanup`**（当前工作基线，非 `main`）；最新完成任务 **T-151**；下一个可用任务编号 **T-152**
> 说明：本文件名已列入项目 `.gitignore`/`.rgignore`，按项目约定作为外部评审草稿放置于根目录，归档时移入 `docs/09_frozen/external_agent_reports/`。此前基于错误分支（main，T-048 基线）的两版草稿全部作废。
> 配套文档：《V1.0 正式版交付任务计划表》（`V1.0_RELEASE_TASK_PLAN.md`）
> 核实版本：v3.1（2026-07-06 代码级逐条复核；修正三处——Offers tab 实为隐藏而非可见占位、单测口径为 221 个 `@Test` 注解、客户端 Storage 桶契约为 5 个；其余关键声明全部核实通过，证据见文末第 7 节）

---

## 1. 产品定位

**Pet Groomer Marketplace**（UI 品牌名 **Groomly**）是一款 iOS 原生宠物美容预约市场应用：

> 宠物主人发布一条公开美容请求 → 系统匹配符合条件的独立美容师 → 美容师主动报价 → 宠物主人确认一份报价 → 生成预约（Booking）→ 服务完成后评价。

核心产品模型（不可变更的产品铁律）：

```text
Open Grooming Request（公开请求）
-> Matched Groomers（系统匹配）
-> Groomer Offers（美容师报价）
-> Customer Confirmation（客户确认）
-> Booking（预约）
```

与传统"客户逐个联系美容师"模式的差异化：**客户只描述一次需求，供给侧主动竞价**。产品已明确的方向边界：**不做**面向客户的公开美容师目录、直接时段预订、或 ML 推荐系统；客户的选择永远锚定在"收到的报价"上。

### Pet-Fit 匹配方向（本分支的核心演进）

Post-MVP 阶段在保持请求优先模型的前提下，把匹配层做成了**基于证据、可解释**的 pet-fit v1：

- 客户请求提供宠物特征（固定分类学、体重推导尺寸、毛发类型）、服务需求、位置模式、照片、偏好时间窗。
- 美容师档案提供服务覆盖、可用时段、预约偏好、休假窗口、日容量，以及低权重的自述专长（fit claims）与作品集标签。
- 完成的预约和结构化评价结果随时间累积为高置信度证据，参与匹配打分，并有公平性校准与负面证据抑制。
- 匹配分数与理由是用户可读的"适配解释"，美容师有自己的证据看板（owner evidence dashboard RPC）。

### 目标用户

| 角色 | 描述 |
|---|---|
| Customer（宠物主人） | 维护宠物档案与个人资料，发布请求，比较报价，管理预约，评价服务 |
| Groomer（独立美容师） | 维护档案/服务/作品集/可用性/适配信号，浏览匹配请求，报价接单，完成履约 |
| Admin | **明确推迟**，无管理后台与审核流程 |

---

## 2. 当前完成状态总览

### 2.1 完成度速览

| 维度 | 状态 |
|---|---|
| 产品阶段 | MVP 闭环 + Groomly UI 改版 + **pet-fit/可用性匹配体系** + 客户资料设置 + Debug Console + TestOps 自动化，实现至 T-151 |
| 端到端主流程 | ✅ 注册 → 角色引导 → 发请求（含照片/地址）→ 可用性感知匹配 → 报价 → 接受 → 预约 + 聊天 → 完成 → 结构化评价，全链路可用且经远程自动化冒烟验证 |
| iOS 代码规模 | 约 34,800 行 Swift（不含测试），较 MVP 期近翻倍 |
| 后端 | Supabase（ref `lqmasbuqzvcvtawonjlb`），**44 个迁移**，5 个私有 Storage 桶（客户端契约 `PhotoStorageBucketID`），11 个 public 受控 RPC，本地/远程迁移历史已对齐（T-128 修复） |
| 单元测试 | **221 个 Swift Testing `@Test` 单测**（参数化展开后运行约 224 例）+ 3 个 XCTest UI 测试 + **TestOps Node 测试套件（24 个）** |
| 自动化验证 | TestOps 远程后端生命周期冒烟 `smoke5` 5/5 通过；匹配评估 `matching_baseline` 8/8 通过；带标签清理零残留 |
| 构建基线 | `./scripts/ios-build.sh` 与 `./scripts/ios-test.sh` 于 2026-07-01（T-137）通过 |
| 已知存活缺陷 | 无记录 |

### 2.2 架构现状（健康，且比 MVP 期更强）

```text
SwiftUI View（Features/*，保持轻薄）
  -> Store（@MainActor 状态所有者）
    -> Repository 协议（Core/Repositories，含 Debug 事件包装器）
      -> Supabase 适配器（Core/Infrastructure，含本地照片/资料快照缓存）
        -> Supabase（Postgres + RLS + 受控 RPC + Storage + 私有 SQL 匹配函数）
```

- SwiftUI 不直连 Supabase；关键转换全走 `security definer` RPC；RLS + 显式授权双重控制，且有**负向测试政策**要求。
- 匹配的资格、可用性、日容量、证据打分全部由后端 SQL 私有函数持有，客户端不做权威匹配计算。
- 图片体系：私有桶 + 认证下载 + 本地缓存（`LocalCustomerPetPhotoCache`、`LocalProfileSnapshotCache`）+ 统一渲染组件（`GroomlyModuleImage`）——宠物照片、请求照片、双角色头像、作品集均可见。
- 诊断体系：DEBUG 结构化事件（Debug Console）+ TestOps 运行元数据，支持本地复现与自动化证据。
- 工程运维：上下文卫生检查脚本、凭据分类规范（CLI PAT / DB 密码 / publishable / `sb_secret` / JWT service-role 五类分离）、TestOps 清理门控。

### 2.3 功能模块完成度矩阵

| 模块 | 已实现 | 剩余缺口（已核实） |
|---|---|---|
| 认证与角色 | 邮箱/密码、会话恢复、原子化角色引导、登出 | 邮箱确认仍需跳浏览器后手动回 App 登录；无深链（无 `onOpenURL`）；无生产 SMTP；无社交登录 |
| 客户资料 | **头像、昵称、地址（含自动填充搜索）、联系邮箱、电话**（T-127） | — |
| 宠物管理 | 宠物 CRUD、固定分类学/体重尺寸/毛发类型、私有照片上传/删除/**渲染** | — |
| 请求发布 | 五步向导；**位置模式/街道地址/服务半径/照片全部持久化**（T-049 契约修复），含回读展示 | 请求不可编辑（推迟） |
| 请求管理（客户） | 状态卡轮播、时间线、真实取消、booked→Booking 交接卡 | 交接卡"已读"仍是本机 UserDefaults，跨设备失效 |
| 匹配（pet-fit v1） | 可用时段/预约偏好/休假强制（T-071/072）、**日容量匹配**（T-126）、fit claims/作品集标签低权重信号、结构化评价→证据汇总→打分与理由文本、公平性校准、负面证据抑制、美容师证据看板 | 匹配仍在**请求创建瞬间**计算；新激活/新完善档案的美容师不回填匹配存量开放请求（未见 backfill 机制） |
| 报价 | 创建/撤回（时间、价格、留言），客户分组查看、含匹配证据展示、接受 | **Groomer Offers tab 被整体隐藏**（`.offers` 不在 `GroomerTab.visibleCases`，占位视图仅为不可达兜底），美容师无处集中跟踪报价状态 |
| 预约 | 原子接受→Booking+会话；双方取消；美容师完成；时间重叠保护 | 取消后无"再次发布"引导（rebooking 推迟） |
| 聊天 | 参与者纯文本聊天 + 预约上下文 | 无实时/轮询，手动刷新；无附件、已读回执（推迟） |
| 评价 | 一次性评分/评论 + **结构化评价结果**（喂给匹配证据） | 单向评价；无美容师回复；无审核 |
| 美容师档案 | 资料、地址/位置模式、服务（含尺寸带 T-104）、作品集（含 fit 标签）、**可用时段/预约偏好/休假**、头像 | — |
| 通知 | 无 | Home 通知铃铛仍是**空动作假按钮**（`notificationAction: {}`）；无推送、无通知中心 |
| 请求过期 | RPC 层内联校验过期请求（报价/接受被拒） | **无后台过期转换**（无 pg_cron）：超时请求在列表中不会变为过期态，僵尸卡片风险仍在 |
| 测试与运维 | 221 单测；TestOps 后端生命周期/匹配自动化 + 种子账号（T-129）+ 清理门控；Debug Console | 无崩溃上报、无分析埋点（Debug Console 是本地诊断，不是生产遥测） |
| 商店合规 | 密钥纪律良好 | **无账号删除**（App Store 5.1.1(v) 硬门槛）；**无 `PrivacyInfo.xcprivacy`**；无隐私政策/支持页 |

### 2.4 与前两版评审草稿的差异（勘误）

前两版草稿基于 `main` 分支的 T-048 基线，当时列为 P0 的"照片能传不能看"和"向导字段填了不存"在本分支**均已解决**（认证下载渲染 + T-049 请求契约修复），当时的测试缺口（88 单测）也已大幅补齐（221 单测 + TestOps）。本版评审只针对**仍然真实存在**的缺口。

---

## 3. 产品经理评审：不合理之处与改进意见

按对 1.0 上线的伤害程度排序（全部经代码/迁移核实）。

### P0 — 不修复不能上线

**① 无账号删除 + 无隐私清单，提审必拒。**
App 支持注册，App Store 审核指南 5.1.1(v) 强制要求账号删除入口；Apple 同时要求 `PrivacyInfo.xcprivacy` 隐私清单与隐私政策链接。当前三者皆无。这是 1.0 的第一优先级合规工程。
**改进：** 删除 RPC（个人数据删除/匿名化，保护对方参与者的预约/评价完整性）+ Edge Function 持服务密钥删 Auth 用户 + Account 入口二次确认；补隐私清单与政策/支持页。

**② 无通知的双边市场无法运转。**
新匹配、新报价、报价被接受、新消息/取消——全部依赖用户主动打开 App 手动刷新。匹配体系已经做到了可用性感知和公平性校准的精度，但**匹配得再准，美容师看不到就等于零**。这是当前产品最大的价值漏损点，也是留存/流动性的头号风险。
**改进：** 1.0 必须交付 APNs 推送（4 类关键事件），Realtime 聊天覆盖前台场景。

**③ 美容师报价追踪能力缺失 + 假通知铃铛必须消灭。**
核实修正：Offers tab 并非可见占位——`.offers` 已从 `GroomerTab.visibleCases` 移除，用户看不到 "not connected yet"；但这意味着**美容师报价后没有任何集中界面可跟踪状态**，只能去请求详情逐个翻，与后端能力（RLS 已允许美容师读自己的报价）严重不匹配。客户 Home 的通知铃铛则是**真实可见的假按钮**（`CustomerPetsView.swift` 中 `notificationAction: {}`）。
**改进：** 实现"我的报价"列表（按 pending/accepted/declined/withdrawn/expired 分组）并把 `.offers` 加回可见 tab、删除占位兜底；铃铛要么接通知中心要么移除。

**④ 请求过期仍是"半执行"状态。**
RPC 层会拒绝对过期请求的报价/接受（内联校验），这比纯纸面强；但没有任何后台任务把超时请求转为 `expired`，客户列表和美容师 feed 里的僵尸卡片不会自己消失，美容师会浪费报价意愿，客户会误以为请求还活着。
**改进：** `pg_cron` 定时转换（请求 + 关联报价/匹配联动）+ iOS 过期态渲染。匹配评估已有 TestOps 基线，过期转换应一并纳入自动化回归。

### P1 — 严重影响体验/增长，1.0 应修复

**⑤ 匹配不回填，供给增长不反哺存量需求。**
匹配体系已演进为可用性感知 + 日容量 + 证据打分，但计算时机仍只有请求创建瞬间。新入驻/新完善可用性档案的美容师匹配不到已存在的开放请求。冷启动期这会放大"发了请求没人报价"的死亡体验，且与 pet-fit 方向（帮这只宠物找到最合适的人）自相矛盾——最合适的人可能是昨天刚注册的。
**改进：** 补匹配 RPC（美容师激活/可用性变更时对存量开放未过期请求执行，复用现有 SQL 匹配函数与唯一约束），或随过期定时任务周期兜底；用 TestOps matching 场景验证不重复、不复活已 dismiss 的匹配。

**⑥ 邮箱确认流程是注册转化率杀手。**
注册 → 邮箱 → 浏览器确认 → 手动回 App 重新登录；且默认 SMTP 限流撑不住公测。
**改进：** Universal Link 深链自动完成 + 生产 SMTP。

**⑦ 取消后的断头路。**
取消不重开请求/报价的语义是审慎的（不动），但被取消的客户必须从零重走五步向导。
**改进：** "再次发布"一键预填原请求（含已持久化的地址/照片）进入向导确认步。

**⑧ 交接卡已读仍是本机状态。**
换设备/重装后已确认的交接卡重现。应落库为客户级持久状态。

### P2 — 应在 1.0 收敛的毛边

- **无生产遥测**：Debug Console 是本地诊断，正式版仍是"裸奔"。至少接崩溃上报 + 关键漏斗埋点（发布/报价/接受/完成）。
- **大文件技术债**：`CustomerRequestsView.swift` 与 `GroomerProfileManagementView.swift` 已被项目自己列为上下文风险，1.0 前做一次专项拆分，降低后续迭代成本与回归风险。
- **评价单向且无审核**：1.0 可接受，但文案上明确规则；美容师回复放 1.x。
- **`main` 分支落后**：当前基线分支远超 `main`。发布前必须有一次显式的分支合并/对账任务，否则 1.0 无法从可追溯的主干出包。

### 明确建议不做进 1.0 的（与产品简报推迟清单一致）

支付/退款、订阅、公开美容师目录、直接时段预订、地图优先、AI/ML 推荐、多宠物请求、收藏夹、聊天附件/已读回执、审核/纠纷、管理后台、社交登录。1.0 定价策略：**平台不碰钱**，报价仅信息展示、线下结算、App 内免责声明。

---

## 4. 未来方向规划

### 4.1 版本路线图

| 版本 | 主题 | 内容 |
|---|---|---|
| **1.0（本计划目标）** | 可信、完整、可上架 | 修复 P0/P1：合规三件套（删除/隐私/政策）、推送 + Realtime、Offers tab、过期转换、补匹配、深链注册、再次发布、交接已读落库、遥测、大文件拆分、main 对账 |
| **1.1** | 履约与信任 | 美容师回复评价、改期/重新预约完整流程、请求编辑（open 态）、聊天附件（bucket 契约已预留）、应用内通知中心、fit 解释的客户端展示强化 |
| **1.2** | 供给侧增长 | 美容师日历深化（当前已有可用窗口/休假/日容量基础）、证据看板对外展示化、评分与完单率参与排序权重的透明化 |
| **2.0** | 商业化 | 支付托管、平台抽佣或订阅、纠纷流程、Admin 后台（此时才引入 Admin 角色与审核） |

### 4.2 北极星与护栏指标（建议 1.0 起埋点）

- **北极星：** 每周完成的预约数。
- 供需健康：请求→首个报价中位时长；报价率；接受率；**匹配理由的报价转化差异**（pet-fit 证据是否真的提升转化——这是本产品独有的可验证假设）。
- 体验护栏：请求过期率；取消率；崩溃率。

---

## 5. 质量与测试现状

两层测试体系已经成型，是本项目的显著优势：

- **Swift Testing 单测 221 个 `@Test`**（参数化展开后运行约 224 例）：CustomerRequests 48、GroomerProfile 43、AppEntry 32、Pets 26、Booking 22、GroomerRequest 13、PetFitTaxonomy 12、Chat 12、CustomerProfile 9、DebugEvent 4；Store 行为、Fake 注入、错误路径风格统一。
- **UI 测试 3 个**（启动冒烟 + TestOps 启动配置）。
- **TestOps Node 套件 24 个**：种子解析、安全门控、计划/矩阵生成、脱敏、清理规划、凭据类型防错、匹配评估投影；远程执行有显式授权 + 标签清理门控。
- **远程自动化证据**：`smoke5` 后端全生命周期 5/5、`matching_baseline` 8/8、清理零残留。

主要缺口：模型解码契约测试不系统、时区/DST 边缘缺失、状态机全矩阵缺失、Chat/Booking 错误路径偏薄、UI 旅程测试少、无生产崩溃遥测。1.0 计划的测试专项（见配套计划第 6 节）目标是 **221 → ≥300 单测** 并把过期/补匹配/容量边界纳入 TestOps 回归。

---

## 6. 结论

这条分支上的 Groomly 已经不是"MVP 加皮肤"，而是一个**带可解释匹配引擎、双层自动化测试体系和严肃工程运维纪律**的准生产级产品。我在旧基线上指出的两个最严重体验缺口（图片不可见、向导字段丢失）已被扎实解决，测试规模翻了 2.5 倍还建立了远程自动化回归——这个团队的执行质量值得信任。

剩下的差距高度集中且清晰：**合规三件套（账号删除/隐私清单/政策页）是提审生死线；通知体系是市场流动性生死线**；再加上 Offers tab、过期转换、补匹配三个"匹配引擎精度与用户可见性不匹配"的收口问题。这些都不是架构问题，是排期问题。

按配套的《V1.0 正式版交付任务计划表》执行（任务编号自 T-152 起，基线分支 `codex/pet-fit-structure-cleanup`），预计 **7~9 周**可达成可提审的 1.0。

---

## 7. 核实记录（2026-07-06 代码级复核）

本版对第 2~3 节全部关键声明做了逐条代码核实。核实通过项不再展开，下表仅记录修正项与最重要的证据锚点：

| 项目 | 结果 | 证据 |
|---|---|---|
| Offers tab | **修正**：`.offers` 不在 `GroomerTab.visibleCases`，tab 栏根本不显示；`FeaturePlaceholderView`（"not connected yet"）仅为不可达兜底代码。缺口本质是**能力缺失**而非可见占位 | `Features/Groomer/GroomerTab.swift`（visibleCases）、`GroomerTabView.swift:117-122` |
| 单测数量 | **修正**：`@Test` 注解共 221 个（10 个测试文件）；此前 224 为参数化展开后的运行例数口径 | `grep -rc "@Test" PetGroomerMarketplaceTests/` |
| Storage 桶 | **修正**：客户端契约桶 5 个：customer-avatars、groomer-avatars、groomer-portfolio、pet-photos、request-photos | `Core/Models/PhotoStorageBucketID.swift` |
| 代码规模 | ✅ 34,811 行 Swift（不含测试） | `find … -name "*.swift" \| xargs wc -l` |
| 迁移与 RPC | ✅ 44 个迁移；11 个 public 受控 RPC（accept_groomer_offer、cancel_booking、cancel_grooming_request、complete_booking、create_groomer_offer、create_grooming_request、create_my_profile、create_review、dismiss_request_match、get_my_groomer_pet_fit_evidence_summary、withdraw_groomer_offer） | `supabase/migrations/` |
| 假铃铛 | ✅ 空动作按钮真实存在 | `Features/Customer/Pets/CustomerPetsView.swift:101`（`notificationAction: {}`） |
| 合规缺口 | ✅ 全库无账号删除代码、无 `PrivacyInfo.xcprivacy`、无 `onOpenURL` 深链、无 APNs/UNUserNotification、无 Realtime 订阅 | 全库 grep 零命中 |
| 过期与补匹配 | ✅ 无 `pg_cron`；匹配写入仅发生在 `create_grooming_request` 内（请求创建瞬间），无任何 backfill 机制 | `migrations/20260621000444_t012_…​.sql:441` |
| 交接卡已读 | ✅ `UserDefaults` 全库仅出现于 `CustomerRequestsStore.swift`（本机态，跨设备失效） | 全库 grep |
| TestOps | ✅ Node 测试 24 个（core 10 + edge 9 + matching 5）；`smoke5` 5/5 与 `matching_baseline` 8/8 与 `CURRENT_STATE.md` 验证基线一致 | `tests/testops/`、`docs/00_memory/CURRENT_STATE.md` |
