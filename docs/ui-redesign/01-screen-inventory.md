# SwiftUI 正式页面清单

## 盘点口径

本文从生产入口 `BeckonApp` 反向验证可达性，调用链为：`BeckonApp` → `AppRootView` → `AuthenticationGateView` / `AuthenticatedEntryView` → role `TabView` → `NavigationLink` / `navigationDestination` / sheet。表中“正式页面”表示 production authenticated/signed-out 路径能够呈现的用户可见 surface；不是按 `View` 声明数量统计。

置信度定义：高＝找到生产父调用、进入条件和具体类型；中＝生产可达，但部分行为由闭包、可选依赖或私有子类型承担；低＝仅发现声明或 Preview/Test 调用。`Alert` 和 `Confirmation Dialog` 不在允许的页面类型枚举内，因此统一归为 `Utility`，并明确其临时界面性质。

## 完整页面总表

| 页面 ID | 页面名称 | SwiftUI 类型 | 文件路径 | 所属模块 | 页面类型 | 主要入口 | 是否正式页面 | 置信度 |
|---|---|---|---|---|---|---|---|---|
| ROOT-01 | App 根状态容器 | `AppRootView` | `ios/Beckon/Beckon/App/AppRootView.swift` | App | Root | `BeckonApp.WindowGroup` | 是 | 高 |
| AUTH-01 | 配置/启动阻塞页 | `AuthenticationBootstrapView` | `Features/Auth/AuthenticationBootstrapView.swift` | Auth | Utility | `AppRootView` 依赖不完整 | 是 | 高 |
| AUTH-02 | 登录与注册 | `AuthenticationView` | `Features/Auth/AuthenticationView.swift` | Auth | Authentication | `AuthenticationGateView` signed-out 分支 | 是 | 高 |
| AUTH-03 | 角色与资料建立 | `RoleOnboardingView` | `Features/Auth/RoleOnboardingView.swift` | Auth | Onboarding | `AuthenticatedEntryView.state == .onboarding` | 是 | 高 |
| AUTH-04 | Profile 加载失败 | `AuthenticatedEntryView.loadFailureView(message:)` | `Features/Auth/AuthenticatedEntryView.swift` | Auth | Utility | authenticated profile lookup failure | 是 | 高 |
| CUS-01 | Customer Home | `CustomerPetsView` | `Features/Customer/Pets/CustomerPetsView.swift` | Customer Home/Pets | Tab Root | Customer Home tab | 是 | 高 |
| CUS-02 | Customer Notifications | `CustomerNotificationsView` | `Features/Customer/Notifications/CustomerNotificationsView.swift` | Notifications | List | Home notification button | 是 | 高 |
| CUS-03 | Pet 创建/编辑表单 | `CustomerPetFormView` | `Features/Customer/Pets/CustomerPetsView.swift` | Pets | Sheet | Home pet actions / wizard add-pet handoff | 是 | 高 |
| CUS-04 | Grooming Request Wizard | `CustomerRequestWizardView` | `Features/Customer/Requests/CustomerRequestWizardView.swift` | Requests | Sheet | Home、Requests、Bookings 的 create/republish | 是 | 高 |
| CUS-05 | Customer Requests | `CustomerRequestsView` | `Features/Customer/Requests/CustomerRequestsView.swift` | Requests | Tab Root | Customer Requests tab | 是 | 高 |
| CUS-06 | Customer Request Detail | `CustomerRequestDetailView` | `Features/Customer/Requests/CustomerRequestDetailView.swift` | Requests | Detail | Requests dashboard/timeline links | 是 | 高 |
| CUS-07 | Customer Offer Detail | `CustomerOfferDetailView` | `Features/Customer/Requests/CustomerRequestDetailView.swift` | Offers | Detail | Request Detail offer row | 是 | 高 |
| CUS-08 | Customer Bookings | `BookingsView`（role `.customer`） | `Features/Bookings/BookingsView.swift` | Bookings | Tab Root | Customer Bookings tab | 是 | 高 |
| CUS-09 | Customer Booking Detail | `BookingDetailView`（role `.customer`） | `Features/Bookings/BookingsView.swift` | Bookings/Reviews | Detail | Bookings row 或 request booking handoff | 是 | 高 |
| CUS-10 | Customer Messages | `ChatConversationsView`（role `.customer`） | `Features/Chat/ChatView.swift` | Chat | Tab Root | Customer Messages tab | 是 | 高 |
| CUS-11 | Customer Chat Thread | `ChatThreadView`（private） | `Features/Chat/ChatView.swift` | Chat | Detail | conversation row / focused booking route | 是 | 高 |
| CUS-12 | Customer Account | `CustomerAccountView` | `Features/Customer/Profile/CustomerProfileSettingsView.swift` | Account | Tab Root | Customer Account tab | 是 | 高 |
| CUS-13 | Customer Profile Settings | `CustomerProfileSettingsView`（private） | `Features/Customer/Profile/CustomerProfileSettingsView.swift` | Account/Profile | Settings | Customer Account menu | 是 | 高 |
| CUS-14 | 删除账户双重确认 | `AccountDangerActions` + system dialogs | `Features/Auth/AuthenticatedAccountView.swift` | Account/Auth | Utility | Customer Account danger actions | 是 | 高 |
| GRM-01 | Groomer Home | `GroomerHomeView` | `Features/Groomer/Home/GroomerHomeView.swift` | Groomer Home | Tab Root | Groomer Home tab | 是 | 高 |
| GRM-02 | Groomer Notifications | `GroomerNotificationsView` | `Features/Groomer/Notifications/GroomerNotificationsView.swift` | Notifications | List | Home bell | 是 | 高 |
| GRM-03 | Groomer Requests | `GroomerRequestsView` | `Features/Groomer/Requests/GroomerRequestsView.swift` | Requests/Offers | Tab Root | Groomer Requests tab / Home routes | 是 | 高 |
| GRM-04 | Groomer Request Detail / Create Offer | `GroomerRequestDetailView`（private） | `Features/Groomer/Requests/GroomerRequestsView.swift` | Requests/Offers | Create | match row / focused request route | 是 | 高 |
| GRM-05 | Groomer Offer Detail | `GroomerOfferDetailView` | `Features/Groomer/Offers/GroomerOffersView.swift` | Offers | Detail | Offers segment row / focused offer route | 是 | 高 |
| GRM-06 | Groomer Schedule | `BookingsView`（role `.groomer`） | `Features/Bookings/BookingsView.swift` | Bookings | Tab Root | Groomer Schedule tab | 是 | 高 |
| GRM-07 | Groomer Booking Detail | `BookingDetailView`（role `.groomer`） | `Features/Bookings/BookingsView.swift` | Bookings | Detail | Schedule appointment row | 是 | 高 |
| GRM-08 | Groomer Messages | `ChatConversationsView`（role `.groomer`） | `Features/Chat/ChatView.swift` | Chat | Tab Root | Groomer Messages tab | 是 | 高 |
| GRM-09 | Groomer Chat Thread | `ChatThreadView`（private） | `Features/Chat/ChatView.swift` | Chat | Detail | conversation row / notification booking route | 是 | 高 |
| GRM-10 | Groomer Account | `GroomerProfileManagementView` + `GroomerAccountHomeView` | `Features/Groomer/Profile/GroomerProfileManagementView.swift`; `GroomerProfileAccountView.swift` | Groomer Profile | Tab Root | Groomer Account tab | 是 | 高 |
| GRM-11 | Edit Groomer Profile | `GroomerProfileEditorView` | `Features/Groomer/Profile/GroomerProfileFormView.swift` | Groomer Profile | Edit | Groomer Account menu | 是 | 高 |
| GRM-12 | Services | `GroomerServicesEditorView` | `Features/Groomer/Profile/GroomerServicesEditorView.swift` | Groomer Services | Settings | Groomer Account menu | 是 | 高 |
| GRM-13 | Service 创建/编辑表单 | `GroomerServiceFormView` | `Features/Groomer/Profile/GroomerServicesEditorView.swift` | Groomer Services | Sheet | Services add/edit actions | 是 | 高 |
| GRM-14 | Availability | `GroomerAvailabilityEditorView` | `Features/Groomer/Profile/GroomerAvailabilityEditorView.swift` | Availability | Settings | Account menu 或 Home deep route | 是 | 高 |
| GRM-15 | Add Time Off | `GroomerTimeOffFormView`（private） | `Features/Groomer/Profile/GroomerAvailabilityEditorView.swift` | Availability | Sheet | Availability add-time-off action | 是 | 高 |
| GRM-16 | Fit Signals | `GroomerFitSignalsEditorView` | `Features/Groomer/Profile/GroomerFitSignalsEditorView.swift` | Pet Fit | Settings | Groomer Account menu | 是 | 高 |
| GRM-17 | Evidence | `GroomerEvidenceDashboardView` | `Features/Groomer/Profile/GroomerFitSignalsEditorView.swift` | Pet Fit Evidence | Settings | Groomer Account menu | 是 | 高 |
| GRM-18 | Portfolio | `GroomerPortfolioEditorView` | `Features/Groomer/Profile/GroomerPortfolioEditorView.swift` | Portfolio | Settings | Groomer Account menu | 是 | 高 |
| GRM-19 | Portfolio Photo Detail | `GroomerPortfolioPhotoDetailView`（private） | `Features/Groomer/Profile/GroomerPortfolioEditorView.swift` | Portfolio | Detail | Portfolio photo tile | 是 | 高 |
| DBG-01 | Debug Console | `DebugPanelView` | `Features/Debug/DebugPanelView.swift` | Debug/TestOps | Preview/Test Only | `#if DEBUG` account link | 否（普通 production） | 高 |
| EMB-01 | Customer 请求状态转发 | `CustomerRequestsStatusView` | `Features/Customer/Requests/CustomerRequestsStatusView.swift` | Feedback | Embedded Component | Requests/Bookings background | 否 | 高 |
| EMB-02 | Groomer Profile 状态转发 | `GroomerProfileStatusView` | `Features/Groomer/Profile/GroomerProfileStatusView.swift` | Feedback | Embedded Component | Groomer profile screens background | 否 | 高 |
| EMB-03 | 共享 loading/empty/error/feedback | `BeckonLoadingView`、`BeckonEmptyState` 等 | `DesignSystem/BeckonFeedbackPrimitives.swift` | Design System | Embedded Component | 多页面状态分支 | 否 | 高 |
| EMB-04 | 行、卡片、header、form section 集合 | 多个 private/public `View` | 各 Feature 文件 | 多模块 | Embedded Component | 正式页面 body 内嵌 | 否 | 高 |

