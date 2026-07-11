# SwiftUI UI 功能盘点：任务与项目边界

## 任务定义

- 任务编号：T-261（依据 `docs/00_memory/CURRENT_STATE.md` 与 `docs/06_tasks/TASK_LEDGER.md` 的下一可用编号）。
- 任务性质：只读盘点准备 / Quick 文档任务。
- 当前阶段交付物：仅本文档。
- 当前阶段目标：建立后续 UI 功能盘点的代码证据范围、分类规则与检查顺序。
- 当前阶段不做：UI 评价、UI 优化、代码修改、缺陷修复、Figma 原型、构建或测试。
- 范围限制：除本文档外，不修改 Swift、配置、资源、测试或其他项目文档。因该限制，本阶段不更新任务台账、工作日志和当前状态。

## 证据与判定规则

1. 生产可达性以正式 App 组合和调用链为主：`BeckonApp` → `AppRootView` → Auth 状态 → role shell → tab/root destination → push/sheet/alert。
2. 文件名、类型名、导航标题和页面外观只能作为检索线索，不能单独证明正式功能或可达性。
3. 页面功能、操作和状态必须继续追溯到具体 View、Store、repository protocol、model 或调用方法。
4. `#Preview`、`PreviewRepository`、测试 target、TestOps 和 DEBUG-only 入口不得作为生产页面或生产功能证据。
5. 后续记录按以下类型区分：
   - 用户可直接访问的正式页面；
   - 正式页面内嵌子视图；
   - Sheet、Popover、Alert、Confirmation Dialog 等临时界面；
   - 仅供 Preview、Mock、Demo 或测试使用的页面/状态。
6. 证据不足时使用固定标记：`待确认`、`未发现实现`、`仅根据调用关系推断`。

## 项目整体架构概览

项目是 SwiftUI iOS marketplace App。正式依赖链在架构文档和代码中表现为：

```text
SwiftUI View
→ Feature Store / State Coordinator
→ Repository Protocol
→ Supabase Repository
→ Supabase Auth / Postgres RPC 或 Data API / Storage
```

代码分层证据：

- App 组合：`ios/Beckon/Beckon/App/`，由 `AppComposition` 创建生产 repositories、Auth store 和运行诊断依赖。
- UI 与功能状态：`ios/Beckon/Beckon/Features/`。
- 稳定业务模型与 repository protocols：`ios/Beckon/Beckon/Core/Models/`、`Core/Repositories/`。
- Supabase 实现和本地基础设施：`ios/Beckon/Beckon/Core/Infrastructure/`。
- 跨功能 UI tokens/primitives：`ios/Beckon/Beckon/DesignSystem/`。
- 正式数据源：Auth session 来自 Supabase Auth；profiles、pets、requests、matches、offers、bookings、conversations、messages、reviews 等以服务端数据为准。表单草稿、选择、临时图片和可丢弃缓存可以是本地状态（见 `docs/02_architecture/ARCHITECTURE.md`、`DATA_FLOW.md`）。

本阶段没有读取或验证 Supabase schema；后续 UI 盘点只记录 UI 通过 repository 暴露出的能力，不据此推断未读到的后端能力。

## App 启动入口

正式入口是 `ios/Beckon/Beckon/App/BeckonApp.swift` 中的 `@main struct BeckonApp: App`。

已确认的启动链：

1. `BeckonApp` 构造 `AppComposition`。
2. `WindowGroup` 创建 `AppRootView(route: .authentication, ...)`。
3. `AppComposition` 加载 `SupabaseConfiguration`，创建 production repositories 和 `AuthenticationStore`；配置失败时保留 `AuthenticationBootstrapState.configurationError`。
4. `BeckonApp.onOpenURL` 将 URL 交给 `AuthenticationStore.handleAuthCallback(_:)`。
5. `AuthenticationGateView` 和 `AuthenticatedEntryView` 根据 Auth session、profile lookup 与权威角色进入登录、角色 onboarding、Customer shell 或 Groomer shell。

`AppRootView` 里的 `.customer`、`.groomer` 直接分支同时被 `#Preview` 使用；正式启动固定传入 `.authentication`，因此不能仅因这些分支存在就把它们认定为绕过 Auth 的生产入口。

## 根视图和顶层导航结构

`AppRootView` 依据 `AppEntryRoute` 支持四类根内容：

