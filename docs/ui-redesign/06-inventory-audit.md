# UI 盘点反向审计

## 审计范围与方法

本次从源码反向核对 `00` 至 `05` 六份盘点文档。默认搜索遵守 `.rgignore`，范围为 production App/Core/DesignSystem/Features，同时定向检查 Tests/UITests/Preview/DEBUG 以防误收录。

执行的源码检索包括：

- 所有 `struct ...: View` / `ViewModifier` / `ButtonStyle`；
- 所有 Route/Destination、`NavigationLink`、`navigationDestination`；
- 所有 `.sheet`、`fullScreenCover`、`popover`、`.alert`、`confirmationDialog`；
- 所有 Button、ToolbarItem、Menu、swipeActions、contextMenu、onTapGesture、searchable、refreshable与自定义`foregroundRefreshable`；
- URL/deep link/Auth callback；
- role/participant/permission/authorization条件；
- PreviewRepository、Mock、Demo、TestOps、`#Preview`、`#if DEBUG`、unit/UI test targets。

## 覆盖情况

### 汇总数字

| 指标 | 数量 | 计数口径 | 证据 |
|---|---:|---|---|
| 正式页面/surface | 38 | `01-screen-inventory.md` 中 Root/Auth/Customer/Groomer正式条目；包含条件surface与系统确认surface | inventory表38行 |
| 顶层页面/surface | 15 | ROOT-01 + AUTH-01...04 + Customer 5 Tab Roots + Groomer 5 Tab Roots | screen inventory页面类型/启动分支 |
| Push页面 | 18 | Customer 6 + Groomer 12 个角色可达Push destination；共享类型按角色入口分别计 | navigation文档/源码destination |
| Sheet页面（唯一surface） | 4 | Pet Form、Request Wizard、Service Form、Time Off Form | 6个`.sheet`调用点映射为4个唯一页面 |
| `.sheet`调用点 | 6 | Home 2、Requests 1、Bookings 1、Groomer Account 1、Availability 1 | 源码搜索 |
| Full Screen Cover | 0 | production App/Features | 搜索无结果 |
| Popover | 0 | production App/Features | 搜索无结果 |
| Alert | 2 | Customer Request取消、Account最终删除确认 | 2个`.alert`调用点 |
| Confirmation Dialog | 2 | Account第一层删除确认、Portfolio Photo删除确认 | 2个调用点 |
| 主要用户流程 | 15 | `02-navigation-and-user-flows.md` 的“流程名称”章节 | heading计数 |
| 可复用组件条目 | 65 | `05` 总表：27个跨模块/基础设施条目 + 38个Feature内条目；组合family按一行计 | 组件表行计数 |
| production/DesignSystem View声明 | 261 | 语法搜索；包含页面、row、card、status、preview-capable类型 | `rg struct ...: View` |
| NavigationLink调用 | 16 | production App/Features | 源码搜索 |
| navigationDestination调用 | 6 | production App/Features | 源码搜索 |
| ToolbarItem调用 | 9 | production App/Features | 源码搜索 |
| Menu调用 | 8 | production App/Features | 源码搜索 |
| 自定义foreground refresh调用 | 7 | `foregroundRefreshable` | 源码搜索 |
| Preview声明 | 15 | App/Features；不含测试类 | `#Preview`搜索 |

说明：`Button {`模式至少匹配50个调用，但不是所有Button语法（还存在`Button("...")`、`Button(role:)`等），因此不把50当“按钮总数”。操作覆盖度按页面action→Store调用审计，不按Button文本计数。

### 搜索API覆盖结论

| 检查项 | 结果 | 是否已被此前文档覆盖 |
|---|---|---|
| path-based navigation / `NavigationPath` | 0 | 是，02/04明确未发现 |
| swipeActions | 0 | 是，03全局未发现项 |
| contextMenu | 0 | 是 |
| onTapGesture | 0 | 本次新增明确计数；交互通过Button/NavigationLink/DragGesture |
| searchable | 0 | 是；地址suggestions不是`.searchable` |
| system `.refreshable` | 0 | 此前“refreshable”描述容易误解；实际为自定义`foregroundRefreshable` |
| custom `foregroundRefreshable` | 7 | 04已描述生命周期；05本次补入组件表 |
| fullScreenCover / popover | 0/0 | 是 |
| deeplink/URL | 仅Auth callback与External Links | 是 |
| role/permission | Auth/profile role、booking role、participant IDs、DEBUG、notification authorization | 基本覆盖；隐藏系统授权见下文新增项 |

## 新发现的遗漏项与同步修正

### 1. Chat message event subscription（事实错误，已修正）

- 先前问题：`03-screen-functional-specs.md` 在CUS-11/GRM-09写“未发现realtime listener”。
- 源码事实：`ChatThreadView.task(id:)`调用`store.startMessageSubscription(for:)`；scene active时重载/确保订阅，background/onDisappear停止。`ChatStore`通过`ChatRepository.messageEvents`创建`Task`消费AsyncStream。
- 修正：03现已记录消息事件订阅的启动、恢复与清理；仍明确没有typing/read-receipt UI。
- 文件/类型：`Features/Chat/ChatView.swift`、`ChatStore.swift`、`Core/Repositories/ChatRepository.swift`。