未发现 production Feature 中的 `NavigationSplitView`、`.fullScreenCover`、`.popover` 或自定义全局 Router/Coordinator。Deep link 仅确认 App URL callback 交给 `AuthenticationStore.handleAuthCallback(_:)`；业务页面深链主要是 role tab 内的 focused ID/route 状态，并非外部 URL router。

## 正式页面详情

### ROOT-01 — App 根状态容器

- 页面 ID / 名称：ROOT-01 / App 根状态容器；类型：`AppRootView`；模块：App；类型：Root。
- 文件：`ios/Beckon/Beckon/App/AppRootView.swift`。
- 访问者与任务：所有启动用户；选择配置阻塞、Auth gate 或 role shell。
- 进入/退出：`BeckonApp.WindowGroup` 固定以 `.authentication` 创建；退出由内部 Auth/role 状态替换内容，不是用户导航返回。
- 主要区域/操作：无独立业务布局；`body` 对 `AppEntryRoute` switch。
- 依赖：`AuthenticationBootstrapState`、`AuthenticationStore`、全部 repository protocols。
- Preview/测试：有四个 route Preview；`AppEntryModelsTests.swift` 覆盖 entry model。直接 `.customer/.groomer` production 调用未发现。
- 不确定事项：`.roleOnboarding/.customer/.groomer` 的直接 route 目前仅确认 Preview；正式流程通过 Auth entry。
- 证据：`BeckonApp.body`、`AppRootView.body`、`AppEntryRoute.productionDefault`。