- `.authentication`：依赖齐全时显示 `AuthenticationGateView`，否则显示 `AuthenticationBootstrapView`；
- `.roleOnboarding`：需要注入 authenticated onboarding 内容；当前直接构造路径主要见 Preview，正式 onboarding 由 `AuthenticatedEntryView` 的状态分支进入；
- `.customer`：`CustomerTabView`；
- `.groomer`：`GroomerTabView`。

正式 authenticated entry 由 `AuthenticatedEntryStore.state` 驱动：`.loading`、`.onboarding`、`.customer(profile)`、`.groomer(profile)`、`.failure(message)`。这说明启动和角色路由是显式状态机，不是依据 UI 选择器或本地角色开关。

### Customer 顶层导航

`CustomerTabView` 使用一个 `TabView`，并为每个 tab 各自创建 `NavigationStack`。`CustomerTab.allCases` 的生产代码定义五个 tab：

| Tab | 根内容（依赖齐全时） | 主要代码证据 |
|---|---|---|
| Home | `CustomerPetsView` | `CustomerTabView.destination(for:)` |
| Requests | `CustomerRequestsView` | 同上 |
| Bookings | `BookingsView(role: .customer)` | 同上 |
| Messages | `ChatConversationsView(role: .customer)` | 同上 |
| Account | authenticated account content；正式 customer 组合中为 `CustomerAccountView` | `AuthenticatedEntryView.customerAccountContent(for:)` 与 `CustomerTabView` |

跨 tab 路由由 `CustomerTabView` 的本地状态协调：Home 的 active request 可切换到 Requests；booking chat 可设置 `focusedConversationBookingID` 后切换到 Messages。Home 和 Messages 分别显示 notification/message badge。

### Groomer 顶层导航

`GroomerTabView` 同样使用一个 `TabView`，每个 tab 各有 `NavigationStack`。`GroomerTab.allCases` 的生产代码定义五个 tab：

| Tab | 根内容（依赖齐全时） | 主要代码证据 |
|---|---|---|
| Home | `GroomerHomeView` | `GroomerTabView.destination(for:)` |
| Requests | `GroomerRequestsView` | 同上 |
| Schedule（枚举 case 为 `bookings`） | `BookingsView(role: .groomer)` | 同上 |
| Messages | `ChatConversationsView(role: .groomer)` | 同上 |
| Account | `GroomerProfileManagementView` | 同上 |

跨 tab 路由由 `GroomerTabView` 的 `selection`、`requestsRoute`、`requestedProfileRoute` 和 `focusedConversationBookingID` 协调。Home 可进入 Requests 的 Matches/Offers、Schedule、Messages、Availability；通知路由可进入 Requests、Schedule 或指定 booking 的 message thread。

## 可能包含 UI 页面和组件的目录

后续盘点优先检查：

- `ios/Beckon/Beckon/App/`：启动、根路由、依赖组合；其中并非所有文件都是 UI。
- `ios/Beckon/Beckon/Features/Auth/`：启动 gate、登录/注册、role onboarding、authenticated account 与 entry 状态。
- `ios/Beckon/Beckon/Features/Customer/`：Customer tabs、Home/Pets、Requests、Notifications、Profile/Account。
- `ios/Beckon/Beckon/Features/Groomer/`：Groomer tabs、Home、Requests/Offers、Notifications、Profile/Services/Availability/Fit/Evidence/Portfolio。
- `ios/Beckon/Beckon/Features/Bookings/`：Customer Bookings 与 Groomer Schedule 共用页面、booking detail、review UI。
- `ios/Beckon/Beckon/Features/Chat/`：conversation list、thread、composer 和 read-only states。
- `ios/Beckon/Beckon/DesignSystem/`：共享按钮、card、form、feedback、loading/empty/error、image 等内嵌 primitives；默认不作为独立页面。
- `ios/Beckon/Beckon/Features/Debug/`：DEBUG/TestOps 诊断 UI，必须单独验证生产可达性，不能计入普通用户正式页面。

辅助证据目录：

- `Core/Models/`：路由、角色、业务状态和显示数据含义；
- `Core/Repositories/`：UI 可以发起的读取和 mutation contract；
- `Core/Infrastructure/`：正式 repository 实现和图片/缓存行为，仅在确认 UI 状态来源时定向读取。

## 当前发现的功能模块

以下仅表示已经发现正式组合或生产 View 调用线索；页面、入口、操作和状态仍需在后续逐模块盘点：