### 2. Foreground refresh reusable modifier（组件遗漏，已修正）

- 先前问题：05没有把`foregroundRefreshable`当可复用行为组件列出。
- 源码事实：`Core/Infrastructure/ForegroundRefreshGate.swift`包含`ForegroundRefreshModifier`与View extension，7个production调用点。
- 修正：已加入05跨模块组件总表，状态为initial/active refresh/in-flight deduplication。

### 3. Wizard专属ButtonStyle（组件遗漏，已修正）

- 先前问题：05重复实现段提到Wizard自有style，但组件总表未列具体类型。
- 源码事实：`CustomerRequestWizardPrimaryButtonStyle: ButtonStyle`位于`CustomerRequestWizardView.swift`。
- 修正：已加入05 Feature组件表。

### 4. Feature feedback bridge family不完整（组件遗漏，已修正）

- 先前问题：05只列Customer Requests、Bookings、Chat、Groomer Profile status views。
- 源码事实：还存在`CustomerHomeStatusView`、`CustomerPetsStatusView`、`CustomerProfileStatusView`、`GroomerRequestsStatusView`、`GroomerOffersStatusView`。
- 修正：05已补全family。它们仍是Embedded Component，不新增正式页面。

### 5. 隐藏系统授权与异步副作用（新增审计项，无需改页面数量）

- Customer登录后的`AuthenticatedEntryView.task(id: activeCustomerIDForPushRegistration)`会配置/触发Customer push registration协调链。
- `CustomerPushNotificationRegistrationCoordinator`调用`UNUserNotificationCenter.requestAuthorization`，用UserDefaults保存installation ID，并通过CustomerPushNotificationRepository注册/注销device token。
- `BookingsStore`/Customer Requests Store注入`AppointmentReminderScheduler`，booking/request相关成功路径可能触发local notification reminder reconciliation。
- 这些不是独立页面或自定义permission screen；系统prompt属于隐藏System UI交互。04已记录service/persistence边界，但03的逐页表没有把系统授权prompt列成单独页面操作。
- 人工确认：首次Customer登录/首次reminder scheduling时prompt的精确时机、拒绝后UI反馈与重复请求策略需要运行时验证。

### 6. onTap/search/gesture反查

- production App/Features没有`.onTapGesture`、swipeActions或contextMenu；此前清单没有漏掉由这些API打开的隐藏页面。
- Fit size range使用DragGesture，是已记录的内嵌表单交互，不产生页面。
- 地址search使用ObservableObject suggestions + Buttons，不是Search页面。

## 文档之间的冲突

### 已解决冲突

| 冲突 | 文档 | 源码结论 | 处理 |
|---|---|---|---|
| Chat“无realtime listener” vs messageEvents subscription | 03 vs 04/源码 | 存在message event订阅；无typing/read-receipt UI | 已修正03 |
| foreground refresh被描述为行为但未列组件 | 04 vs 05 | 是可复用ViewModifier/extension | 已修正05 |
| Wizard custom primary style仅在重复实现提及 | 05内部 | 具体ButtonStyle存在且在用 | 已修正05总表 |
| status bridge family列举不完整 | 05 vs源码 | 9个Feature status桥接族 | 已修正05 |

### 仍存在但不应在本任务擅自解决的冲突

| 冲突/不一致 | 具体文件与类型 | 当前证据 | 需要人工确认 |
|---|---|---|---|
| Groomer tabs旧文档为Board/Schedule/Messages/Account | `docs/01_product/NAVIGATION_AND_FLOWS.md` vs `GroomerTab.swift` | production为Home/Requests/Schedule/Messages/Account | 是否单独更新产品导航文档；不在ui-redesign范围改 |
| Product docs称realtime out of scope，但Chat有messageEvents | `NAVIGATION_AND_FLOWS.md`、`ChatStore.startMessageSubscription` | message事件刷新存在；typing/read receipt仍无 | “realtime”定义是否需产品文档澄清 |
| `AppEntryRoute`含customer/groomer/onboarding直接case | `AppRootView.swift` | 正式`BeckonApp`只传authentication；其他case主要Preview | 是否保留这些route cases作为Preview API |
| Groomer booking notification带ID但未开detail | `GroomerNotificationRoute.bookings(bookingID:)`、`GroomerTabView.openNotificationRoute` | ID未消费，只切Schedule | 产品是否期待deep detail；不可在UI任务顺手改变 |
| Groomer generic account content含删除账户能力但正式入口优先sign out | `AuthenticatedEntryView.genericAccountContent`、`GroomerAccountHomeView.signOutControl` | 普通Groomer看不到generic content link | Groomer是否应有delete account入口 |
| system permission prompt时机/反馈 | Push coordinator、AppointmentReminderScheduler | 有requestAuthorization调用，无自定义permission页面 | 需设备/模拟器运行确认 |