### AUTH-01 — 配置/启动阻塞页

- 类型/文件/模块/页面类型：`AuthenticationBootstrapView`；`Features/Auth/AuthenticationBootstrapView.swift`；Auth；Utility。
- 访问者与任务：所有启动用户；显示 backend configuration ready/error 状态，阻止错误配置进入 Auth。
- 进入条件/退出：`AppRootView` 缺少组合依赖时进入；配置由重新启动/修复环境解决，页面内无业务导航。
- 区域/操作：品牌、状态图标、配置错误说明；未确认用户可执行恢复按钮。
- 数据：`AuthenticationBootstrapState`。
- Preview/测试：有 configured 与 missing-configuration Preview；entry model tests 存在。
- 不确定事项：release 环境错误恢复是否只能重启，待运行时确认。
- 证据：`AppRootView.body` authentication fallback；`AuthenticationBootstrapView.body`。

### AUTH-02 — 登录与注册

- 类型/文件/模块/页面类型：`AuthenticationView`；`Features/Auth/AuthenticationView.swift`；Auth；Authentication。
- 访问者与任务：signed-out 用户；进入登录或注册、提交邮箱密码。
- 进入/退出：`AuthenticationGateView` 的 `.signedOut`；成功后 `AuthenticationStore.rootState` 变为 `.signedIn`，返回按钮仅在 landing/form 内切换。
- 区域：landing hero/actions；sign-in/sign-up form；email/password/confirm password；notice/error feedback。
- 操作：Get Started、已有账户、切换模式、显示密码、`store.submit()`；DEBUG-only quick login 排除。
- 数据：`AuthenticationStore`、`AuthenticationMode`、`AuthenticationSurface`（private local state）。
- Preview/测试：未发现独立 Preview；Auth/App entry tests 通过 Store/model 间接覆盖。
- 不确定事项：没有忘记密码入口，标记为“未发现实现”。
- 证据：`AuthenticationGateView.body`；`AuthenticationView.authActions`、`authFields`、`openForm`。

### AUTH-03 — 角色与资料建立

- 类型/文件/模块/页面类型：`RoleOnboardingView`；`Features/Auth/RoleOnboardingView.swift`；Auth；Onboarding。
- 访问者与任务：已登录但 profile lookup 为空的用户；选择 Customer/Groomer 并建立 display name/profile。
- 进入/退出：`AuthenticatedEntryView.state == .onboarding`；成功后 `AuthenticatedEntryStore` 切换到权威 role state；可 sign out。
- 区域/操作：role selection、display name、创建 profile、错误/loading、sign out。
- 数据：`AuthSessionSnapshot`、`AuthenticatedEntryStore`、`UserRole`。
- Preview/测试：AppRoot 有 DEBUG role-onboarding Preview；`AppEntryModelsTests.swift` 覆盖 entry state。
- 不确定事项：无。
- 证据：`AuthenticatedEntryView.body` onboarding case；`RoleOnboardingView.body`。

### AUTH-04 — Profile 加载失败

- 类型/文件/模块/页面类型：`AuthenticatedEntryView.loadFailureView(message:)`（`@ViewBuilder`/opaque View surface，无独立类型）；`Features/Auth/AuthenticatedEntryView.swift`；Auth；Utility。
- 访问者与任务：已登录但 profile repository 读取失败的用户；理解失败、重试或安全登出。
- 进入/退出：`AuthenticatedEntryStore.state == .failure(message)`；Retry 调 `store.retry()`，Sign Out 调 `signOut()` 返回 Authentication。
- 区域/操作：独立 `NavigationStack`、Profile Unavailable error banner、Retry、Sign Out。
- 数据：`AuthenticatedEntryStore`、`AuthenticationStore`。
- Preview/测试：未发现独立 Preview；`AppEntryModelsTests.swift` 覆盖 failure/retry entry behavior。
- 不确定事项：这是条件页面而非命名 `View` type；仍因 production 状态分支可达而计入正式页面。
- 证据：`AuthenticatedEntryView.body` failure case；`loadFailureView(message:)`、`store.retry()`、`signOut()`。

### CUS-01 — Customer Home

- 类型/文件/模块/页面类型：`CustomerPetsView`；`Features/Customer/Pets/CustomerPetsView.swift`；Customer Home/Pets；Tab Root。
- 访问者与任务：Customer；查看问候、通知、宠物、active request、next booking，并发起请求。
- 进入/退出：Customer Home tab；切 tab 离开，内部可 push Notifications 或触发跨 tab Requests/Messages。
- 区域：header/notification badge、request hero、pet carousel/list、active request、next booking、loading/error feedback。
- 操作：打开通知、创建/编辑宠物、开始 request、打开 active request、打开 booking chat、refresh。
- 数据：`CustomerPetsStore`、`CustomerRequestsStore`、`BookingsStore`、`CustomerNotificationsStore`。
- Preview/测试：有 Preview repository；`CustomerPetFeatureTests`、`CustomerRequestFeatureTests*`、notification/booking tests。
- 不确定事项：Home 中 pet detail 没有独立 push 类型；编辑在 sheet 中完成。
- 证据：`CustomerTabView.destination(for: .home)`；`CustomerPetsView.body`、`loadHome()`。

### CUS-02 — Customer Notifications