- App 配置与阻塞状态；
- Auth session 恢复、登录/注册、Auth callback 与登出；
- 角色 onboarding 与 customer/groomer 权威角色路由；
- Customer Home/Pets、pet form/photo、request wizard；
- Customer Requests、request detail、offers、accept/cancel/republish 与 booking handoff；
- Customer Bookings、booking detail、cancel、chat handoff、completed-booking review；
- Customer Messages、conversation list、thread、pagination/send/read-only states；
- Customer Notifications；
- Customer Account/Profile、avatar/address、release/support links、account danger actions；
- Groomer Home、摘要、next booking、notification entry 与 workspace shortcuts；
- Groomer Requests 的 Matches/Offers 分段、request/match detail、offer create/withdraw/dismiss；
- Groomer Schedule、booking detail、cancel/complete 与 chat handoff；
- Groomer Messages 与 Notifications；
- Groomer Account/Profile；
- Groomer Services、Availability、Time Off；
- Groomer Fit Signals、Evidence、Portfolio 与图片管理；
- 全局 loading/empty/error/progress/notice feedback；
- DEBUG/TestOps Debug Console（非普通生产页面，正式可达性待确认）。

未在本阶段把任何 repository 方法直接等同为用户可见操作；后续必须同时找到 UI 入口和调用链。

## 使用的状态管理方式

当前代码主要使用 Swift Observation：

- Feature Stores 多为 `@Observable final class`，例如 `AuthenticationStore`、`AuthenticatedEntryStore`、`CustomerPetsStore`、`CustomerRequestsStore`、`BookingsStore`、`ChatStore`、`GroomerHomeStore`、`GroomerRequestsStore`、`GroomerOffersStore`、`GroomerProfileStore` 和 notifications stores。
- 根或 feature View 通常通过 `@State` 持有 store；子视图使用 `@Bindable` 绑定 store 字段。
- tab selection、focused IDs、sheet/alert flags、表单临时值和 route 值使用 `@State`/`Binding`。
- 跨层 UI 服务通过 Environment 注入，例如 debug recorder 与 `BeckonFeedbackCenter`。
- 地址搜索仍可见 `ObservableObject` + `@Published` + `@StateObject` 的局部使用（`BeckonAddressSearch` 及 profile form）。
- repository protocol 通过 initializer 注入 Store/View；生产具体实现由 `AppComposition` 创建。
- 服务端记录不是本地 Store 的永久事实；Store 在操作后刷新 repository 数据。具体每屏 loading/content/empty/error/submitting 状态需后续逐 Store 记录。

## 使用的导航方式

- 根路由：`AppRootView` 对 `AppEntryRoute` 的 switch，加上 Auth/entry stores 的状态 switch。
- 角色主导航：Customer/Groomer 各一个 `TabView`，每个 tab 各自拥有 `NavigationStack`。
- 层级页面：`NavigationLink` 与 `.navigationDestination(item:/isPresented:)`。
- 跨 tab 深链式协调：tab shell 保存 focused ID 或 route state，再切换 selection。
- 临时界面：已发现 `.sheet`、`.alert`、`.confirmationDialog`；图片选择使用 `PhotosPicker`。
- 本阶段静态搜索未发现生产 Feature 中的 `NavigationSplitView` 或 `fullScreenCover`；应标记为“未发现实现”，而不是断言项目绝无此类界面。
- 本阶段静态搜索未发现 Feature 中的 `.popover` 调用；标记为“未发现实现”。

## 正式盘点范围

后续 UI 功能盘点应覆盖：

1. 从正式 App 启动可达的 blocking/loading/error、signed-out、onboarding 和 authenticated role states。
2. Customer 与 Groomer 的每个正式 tab root。
3. 每个 root 可触达的 push destination、sheet、alert、confirmation dialog 和系统 picker。
4. 每个界面的用户操作入口、调用的 Store 方法、对应 repository contract、mutation 后刷新方式。
5. 每个界面的 loading、empty、content、error、submitting、disabled、pagination、read-only 等可见状态。
6. 跨 tab 跳转、focused IDs、notification routes、booking/chat handoff。
7. shared components 仅在它们影响多个正式页面的可见状态或交互时记录，并标注为“内嵌子视图/共享组件”。
8. DEBUG/Preview/Test 页面作为排除审计单独记录，防止误计为正式页面。

## 明确排除的文件类型与内容