### 页面名称与计数口径澄清

- `BookingsView(role: .customer/.groomer)`、`BookingDetailView`、`ChatConversationsView`、`ChatThreadView`是共享SwiftUI类型，但Customer/Groomer使用不同role、数据scope和操作，因此inventory按角色页面分别记录，不是重复实现错误。
- GRM-10由`GroomerProfileManagementView`容器和`GroomerAccountHomeView`内容共同组成，是一个Tab Root，不是两个页面。
- CUS-14不是独立Navigation destination，而是CUS-12内的Confirmation Dialog + Alert surface；38的口径是“正式页面/surface”，不是“38个独立View types”。
- AUTH-04是`@ViewBuilder`条件surface而不是命名View type；因用户可见且有Retry/Sign Out而保留。
- 6个`.sheet`调用点只对应4个唯一Sheet页面；Request Wizard被3个父页面复用。

## 先前文档未覆盖或只部分覆盖的交互清单

| 项目 | 覆盖状态 | 结论/证据 |
|---|---|---|
| session async stream | 04覆盖 | `AuthSessionRepository.sessionStateChanges` |
| message event AsyncStream | 原03错误、04部分覆盖；现已修正 | `ChatRepository.messageEvents` |
| foreground scene refresh deduplication | 04覆盖、05现补组件 | `ForegroundRefreshGate` |
| push permission/device token | 04覆盖边界；03逐页未单列 | Authenticated Entry task + coordinator |
| local appointment reminder permission | 04覆盖service；03未单列 | `AppointmentReminderScheduler` |
| Reduce Motion | 03 AUTH-02覆盖，05动画说明 | AuthenticationView environment |
| Debug/TestOps UI | 01/02排除，05仅组件证据 | `#if DEBUG`；没有误收入正式页面 |
| Preview repositories | 00/01排除 | Pets/Requests/Bookings/Chat/Profile Preview repositories均只用于Preview |
| system photo picker | 02/03覆盖 | 多个PhotosPicker；不是自定义页面 |
| External Links | 02/03/05覆盖 | Account release/support Links |

## 完整性判断

| 维度 | 评级 | 判断依据 | 剩余风险 |
|---|---|---|---|
| 页面覆盖度 | 高 | 261个View声明已从App入口反向分类；38个正式surface全部有父调用或条件分支；Preview/DEBUG独立排除 | 系统permission prompt不计自定义页面；口径需保持“surface” |
| 导航覆盖度 | 高 | 16个NavigationLink、6个navigationDestination、6个sheet调用、2 Alert、2 Confirmation Dialog、role tab程序化route均已映射 | booking notification ID未消费是产品不确定项 |
| 操作覆盖度 | 中 | 03逐页列主要action→Store，Button/Toolbar/Menu与隐藏API已反查 | 261个内嵌View中的微交互未逐Button逐行列；permission prompt运行时反馈待验 |
| 页面状态覆盖度 | 中 | 03统一检查14类状态，04记录明确enum和条件逻辑转换 | partial error、network/permission映射多为通用error；实际动画/dismiss需运行验证 |
| 数据依赖覆盖度 | 高 | 04覆盖38页、全部repository protocols、cache/UserDefaults/notifications/async stream | Supabase schema/RLS未在本阶段读取；符合UI盘点边界 |
| 组件覆盖度 | 高 | DesignSystem、ButtonStyle/ViewModifier、Feature组件、tokens/assets/SF Symbols均扫描；本次补2个遗漏及status family | 组件表按语义family而非261个View逐一列，局部微组件仍由声明搜索清单兜底 |

## 无新增正式页面的依据

本轮没有发现需要加入`01-screen-inventory.md`的新正式页面：

- 所有NavigationLink/navigationDestination目标均已映射到现有38个surface或DEBUG-only DebugPanel。
- 所有Sheet目标均属于4个已知Sheet页面。
- 所有Alert/Confirmation Dialog已记录。
- 没有fullScreenCover、popover、swipe/context/tap/search触发的隐藏destination。
- 未被inventory列为页面的View声明均可归为container、row/card/field/status/feedback/Preview或DesignSystem primitive。

## 人工确认清单

1. 在真实Customer首次登录上确认push authorization prompt时机、拒绝/稍后行为和可见反馈。
2. 在booking reminder首次触发时确认notification permission和失败反馈。
3. 在前台/后台切换Chat Thread时确认subscription不重复且onDisappear停止。
4. 确认产品所称“realtime out of scope”是否应改为“无typing/read receipts；message event refresh已实现”。
5. 确认Groomer是否需要delete account入口。
6. 确认Groomer booking notification是否应直接打开booking detail。
7. 决定是否单独修复`docs/01_product/NAVIGATION_AND_FLOWS.md`的旧Groomer tabs描述。

## 本阶段停止点

本轮完成反向审计并同步修正文档事实；未修改任何production Swift、配置、资源或测试，也未运行App、构建或测试。