- 类型/文件/模块/页面类型：`CustomerNotificationsView`；`Features/Customer/Notifications/CustomerNotificationsView.swift`；Notifications；List。
- 访问者与任务：Customer；查看、分页和标记通知。
- 进入/退出：Home 的 `isShowingNotifications` navigation destination；系统 Back 返回 Home。
- 区域/操作：通知列表、unread/read presentation、load-more、mark-all-read、loading/empty/error。
- 数据：`CustomerNotificationsStore`、`CustomerNotification`。
- Preview/测试：未发现独立 Preview；`CustomerNotificationsFeatureTests.swift`。
- 不确定事项：通知点击后的业务 route 未在该 View 中确认，待后续交互盘点。
- 证据：`CustomerPetsView.navigationDestination`；`CustomerNotificationsView.body`/toolbar。

### CUS-03 — Pet 创建/编辑表单

- 类型/文件/模块/页面类型：`CustomerPetFormView`；`Features/Customer/Pets/CustomerPetsView.swift`；Pets；Sheet。
- 访问者与任务：Customer；新增或编辑 pet 与照片/属性。
- 进入/退出：`petStore.isShowingPetForm`；Cancel/dismiss 或保存成功后关闭。
- 区域/操作：pet identity、species/breed/size/notes、PhotosPicker、save/cancel。
- 数据：`CustomerPetsStore`、`CustomerPet`、pending photo state。
- Preview/测试：随 CustomerPets Preview 间接可呈现；`CustomerPetFeatureTests.swift`。
- 不确定事项：创建和编辑共用同一类型，未拆成两个页面 ID。
- 证据：`CustomerPetsView.sheet`、`CustomerPetFormView`、`CustomerPetsStore.startCreate/startEdit/save`。

### CUS-04 — Grooming Request Wizard

- 类型/文件/模块/页面类型：`CustomerRequestWizardView`；`Features/Customer/Requests/CustomerRequestWizardView.swift`；Requests；Sheet。
- 访问者与任务：Customer；选择 pet、service、日期时间、地点、图片、fit 信息并发布或 republish request。
- 进入/退出：Home、Requests、Bookings 的 `isShowingWizard` bindings；Close/cancel 或 publish 完成；缺 pet 时可转 Pet Form。
- 区域：多步 header/progress、pet/service/time/location/photos/fit/review steps、固定 bottom bar。
- 操作：前进/后退、字段选择、PhotosPicker、添加 pet handoff、publish/cancel。
- 数据：`CustomerRequestsStore`、`CustomerRequestWizardDraft`/presentation state、`CustomerProfileRepository`。
- Preview/测试：无独立 Preview；`CustomerRequestFeatureTests+WizardPresentation.swift` 等。
- 不确定事项：具体 step 数由 Store/presentation 控制，本文不重复枚举内部组件为页面。
- 证据：三个 `.sheet` 调用；`CustomerRequestWizardView.body`、`store.publishWizard()`。

### CUS-05 — Customer Requests

- 类型/文件/模块/页面类型：`CustomerRequestsView`；`Features/Customer/Requests/CustomerRequestsView.swift`；Requests；Tab Root。
- 访问者与任务：Customer；查看 active/cancelled requests、进度、offers 与 booking handoff。
- 进入/退出：Customer Requests tab；NavigationLink 进入 detail，sheet 创建/republish，cross-tab chat。
- 区域/操作：root header、progress carousel、timeline、action cards、cancelled section、empty/loading/error；create、cancel confirmation、republish、load more。
- 数据：`CustomerRequestsStore`、`CustomerRequest`、offers、booking handoff。
- Preview/测试：status-only Preview；大量 `CustomerRequestFeatureTests*`。
- 不确定事项：部分 dashboard View 为大型内嵌模块，不是独立页面。
- 证据：`CustomerTabView.destination`；`CustomerRequestsView.body`、alert/sheet/navigationDestination。

### CUS-06 — Customer Request Detail

- 类型/文件/模块/页面类型：`CustomerRequestDetailView`；`Features/Customer/Requests/CustomerRequestDetailView.swift`；Requests；Detail。
- 访问者与任务：request owner Customer；查看请求快照、进度、照片、offers、booking/republish 状态。
- 进入/退出：Requests dashboard/timeline `NavigationLink`；系统 Back。
- 区域/操作：request hero/facts/photos/status、offer review、republish card；打开 offer、accept offer、republish/handoff。
- 数据：`CustomerRequestsStore`、`CustomerGroomingRequest`、offer/match/booking data。
- Preview/测试：无独立 Preview；request/offer/republish tests。
- 不确定事项：不同 request 状态显示区域有条件分支，需状态矩阵任务细化。
- 证据：`CustomerRequestsDashboardView` links；`CustomerRequestDetailView.body`。

### CUS-07 — Customer Offer Detail

- 类型/文件/模块/页面类型：`CustomerOfferDetailView`（private）；同 CUS-06 文件；Offers；Detail。
- 访问者与任务：拥有 request 的 Customer；比较 groomer offer、fit evidence、报价和 proposed time，并接受可用 offer。
- 进入/退出：Request Detail offer row `NavigationLink`；Back 或接受后由 Store 刷新。
- 区域/操作：offer/groomer summary、facts、fit evidence、message、accept action、状态反馈。
- 数据：`CustomerRequestsStore`、`CustomerRequestOffer` 及 groomer evidence。
- Preview/测试：无独立 Preview；`CustomerRequestFeatureTests+Offers.swift`。
- 不确定事项：accepted/unavailable 分支由 offer/request 状态决定。
- 证据：`CustomerOfferReviewSection`、`CustomerOfferDetailView`。

### CUS-08 — Customer Bookings

- 类型/文件/模块/页面类型：`BookingsView(role: .customer)`；`Features/Bookings/BookingsView.swift`；Bookings；Tab Root。
- 访问者与任务：Customer；按 scope 查看 bookings、进入 detail、从 cancelled booking republish。
- 进入/退出：Customer Bookings tab；row push detail；republish sheet；chat callback 切 Messages。
- 区域/操作：scope control、booking rows、empty/loading/error、pagination、republish。
- 数据：`BookingsStore`，可选 `CustomerRequestsStore`。
- Preview/测试：Customer role Preview；`BookingFeatureTests.swift`。
- 不确定事项：无。
- 证据：`CustomerTabView.destination`；`BookingsView.body` customer branches。