- `ios/Beckon/BeckonTests/**`、`ios/Beckon/BeckonUITests/**`：测试证据可用于佐证调用，但不计为正式页面。
- `#Preview` block、`PreviewRepository`、preview fixtures、preview-only route/content。
- TestOps launch arguments、TestOps driver、seed profiles、test resource Markdown。
- `#if DEBUG` 下的 quick login、debug wrappers、Debug Console：除非后续代码证明它是普通生产构建的用户路径，否则不列入正式页面。
- Mock、Demo、fixture、placeholder 仅在正式组合实际可达时记录；不能因类型存在就视为已实现功能。
- `FeaturePlaceholderView` 不证明业务功能已连接；若生产依赖缺失路径可达，只记录为 fallback/placeholder 状态。
- Xcode 工程元数据、assets、配置、entitlements、scripts、backend migrations 和 Supabase schema，不作为 UI 页面清单；仅在解释正式 target、资源或状态来源时定向引用。
- `docs/09_frozen/**`、历史 task records、旧设计导出/HTML、截图和历史产品 brief，不作为当前实现事实。

## 后续盘点顺序

1. 启动与 Auth：`BeckonApp`、`AppRootView`、`AuthenticationGateView`、`AuthenticationView`、`AuthenticatedEntryView/Store`、`RoleOnboardingView`。
2. Customer shell：`CustomerTab`、`CustomerTabView`，先画清五个 tab 与跨 tab route state。
3. Customer Home/Pets/Notifications，再盘点 pet form 与 request wizard sheets。
4. Customer Requests：列表、detail、offers、wizard、cancel alert、booking handoff。
5. Customer Bookings 与 Reviews。
6. Customer Messages/thread 和 Account/Profile/danger actions。
7. Groomer shell：`GroomerTab`、`GroomerTabView`，先画清五个 tab、requests/profile routes 与 notification routes。
8. Groomer Home 与 Notifications。
9. Groomer Requests/Matches/Offers 和 detail/mutation flows。
10. Groomer Schedule/booking detail 与 Messages/thread。
11. Groomer Account/Profile、Services、Availability/Time Off、Fit Signals/Evidence、Portfolio。
12. 最后反向审计所有 `NavigationLink`、`navigationDestination`、sheet/alert/dialog/picker 和 shared feedback primitives，查漏并分类。
13. 单独审计 Preview/DEBUG/Test/placeholder，确认没有被误收入正式页面清单。

## 当前不确定事项

- **待确认**：`docs/01_product/NAVIGATION_AND_FLOWS.md` 的 Groomer tabs 仍写为 Board、Schedule、Messages、Account，而当前 `GroomerTab` 与 `GroomerTabView` 明确为 Home、Requests、Schedule、Messages、Account。后续以生产代码为实现事实，同时保留文档冲突。
- **待确认**：`AppRootView.route` 的 `.roleOnboarding`、`.customer`、`.groomer` 直接入口在正式 runtime 是否存在除 Preview/外部注入外的调用者；当前正式 `BeckonApp` 固定从 `.authentication` 启动。
- **仅根据调用关系推断**：Customer Account 的正式内容为 `CustomerAccountView`、Groomer Account 的正式内容为 `GroomerProfileManagementView`；后续需完整核对 `AuthenticatedEntryView` 的 content factory 与每个 destination。
- **待确认**：Debug Console 是否仅由 DEBUG/TestOps 的 authenticated account link 进入，以及 release build 中是否完全不可达。
- **待确认**：Notifications 页面所有入口。Customer Home 已发现 `navigationDestination`，Groomer Home 已发现 notification link；还需核对 account 或其他入口。
- **待确认**：所有页面的精确数据状态枚举、错误恢复、分页终点、按钮禁用和重复提交保护；本阶段只确认 Store 模式，没有逐方法盘点。
- **待确认**：`FeaturePlaceholderView` 在真实配置成功且 authenticated 依赖完整的生产流程中是否存在可触达场景。
- **未发现实现**：Feature 生产代码中的 `NavigationSplitView`、`fullScreenCover` 和 `.popover`；后续反向搜索时再确认。
- **未发现实现**：运行时 Demo mode。`docs/02_architecture/PREVIEW_AND_TEST_FIXTURES.md` 明确声明 production 不允许 fixture fallback；仍需在最终排除审计中用代码验证。
- **待确认**：部分类型虽定义在生产 target 文件中但为 `private` 内嵌组件，后续必须依据调用位置区分页面与组件，不能按 `struct ...: View` 数量生成页面数。

## 本阶段停止点

本文档只建立盘点任务、证据规则、项目边界和执行顺序。尚未创建全量页面表、导航图、操作矩阵、数据状态矩阵或 Figma 原型；这些属于后续独立盘点任务。
