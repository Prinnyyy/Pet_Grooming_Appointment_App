# T-001 Context Librarian Report

## 任务理解

T-001 的唯一主要任务是建立一个全新的、可构建且可测试的 iOS 18 SwiftUI 基线项目 `PetGroomerMarketplace`。本次应交付：

- Swift 6、最低 iOS 18.0 的原生 Xcode 工程。
- 真实启动状态固定为认证引导（authentication bootstrap）。
- 明确、可注入的角色路由；Customer/Groomer 壳层仅能通过显式注入、预览或测试到达，不能成为生产启动时的隐式演示路径。
- Customer 五个 Tab：Home、Requests、Bookings、Messages、Account。
- Groomer 五个 Tab：Requests、Offers、Bookings、Messages、Account。
- 少量语义化设计 token、薄 SwiftUI 壳层、单元测试与 UI smoke test。
- 构建/测试脚本适配和 durable project memory 更新。

本任务到上述基线验证结束即停止，不继续 Auth 实现、角色 onboarding 或任何市场业务纵切片。

## 相关上下文

- 当前分支为 `main`，跟踪 `origin/main`；记忆文档仍以初始化占位内容为主，尚无已验证的 Xcode 工程或构建结果。
- 工程简报第 7/8 节要求 feature-oriented 结构、薄 View、业务逻辑不进入 View，并反对大型单体 `AppModel`。T-001 只需建立能支撑该方向的最小目录和边界，不需要提前实现完整 repository/service 层。
- 第 10 节给出了两种角色的精确 Tab 集合；首版必须保持简单。
- 第 20 节规定后端最终是业务事实来源。本任务没有后端，因此不能用运行时 mock、持久化假数据或 fake success 把尚未实现的能力伪装为完成。仅 UI preview fixture 可接受。
- 第 21 节要求轻量、友好、清晰的 UI；T-001 的语义 token 和占位壳层应克制，避免复杂日历、筛选、地图和动画。
- 第 23 节 Phase 1 要求 fresh SwiftUI project、清晰结构、design tokens、navigation shell，且不得导入旧代码、旧 migrations 或旧 local AppModel。其“placeholder repositories”与“preview mock data”只能在确有基线编译需要时最小化处理；preview 数据不得进入生产运行路径。
- 第 26 节要求持续可编译、垂直小切片、无巨大文件、无 View 内业务规则、无生产 mock 回退。
- 第 27/28 节确认最终产品核心是 `Open Request → Groomer Offer → Customer Confirmation → Booking`，不是旧的 direct task-card send/reject/resend 流程。T-001 不实现这些业务，但其命名或占位 UI 不应重新引入旧流程。

## 风险

- 当前工作树非干净状态，存在明确的用户/编排器工作，任何 broad rewrite、恢复文件、清理未跟踪文件或覆盖台账都会破坏现有进度。
- `PROJECT_MEMORY.md`、`CURRENT_STATE.md`、`FEATURE_INDEX.md` 仍有大量 TODO；如果基线完成后不更新，它们会与真实仓库状态明显失配。
- 过度实现 Phase 1 的占位 repositories、运行时 demo 路由或 mock 数据，容易突破 T-001 范围并违反“真实启动为 Auth bootstrap”的约束。
- 将 Customer/Groomer 壳层做成生产 UI 可切换角色，会形成隐式 demo/backdoor；路由入口必须是显式依赖注入或 preview/test 配置。
- 新建 Xcode 工程可能出现 scheme、deployment target、Swift language mode、test host 或脚本路径不一致；必须使用仓库脚本验证，不能只依赖 Xcode UI。
- 最低系统版本和 Swift 6 并不自动等于严格并发配置正确；不要为了基线引入无关并发抽象。

## 允许/禁止范围

### 允许

- 在 `ios/` 下新增最小原生 Xcode 工程、App 入口、route/state 类型、Auth bootstrap view、两种角色 tab shell、必要的占位 view、语义 design tokens、unit/UI tests。
- 按需要小范围调整 `scripts/ios-build.sh`、`scripts/ios-test.sh` 或 `scripts/preflight.sh`，但应保持现有脚本职责，并以脚本作为最终验证入口。
- 使用 preview-only fixture；测试可通过显式 route 注入验证 Customer/Groomer 壳层。
- 完成后更新：
  - `docs/00_memory/PROJECT_MEMORY.md`：用当前产品方向、基线架构和近期优先级替换相关 TODO。
  - `docs/00_memory/CURRENT_STATE.md`：记录工程、版本、启动状态、构建/测试结果、已知风险和下一任务。
  - `docs/00_memory/FEATURE_INDEX.md`：索引 Auth bootstrap、角色路由、Customer/Groomer tabs、design tokens、tests 的实际文件与状态。
  - `docs/00_memory/WORKLOG.md`：记录 T-001 改动和验证证据。
  - `docs/00_memory/DECISION_LOG.md`：若实现中确定了 app route、依赖注入、目录或测试架构等设计决策，则记录；没有新决策时不要制造条目。
  - `docs/06_tasks/TASK_LEDGER.md`：仅在验证成功后把 T-001 更新为完成并记录检查；保留现有 T-000/T-001 用户修改。

### 禁止

- Supabase、第三方依赖、网络、持久化、真正的登录/注册、角色 onboarding、profiles/pets/requests/offers/bookings/chat/reviews 等业务功能。
- 运行时 demo data、生产 mock fallback、fake success、旧 local `AppModel`、旧代码或 migrations 导入。
- 复杂设计系统、复杂导航、业务规则进入 SwiftUI View、大型单体状态对象。
- 改动或恢复当前用户工作：
  - 保留 `Product_Architecture_Grooming_Request_Offers_Mode.md` 的现有删除状态，不恢复。
  - 保留 `docs/06_tasks/TASK_LEDGER.md` 的现有修改并基于它做最小后续更新。
  - 保留未跟踪的 `Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md`、`docs/05_workflow/agent_reports/T-001/00-task-intake.md`、`docs/06_tasks/T-001_SWIFTUI_BASELINE.md`。
- commit、push、PR 或任何远程/破坏性操作。

## 交给主代理的建议

1. 把 T-001 收敛为四个可验证面：工程配置、显式 route/auth 启动、两套 tab shell/语义 token、unit/UI smoke tests；不要顺手进入 Phase 2。
2. 让生产默认 route 始终为 Auth bootstrap；Customer/Groomer route 通过初始化参数或等价显式依赖注入提供给 previews/tests，避免运行时 demo 开关。
3. 仅建立当前壳层确实需要的目录和类型。不要为了匹配未来目录树创建空 repository/service 大全。
4. 实现前后都检查 `git status --short --untracked-files=all`，确保上述用户改动没有被覆盖或清理。
5. 最终依次运行 `./scripts/ios-build.sh`、`./scripts/ios-test.sh`、`./scripts/preflight.sh`、`git diff --check`；任何成功声明都应引用实际输出。
6. 验证成功后再更新 durable docs 与任务台账，并停止等待下一条用户指令。建议下一任务为 Phase 2 的 Auth/Role Onboarding 规划或实现，但不得在本轮提前开展。