### CUS-09 — Customer Booking Detail

- 类型/文件/模块/页面类型：`BookingDetailView(role: .customer)`；同上；Bookings/Reviews；Detail。
- 访问者与任务：booking participant Customer；查看 appointment、partner、request、状态，取消、聊天、提交 review。
- 进入/退出：Bookings row 或 Requests `selectedBookingHandoff`; Back，chat 转 Messages。
- 区域/操作：hero、facts、partner、action bar、existing review 或 review form；cancel/open chat/submit review。
- 数据：`BookingsStore`、`Booking`、review draft/fit outcome。
- Preview/测试：随 Bookings Preview；`BookingFeatureTests.swift`。
- 不确定事项：review form 是 detail 内嵌区域，不另算页面。
- 证据：两个 Customer navigation sources；`BookingDetailView.body`。

### CUS-10 — Customer Messages

- 类型/文件/模块/页面类型：`ChatConversationsView(role: .customer)`；`Features/Chat/ChatView.swift`；Chat；Tab Root。
- 访问者与任务：Customer；查看 booking conversations、unread 和分页。
- 进入/退出：Customer Messages tab 或 booking chat cross-tab；row/focused route push thread。
- 区域/操作：conversation rows、unread state、loading/empty/error、load more、refresh。
- 数据：`ChatStore`、`ChatConversationSummary`。
- Preview/测试：Customer Preview；`ChatFeatureTests.swift`、`TabBadgeFeatureTests.swift`。
- 不确定事项：unread 是 local/session-scoped，非服务器 read receipt。
- 证据：`CustomerTabView.openBookingChat`；`ChatConversationsView.body`。

### CUS-11 — Customer Chat Thread

- 类型/文件/模块/页面类型：`ChatThreadView`（private）；同上；Chat；Detail。
- 访问者与任务：conversation participant Customer；读写 booking text chat。
- 进入/退出：conversation link 或 `focusedBookingID` destination；自定义 header Back。
- 区域/操作：thread header、booking context、message list、history pagination、composer/read-only banner；send/load older。
- 数据：`ChatStore`、conversation/messages、draft text。
- Preview/测试：随 Chat Preview；`ChatFeatureTests.swift`。
- 不确定事项：attachments/read receipts/realtime 未发现实现。
- 证据：`ChatConversationsView.navigationDestination`/row link；`ChatThreadView`。

### CUS-12 — Customer Account

- 类型/文件/模块/页面类型：`CustomerAccountView`；`Features/Customer/Profile/CustomerProfileSettingsView.swift`；Account；Tab Root。
- 访问者与任务：Customer；查看 profile summary，进入设置/支持，登出或删除账户。
- 进入/退出：Customer Account tab；menu push；sign out 返回 Auth。
- 区域/操作：profile card、Profile Settings link、release/support links、danger actions、DEBUG-only link；load profile、sign out/delete。
- 数据：`CustomerProfileStore`、`AuthenticatedAccountView`/`AuthenticationStore` content。
- Preview/测试：未发现独立 Preview；`CustomerProfileFeatureTests.swift`、Auth tests。
- 不确定事项：外部 Privacy/Support 链接打开系统浏览器，不算 App 内页面。
- 证据：`AuthenticatedEntryView.customerAccountContent`；`CustomerAccountView.body`。

### CUS-13 — Customer Profile Settings

- 类型/文件/模块/页面类型：`CustomerProfileSettingsView`（private）；同上；Account/Profile；Settings。
- 访问者与任务：Customer；编辑 nickname/contact/address/avatar。
- 进入/退出：Customer Account menu `NavigationLink`；Back，Save 保持页面并反馈。
- 区域/操作：avatar editor、contact fields、address autocomplete、Save bar；PhotosPicker/upload/save。
- 数据：`CustomerProfileStore`、address search object、profile/photo models。
- Preview/测试：无独立 Preview；`CustomerProfileFeatureTests.swift`。
- 不确定事项：地址建议为表单内嵌 search results，不算 Search 页面。
- 证据：`CustomerAccountMenuLink` destination；`CustomerProfileSettingsView.body`。

### CUS-14 — 删除账户双重确认

- 类型/文件/模块/页面类型：`AccountDangerActions` + SwiftUI system dialogs；`Features/Auth/AuthenticatedAccountView.swift`；Account/Auth；Utility。
- 访问者与任务：authenticated Customer（generic account content）；安全确认永久删除账户。
- 进入/退出：Account danger button；confirmation dialog → final alert；Cancel 退出，Delete 调 `authenticationStore.deleteAccount()` 并 sign out。
- 区域/操作：两层 destructive warning 与 cancel/delete。
- 数据：`AuthenticationStore`、local `showsDeletionWarning/showsFinalDeletionConfirmation`。
- Preview/测试：无独立 Preview；Auth/account deletion Store tests 待确认具体 selector。
- 不确定事项：Groomer 当前 Account 使用直接 `onSignOut`，generic account content 作为 fallback link；普通 Groomer 是否能进入删除账户页面待确认。
- 证据：`AccountDangerActions.body`、`AuthenticatedEntryView.genericAccountContent`、Groomer account fallback logic。

### GRM-01 — Groomer Home

- 类型/文件/模块/页面类型：`GroomerHomeView`；`Features/Groomer/Home/GroomerHomeView.swift`；Groomer Home；Tab Root。
- 访问者与任务：Groomer；查看 next booking、attention counts、availability 和 unread shortcuts。
- 进入/退出：Groomer Home tab；按钮跨 tab 或 push Notifications。
- 区域/操作：header/avatar/bell、next booking card、requests/offers/messages attention、availability row、loading/unavailable；refresh/navigation actions。
- 数据：`GroomerHomeStore`、notification store、profile/request/booking repositories。
- Preview/测试：未发现独立 Preview；`GroomerHomeFeatureTests.swift`。
- 不确定事项：booking shortcut 当前只选择 Schedule tab，未携带 focused booking ID。
- 证据：`GroomerTabView.destination(.home)`；`GroomerHomeView.body`。

### GRM-02 — Groomer Notifications

- 类型/文件/模块/页面类型：`GroomerNotificationsView`；`Features/Groomer/Notifications/GroomerNotificationsView.swift`；Notifications；List。
- 访问者与任务：Groomer；查看/分页/标记通知，并路由到 Requests/Offers/Bookings/Messages。
- 进入/退出：Home bell `NavigationLink`；Back 或点击通知触发 `notificationRouteAction` 后切 tab。
- 区域/操作：workspace header、notification rows、mark all read、load more、loading/empty/error。
- 数据：`GroomerNotificationsStore`、`GroomerNotificationRoute`。
- Preview/测试：无独立 Preview；`GroomerNotificationsFeatureTests.swift`。
- 不确定事项：route 带 request/offer ID 时由 Requests tab 二次激活 detail。
- 证据：`GroomerHomeHeader` link；`GroomerTabView.openNotificationRoute`。

### GRM-03 — Groomer Requests

- 类型/文件/模块/页面类型：`GroomerRequestsView`；`Features/Groomer/Requests/GroomerRequestsView.swift`；Requests/Offers；Tab Root。
- 访问者与任务：Groomer；在 Matches/Offers 分段查看请求与已发 offers。
- 进入/退出：Requests tab、Home shortcuts、notification route；push request/offer detail。
- 区域/操作：segmented workspace header、matches list、offers content、pagination、loading/empty/error；dismiss/open/create/withdraw flows。
- 数据：`GroomerRequestsStore`、`GroomerOffersStore`、`GroomerRequestsRoute`。
- Preview/测试：有 Preview repositories；`GroomerRequestFeatureTests.swift`、`GroomerOffersFeatureTests.swift`。
- 不确定事项：Offers 是同一 tab 的 segment 内容，不另列 list 页面。
- 证据：`GroomerTabView.destination`；`GroomerRequestsView.body`/route change handlers。

### GRM-04 — Groomer Request Detail / Create Offer

- 类型/文件/模块/页面类型：`GroomerRequestDetailView`（private）；同上；Requests/Offers；Create。
- 访问者与任务：matched Groomer；查看 request/pet/fit/photos，dismiss match 或填写 proposed time/price/message 创建 offer。
- 进入/退出：match row/focused request destination；Back，dismiss/create 后 Store 刷新。
- 区域/操作：request hero/facts/photos/evidence、date pickers、price/message form、dismiss/submit。
- 数据：两个 Groomer stores、matched request、offer draft local state。
- Preview/测试：随 Requests Preview；request/offer feature tests。
- 不确定事项：Detail 与 Create form 在同一 type，因此页面类型按主要可执行任务标为 Create。
- 证据：`GroomerRequestsView.navigationDestination($focusedMatchID)`；`GroomerRequestDetailView.body`。

### GRM-05 — Groomer Offer Detail

- 类型/文件/模块/页面类型：`GroomerOfferDetailView`；`Features/Groomer/Offers/GroomerOffersView.swift`；Offers；Detail。
- 访问者与任务：offer owner Groomer；查看 offer/request/booking/message 与状态，必要时 withdraw。
- 进入/退出：Offers row/focused offer destination；Back，withdraw 后刷新。
- 区域/操作：hero、facts、request/booking/message cards、withdraw action、status feedback。
- 数据：`GroomerOffersStore`、groomer offer summary。
- Preview/测试：随 Requests Preview 间接；`GroomerOffersFeatureTests.swift`。
- 不确定事项：无。
- 证据：`GroomerOffersContentView` row link；`GroomerOfferDetailView`。

### GRM-06 — Groomer Schedule

- 类型/文件/模块/页面类型：`BookingsView(role: .groomer)`；`Features/Bookings/BookingsView.swift`；Bookings；Tab Root。
- 访问者与任务：Groomer；按日期查看 appointment timeline/summary。
- 进入/退出：Schedule tab 或 notification/home route；row push detail。
- 区域/操作：day strip、summary band、timeline/empty day、pagination/refresh。
- 数据：`BookingsStore`、`GroomerSchedulePresentation`。
- Preview/测试：Preview 默认 customer，groomer presentation tests 在 `BookingFeatureTests.swift`。
- 不确定事项：外部 Calendar integration 未发现实现。
- 证据：`GroomerTabView.destination(.bookings)`；`BookingsView` groomer branches。

### GRM-07 — Groomer Booking Detail

- 类型/文件/模块/页面类型：`BookingDetailView(role: .groomer)`；同上；Bookings；Detail。
- 访问者与任务：booking Groomer participant；查看 appointment 并 cancel/complete/open chat。
- 进入/退出：Schedule appointment row；Back，chat cross-tab Messages。
- 区域/操作：shared hero/facts/partner/action bar；Cancel、Complete、Open Chat。
- 数据：`BookingsStore`、`Booking`。
- Preview/测试：间接 Preview；`BookingFeatureTests.swift`。
- 不确定事项：review UI 只对 Customer 条件显示。
- 证据：`GroomerScheduleAppointmentRow.NavigationLink`；`BookingDetailActionPresentation`。

### GRM-08 — Groomer Messages

- 类型/文件/模块/页面类型：`ChatConversationsView(role: .groomer)`；`Features/Chat/ChatView.swift`；Chat；Tab Root。
- 访问者与任务：Groomer；查看 booking conversations/unread，进入 thread。
- 进入/退出：Messages tab、booking action、notification route；push thread。
- 区域/操作：conversation list、loading/empty/error/pagination、refresh。
- 数据：`ChatStore`。
- Preview/测试：Preview 默认 customer；`ChatFeatureTests.swift`、groomer inbox presentation tests。
- 不确定事项：无。
- 证据：`GroomerTabView.destination/openBookingChat/openNotificationRoute`；`ChatConversationsView`。

### GRM-09 — Groomer Chat Thread

- 类型/文件/模块/页面类型：`ChatThreadView`（private）；同上；Chat；Detail。
- 访问者与任务：conversation participant Groomer；读写 text chat。
- 进入/退出：conversation row 或 focused booking；header Back。
- 区域/操作/数据：与 CUS-11 相同，以 `.groomer` role 调整 presentation；send/load older/read-only。
- Preview/测试：间接；`ChatFeatureTests.swift`。
- 不确定事项：attachments、typing、realtime、read receipts 未发现实现。
- 证据：Groomer `ChatConversationsView` 构造；`ChatThreadView` role branches。

### GRM-10 — Groomer Account

- 类型/文件/模块/页面类型：`GroomerProfileManagementView` + `GroomerAccountHomeView`；两个 Profile 文件；Groomer Profile；Tab Root。
- 访问者与任务：Groomer；查看 business/matching summaries，进入各配置 workspace，sign out。
- 进入/退出：Account tab；menu push；Home Availability deep route；sign out 返回 Auth。
- 区域/操作：profile header；Business（Edit Profile/Services/Portfolio）；Matching & Schedule（Availability/Fit Signals/Evidence）；Support；Sign Out。
- 数据：`GroomerProfileStore`、`GroomerProfileRoute`。
- Preview/测试：status Preview；`GroomerProfileFeatureTests*`、TestOps selectors。
- 不确定事项：`accountContent` fallback link 仅在没有 `onSignOut` 时出现；正式构造同时传两者，使用直接 sign out。
- 证据：`GroomerTabView.destination(.account)`；`GroomerProfileManagementView.body`；`GroomerAccountHomeView.body`。

### GRM-11 — Edit Groomer Profile

- 类型/文件/模块/页面类型：`GroomerProfileEditorView`；`Features/Groomer/Profile/GroomerProfileFormView.swift`；Groomer Profile；Edit。
- 访问者与任务：Groomer；编辑 identity/business/address/avatar。
- 进入/退出：Account Edit Profile link；native Back；固定 Save bar。
- 区域/操作：avatar PhotosPicker、profile fields、address suggestions、active/status fields、save/upload。
- 数据：`GroomerProfileStore`、address search。
- Preview/测试：无独立 Preview；`GroomerProfileFeatureTests+Operations.swift` 等。
- 不确定事项：无。
- 证据：`GroomerAccountHomeView` destination；`GroomerProfileEditorView.body`。

### GRM-12 — Services

- 类型/文件/模块/页面类型：`GroomerServicesEditorView`；`Features/Groomer/Profile/GroomerServicesEditorView.swift`；Services；Settings。
- 访问者与任务：Groomer；查看和管理 service types、价格、duration、accepted sizes、active state。
- 进入/退出：Account Services link；Back；Add/Edit 打开 sheet。
- 区域/操作：service list/empty state、type picker、add/edit/toggle/delete（以 Store 支持为准）。
- 数据：`GroomerProfileStore`、service models/form state。
- Preview/测试：无独立 Preview；`GroomerProfileFeatureTests+Operations.swift`。
- 不确定事项：删除是否为立即操作或只在 form 内，待交互矩阵确认。
- 证据：Account menu destination；`GroomerServicesEditorView.body`。

### GRM-13 — Service 创建/编辑表单

- 类型/文件/模块/页面类型：`GroomerServiceFormView`；同上；Services；Sheet。
- 访问者与任务：Groomer；新增或编辑一项 service。
- 进入/退出：`store.isShowingServiceForm` sheet（modifier 位于 Account root）；Cancel/dismiss、Save。
- 区域/操作：service type/details/price/duration/pet sizes/active、save/cancel。
- 数据：`GroomerProfileStore.serviceForm*`。
- Preview/测试：无独立 Preview；profile operations tests。
- 不确定事项：sheet modifier 位于 `GroomerProfileManagementView`，但由 Services 子页面设置共享 Store flag。
- 证据：`GroomerProfileManagementView.sheet`；`GroomerServiceFormView`。

### GRM-14 — Availability

- 类型/文件/模块/页面类型：`GroomerAvailabilityEditorView`；`Features/Groomer/Profile/GroomerAvailabilityEditorView.swift`；Availability；Settings。
- 访问者与任务：Groomer；管理 matching、weekly hours、capacity/advance notice/auto-ready 和 time off。
- 进入/退出：Account link；Home `requestedProfileRoute = .availability`；Back、Save。
- 区域/操作：matching settings、weekly rows/time menus、booking preferences、time-off list、fixed save；toggle/edit/add/delete/save。
- 数据：`GroomerProfileStore` availability/time-off state。
- Preview/测试：无独立 Preview；`GroomerProfileFeatureTests+Operations.swift`。
- 不确定事项：Home route 等待 profile load 后才激活。
- 证据：两种 destination；`GroomerProfileRoute.activatedRoute`；Availability view。

### GRM-15 — Add Time Off

- 类型/文件/模块/页面类型：`GroomerTimeOffFormView`（private）；同上；Availability；Sheet。
- 访问者与任务：Groomer；添加 time-off 日期范围与原因。
- 进入/退出：Availability `store.isShowingTimeOffForm`；Cancel/dismiss 或 save。
- 区域/操作：start/end date、reason、save/cancel。
- 数据：`GroomerProfileStore` time-off form fields。
- Preview/测试：无独立 Preview；availability operations tests。
- 不确定事项：类型名只写 Add，编辑已有 time off 的独立 flow 未发现实现。
- 证据：`GroomerAvailabilityEditorView.sheet`；`GroomerTimeOffFormView`。

### GRM-16 — Fit Signals

- 类型/文件/模块/页面类型：`GroomerFitSignalsEditorView`；`Features/Groomer/Profile/GroomerFitSignalsEditorView.swift`；Pet Fit；Settings。
- 访问者与任务：Groomer；设置 size range 和 fit claims/skills。
- 进入/退出：Account Fit Signals link；Back、save mutations。
- 区域/操作：core selection/size range、grouped skills、chips/toggles、save/feedback。
- 数据：`GroomerProfileStore` fit signal extension state。
- Preview/测试：无独立 Preview；`GroomerProfileFeatureTests+FitSignals.swift`。
- 不确定事项：无。
- 证据：Account menu destination；`GroomerFitSignalsEditorView`。

### GRM-17 — Evidence

- 类型/文件/模块/页面类型：`GroomerEvidenceDashboardView`；同上；Pet Fit Evidence；Settings。
- 访问者与任务：Groomer；查看 grouped evidence overview/empty state。
- 进入/退出：Account Evidence link；Back。
- 区域/操作：evidence summary/groups/empty state；本阶段未确认直接 edit action。
- 数据：`GroomerProfileStore.petFitEvidenceSummary` 等。
- Preview/测试：无独立 Preview；fit signal/evidence tests。
- 不确定事项：若全部只读，应在操作矩阵中标记；当前没有独立 evidence mutation 证据。
- 证据：Account menu destination；`GroomerEvidenceDashboardView.body`。

### GRM-18 — Portfolio

- 类型/文件/模块/页面类型：`GroomerPortfolioEditorView`；`Features/Groomer/Profile/GroomerPortfolioEditorView.swift`；Portfolio；Settings。
- 访问者与任务：Groomer；查看 gallery、上传照片、进入照片 detail。
- 进入/退出：Account Portfolio link；Back；photo link push detail。
- 区域/操作：gallery/empty state、PhotosPicker upload、tiles、feedback。
- 数据：`GroomerProfileStore` portfolio photos/cache/upload state。
- Preview/测试：无独立 Preview；`GroomerProfileFeatureTests+Portfolio.swift`。
- 不确定事项：无。
- 证据：Account destination；`GroomerPortfolioEditorView.body`。

### GRM-19 — Portfolio Photo Detail

- 类型/文件/模块/页面类型：`GroomerPortfolioPhotoDetailView`（private）；同上；Portfolio；Detail。
- 访问者与任务：Groomer；查看大图、编辑 fit notes/tags、删除照片。
- 进入/退出：Portfolio tile `NavigationLink`；Back；delete confirmation dialog 后返回/刷新。
- 区域/操作：artwork、summary、fit-note editor/tags、save bar、delete confirmation。
- 数据：`GroomerProfileStore`、`GroomerPortfolioPhoto`、local delete-confirmation state。
- Preview/测试：无独立 Preview；portfolio tests。
- 不确定事项：删除后的自动 pop 行为需运行时确认。
- 证据：`GroomerPortfolioGallerySection.NavigationLink`；detail type and `confirmationDialog`。

## 非正式页面与排除审计

### DBG-01 — Debug Console

- `DebugPanelView` 只由 Customer/generic authenticated account 中的 `#if DEBUG NavigationLink` 和 DEBUG Preview 调用；普通 release production 不可见，分类为 `Preview/Test Only`。
- 它显示 session/profile/config/operational events、feedback diagnostics，是测试/诊断辅助页，不纳入正式用户流程。
- 证据：`AuthenticatedAccountView.swift`、`CustomerProfileSettingsView.swift` 中 `#if DEBUG`；`DebugPanelView.swift` Preview。

### 内嵌组件

- `CustomerRequestsStatusView`、`GroomerProfileStatusView`、`BookingsStatusView`、`ChatStatusView` 通过 background/overlay 转发反馈或显示状态，不是独立导航目的地。
- `BookingReviewForm`、`ChatComposerView`、Customer/Groomer dashboard/header/card/row/section、address suggestion lists、service/time-off form sections均是正式页面内部区域。
- `FeaturePlaceholderView` 只在 tab 依赖缺失的 fallback 分支出现；正式 `AppComposition` 成功且 authenticated 依赖完整时不会作为业务页面计入。
- 所有 `#Preview` wrapper `NavigationStack`、`*PreviewRepository`、Test target 和 TestOps driver 均不计为 production 页面。

## 导航能力核对结论

- `NavigationStack`：Customer/Groomer 每个 tab 一套；若干 Preview 自建 stack 已排除。
- `TabView`：Customer 与 Groomer 各五个正式 tab。
- `NavigationLink` / `navigationDestination`：覆盖 Notifications、request/offer/booking/chat/profile/portfolio detail 与 role 内 focused routes。
- `.sheet`：Customer Pet Form、Request Wizard、Groomer Service Form、Time Off Form。
- `.fullScreenCover`：未发现实现。
- `.popover`：未发现实现。
- `NavigationSplitView`：未发现实现。
- 外部 deep link：只确认 Auth callback (`BeckonApp.onOpenURL` → `AuthenticationStore.handleAuthCallback`)；未发现外部 URL 直接打开某个业务页面的 router。
- 内部 route/coordinator：`AppEntryRoute`、`AuthenticatedEntryState`、`CustomerTabView` focused IDs、`GroomerRequestsRoute`、`GroomerProfileRoute`、`GroomerNotificationRoute`。

## 当前不确定事项

- `AppRootView` 的直接 `.customer/.groomer/.roleOnboarding` route 是否存在 production 外部调用者：未发现，当前只确认 Preview；正式启动固定 `.authentication`。
- Groomer 是否有普通 production 删除账户入口：当前正式 Account 优先显示直接 Sign Out，generic `AuthenticatedAccountView` 作为 fallback content 传入但不被该分支导航到，待确认产品意图。
- Customer/Groomer notification row 点击后的精确 mark-read 与 route 时序需后续操作矩阵核对。
- Alert/confirmation dialogs 没有独立 SwiftUI type；本文按 Utility 临时界面记录，没有伪造页面类型。
- 未运行 App，因此自动 dismiss/pop、键盘行为、动态条件分支只按代码调用关系记录。

## 本阶段停止点

本文完成正式页面清单与可达性分类，不继续创建导航图、操作矩阵、状态矩阵或 Figma 原型。
