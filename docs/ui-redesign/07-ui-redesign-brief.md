# Beckon UI 重设计输入包

> 本文只定义产品功能、信息架构、交互与业务约束，不规定视觉风格。依据 `00`—`06` 盘点文档及其代码证据整理。正式页面口径包含可达页面、Sheet、条件状态 surface 与系统确认 surface，共 38 个。

## 1. 产品概览

### App 服务的用户

- Customer：维护宠物资料，发布美容请求，比较 Groomer offer，管理预约、消息和评价。
- Groomer：接收匹配请求，提交 offer，管理预约、服务、营业时间、适配信号与作品集。
- 未登录或资料未完成用户：完成认证、角色选择和资料建立。

### 核心使用场景

产品采用 request-first 市场模式：Customer 先描述宠物和服务需求，系统产生 Groomer 匹配；Groomer 提交 offer；Customer 接受后生成 booking 与 conversation；双方在预约前后沟通，Groomer 完成服务，Customer 可提交评价。当前未发现公开浏览 Groomer 或直接预约入口。

### 主要业务模块与完成情况

| 模块 | 已确认能力 | 完成情况/边界 |
|---|---|---|
| Auth/Profile Gate | 登录、注册、角色 onboarding、profile 加载失败恢复、登出 | 正式可达；未发现忘记密码 |
| Customer Pets | 宠物列表、创建/编辑、照片 | 已实现 |
| Requests/Offers | 多步发布、匹配、offer、接受、取消、republish | 核心链路已实现 |
| Bookings/Reviews | 双角色列表/详情、取消、完成、Customer review | 已实现；权限依角色限制 |
| Chat | 会话列表、文本消息、message event subscription | 已实现；无附件、typing、read-receipt UI |
| Notifications | 双角色通知列表、读取、部分程序化路由 | 已实现；若干目标路由待产品确认 |
| Groomer Operations | 服务、可用时间、休假、fit signals、evidence、portfolio | 已实现 |
| Push/Reminders | push 注册与本地预约提醒服务链 | 代码存在；系统授权时机和失败反馈待确认 |

## 2. 信息架构

### 顶层导航

`BeckonApp → AppRootView → 配置/Auth/Profile Gate → 角色 TabView`。Customer 与 Groomer 各有独立的五个 Tab，每个 Tab 内使用独立 `NavigationStack`。

| 角色 | 顶层 Tab |
|---|---|
| Customer | Home、Requests、Bookings、Messages、Account |
| Groomer | Home、Requests、Schedule、Messages、Account |

### 页面层级

- Root/Auth：ROOT-01、AUTH-01—04。
- Customer Tab Roots：CUS-01、05、08、10、12；其下包含通知、详情、设置和 Sheet。
- Groomer Tab Roots：GRM-01、03、06、08、10；其下包含通知、请求/offer/booking/chat 详情及资料管理页面。
- 临时 surface：CUS-03、CUS-04、GRM-13、GRM-15；CUS-14 为双重破坏性确认。

### 核心对象关系

`CustomerProfile → CustomerPet → GroomingRequest → GroomerMatch → Offer → Booking ↔ Conversation → Review`。`GroomerProfile` 关联 `Service`、`Availability/TimeOff`、`FitSignals/Evidence`、`PortfolioPhoto`，共同支持匹配与 offer。Notifications 负责把用户带回相关业务模块。

## 3. 页面优先级

P0＝核心交易或高频沟通；P1＝重要资料与运营支撑；P2＝低频恢复、管理或辅助能力；P3＝系统容器/异常阻塞 surface。

| 优先级 | 页面 ID | 依据 |
|---|---|---|
| P0 | AUTH-02、CUS-01、CUS-04—11、GRM-01、GRM-03—09 | 覆盖登录、请求→offer→booking 主链及高频消息/日程 |
| P1 | AUTH-03、CUS-02—03、CUS-12—13、GRM-02、GRM-10—16、GRM-18—19 | 建立主链所需资料、通知及 Groomer 日常运营能力 |
| P2 | AUTH-04、CUS-14、GRM-17 | 低频恢复、危险操作或证据辅助页面 |
| P3 | ROOT-01、AUTH-01 | 系统路由容器或配置异常阻塞，不是常规业务目的地 |

## 4. 页面设计需求表

| ID | 页面 | 核心任务 | 必须显示的信息 | 主要操作 | 次要操作 | 必须设计的状态 | 进入方式 |
|---|---|---|---|---|---|---|---|
| ROOT-01 | App 根容器 | 决定当前根界面 | 配置/Auth/profile 状态 | 自动路由 | 无 | resolving、signed out/in、failure | App 启动 |
| AUTH-01 | 配置阻塞 | 解释无法启动 | 配置错误与状态 | 无已确认恢复操作 | 无 | configured、missing/error | Root 条件分支 |
| AUTH-02 | 登录/注册 | 建立 session | 模式、邮箱、密码、反馈 | 登录或注册 | 切换模式、显隐密码 | normal、validation、loading、error | signed-out gate |
| AUTH-03 | Onboarding | 建立角色资料 | 角色、display name | 创建资料 | 登出 | normal、disabled、saving、error | profile 缺失 |
| AUTH-04 | Profile 错误 | 恢复 profile 加载 | 错误消息 | Retry | Sign Out | error、loading | profile lookup failure |
| CUS-01 | Customer Home | 了解当前任务并快速行动 | 宠物、请求、下次预约、通知 | 发起请求 | 宠物管理、通知、聊天 | loading、empty、error、loaded | Home Tab |
| CUS-02 | Customer 通知 | 查看和处理通知 | 通知内容、时间、已读状态 | 标记全部已读 | 分页 | loading、empty、error、loaded | Home bell Push |
| CUS-03 | 宠物表单 | 创建/编辑宠物 | 身份、品种、体型、备注、照片 | Save | Cancel、选照片 | validation、saving、error | Sheet |
| CUS-04 | Request Wizard | 发布完整需求 | 宠物、服务、时间、地点、照片、fit、review | Publish | Back、Cancel、添加宠物 | step validation、saving、error | Home/Requests/Bookings Sheet |
| CUS-05 | Requests | 管理请求生命周期 | 状态、进度、offers、booking handoff | 新建/查看请求 | 取消、republish、分页 | loading、empty、error、confirmation | Requests Tab |
| CUS-06 | Request Detail | 理解请求和 offers | 请求快照、照片、状态、offers | 打开/接受 offer | republish | loading、empty offers、error、disabled | Requests Push |
| CUS-07 | Offer Detail | 评估并接受 offer | Groomer、报价、时间、fit evidence、留言 | Accept | Back | loading、error、disabled | Request Detail Push |
| CUS-08 | Bookings | 查看预约 | scope、预约摘要、状态 | 打开预约 | republish、分页 | loading、empty、error | Bookings Tab |
| CUS-09 | Booking Detail | 管理预约与评价 | 时间、双方、请求、状态、评价 | Chat/Submit Review | Cancel | loading、error、validation、confirmation | Bookings/Request Push |
| CUS-10 | Messages | 找到会话 | 对方、预约、最近消息、未读 | 打开会话 | 分页/刷新 | loading、empty、error | Messages Tab |
| CUS-11 | Chat Thread | 发送消息 | 消息流、参与者、只读状态 | Send | 返回 | loading、empty、error、disabled | Conversation Push |
| CUS-12 | Customer Account | 管理账户 | profile 摘要、支持/版本、危险操作 | 打开 Profile | Sign Out、Delete | normal、confirmation、error | Account Tab |
| CUS-13 | Customer Profile | 编辑资料 | display name 与联系资料 | Save | Back | loading、validation、saving、error | Account Push |
| CUS-14 | 删除账户确认 | 防止误删 | 后果与确认文案 | 最终 Delete | Cancel | confirmation、deleting、error | Account dialog/alert |
| GRM-01 | Groomer Home | 掌握待办 | 匹配、offers、预约、通知 | 打开待处理项 | 通知、资料快捷入口 | loading、empty、error | Home Tab |
| GRM-02 | Groomer 通知 | 查看通知并跳转业务 | 通知、时间、已读状态 | 打开相关模块 | 标记已读/分页 | loading、empty、error | Home bell Push |
| GRM-03 | Groomer Requests | 管理匹配与 offers | 匹配请求、offer 状态 | 打开请求/offer | 分段、刷新、分页 | loading、empty、error | Requests Tab |
| GRM-04 | Request/Create Offer | 评估请求并报价 | 宠物、服务、时间地点、fit、报价字段 | Submit Offer | Back | validation、saving、error、disabled | Requests Push |
| GRM-05 | Groomer Offer Detail | 查看已提交 offer | 请求、报价、状态、时间 | 查看状态 | 返回 | loading、error、disabled | Offers Push |
| GRM-06 | Schedule | 管理预约 | scope、预约、状态 | 打开预约 | 分页 | loading、empty、error | Schedule Tab |
| GRM-07 | Groomer Booking Detail | 履约预约 | 时间、Customer/pet、请求、状态 | Chat/Complete | Cancel | loading、error、disabled、confirmation | Schedule Push |
| GRM-08 | Groomer Messages | 找到会话 | 会话摘要、未读 | 打开会话 | 分页/刷新 | loading、empty、error | Messages Tab |
| GRM-09 | Groomer Chat Thread | 与 Customer 沟通 | 消息流、参与者、只读状态 | Send | 返回 | loading、empty、error、disabled | Conversation Push |
| GRM-10 | Groomer Account | 进入运营设置 | profile/服务/availability/fit/portfolio 摘要 | 打开编辑模块 | Sign Out、外部链接 | loading、error | Account Tab |
| GRM-11 | Edit Groomer Profile | 编辑公开资料 | 名称、简介、联系/地点、头像 | Save | 选图、Back | loading、validation、saving、error | Account Push |
| GRM-12 | Services | 管理服务目录 | 服务、价格/时长、启用状态 | Add/Edit | 删除或切换状态 | loading、empty、error | Account Push |
| GRM-13 | Service Form | 创建/编辑服务 | 名称、价格、时长等 | Save | Cancel | validation、saving、error | Services Sheet |
| GRM-14 | Availability | 管理工作时间 | 周期可用时段、休假 | Save/Add Time Off | 编辑/删除时段 | loading、empty、validation、saving、error | Account/Home Push |
| GRM-15 | Add Time Off | 新增休假 | 开始/结束与备注 | Save | Cancel | validation、saving、error | Availability Sheet |
| GRM-16 | Fit Signals | 配置适配偏好 | 体型/行为等适配信号 | Save | 调整范围 | loading、validation、saving、error | Account Push |
| GRM-17 | Evidence | 查看适配证据 | evidence 汇总与状态 | 查看 | Back | loading、empty、error | Account Push |
| GRM-18 | Portfolio | 管理作品 | 照片、标签、上传状态 | Add Photo | 打开详情 | loading、empty、error、uploading | Account Push |
| GRM-19 | Portfolio Photo | 编辑单张作品 | 图片、标签、状态 | Save Tags | Delete | loading、saving、error、confirmation | Portfolio Push |

## 5. 关键用户流程

Figma 原型至少覆盖以下 15 条完整流程：

1. 启动、session 恢复与根状态切换。
2. 注册、选择角色、完成 onboarding。
3. Customer 创建或编辑宠物。
4. Customer 从任一可用入口完成 Request Wizard 并发布。
5. Customer 查看请求、比较并接受 offer。
6. Customer 取消请求，或从取消状态 republish。
7. Customer 查看 booking、进入 chat、Groomer 完成、Customer review。
8. Customer 编辑 profile。
9. Customer 登出或通过双重确认删除账户。
10. Groomer 查看匹配请求并提交 offer。
11. Groomer 新建、编辑与管理服务。
12. Groomer 管理周期 availability 与 time off。
13. Groomer 编辑 profile、fit signals 并查看 evidence。
14. Groomer 上传作品、编辑标签并删除照片。
15. Groomer 从通知进入对应 Tab/业务上下文。

所有原型流程应包含成功返回、用户取消、校验失败和服务失败分支；不得补造公开 Groomer 浏览、直接预约、聊天附件、typing 或 read receipt。

## 6. 组件需求

| 组件语义 | 使用页面 | 内容 | 交互 | 状态/Variant |
|---|---|---|---|---|
| Navigation/RoleTabBar | 双角色 Root | 5 个角色专属 Tab | 切换并保留各自栈 | Customer/Groomer、selected |
| Feedback/State | 全局 | 标题、说明、图标、重试 | Retry/辅助操作 | loading/empty/error/success |
| Pet/Card、Pet/Avatar | CUS-01、03、04 | 照片、名称、属性 | 选择/编辑 | selected、empty image |
| Request/Card、Request/StatusBadge | CUS/GRM Requests、Home | 服务、宠物、时间、状态 | 打开详情 | lifecycle status、disabled |
| Offer/Card、Offer/FitEvidence | CUS-06—07、GRM-03—05 | Groomer、价格、时间、fit | 打开/接受 | pending/accepted/unavailable |
| Booking/Card、Booking/StatusBadge | CUS-08—09、GRM-06—07 | 时间、双方、状态 | 打开、聊天 | upcoming/completed/cancelled |
| Conversation/Row、Message/Bubble | CUS/GRM Chat | 对方、最近消息、消息内容 | 打开/发送 | unread/read-only/sending/error |
| Notification/Row | CUS-02、GRM-02 | 类型、内容、时间 | 标记已读/路由 | read/unread/loading |
| Form/Section、Form/FieldRow | 各表单 | 标签、值、帮助/错误 | 输入、选择 | normal/focused/disabled/error |
| Form/DateTimeRow | Request、Availability、Time Off | 日期/时间/范围 | 选择/校验 | valid/invalid/disabled |
| Action/Primary、Secondary、Destructive | 全局 | 文案、进度 | 执行业务 action | enabled/disabled/loading/destructive |
| Account/MenuRow | CUS-12、GRM-10 | 标题、说明、图标 | Push/External Link | standard/destructive |
| Portfolio/PhotoTile、PhotoDetail | GRM-18—19 | 私有图片、标签 | 选择、保存、删除 | loading/uploading/error |
| Refresh/ForegroundGate | 列表与 Home | 无独立内容 | 前台恢复时去重刷新 | idle/in-flight |

## 7. 状态覆盖矩阵

“—”表示该状态不适用或未发现实现；“待确认”不得作为已实现状态承诺。

| 页面组 | Normal | Loading | Empty | Error | Disabled | Validation | Destructive Confirmation |
|---|---:|---:|---:|---:|---:|---:|---:|
| ROOT-01、AUTH-01、AUTH-04 | ✓ | ✓ | — | ✓ | — | — | — |
| AUTH-02—03 | ✓ | ✓ | — | ✓ | ✓ | ✓ | — |
| CUS-01—02 | ✓ | ✓ | ✓ | ✓ | ✓ | — | — |
| CUS-03—04、CUS-13 | ✓ | ✓ | — | ✓ | ✓ | ✓ | — |
| CUS-05—07 | ✓ | ✓ | ✓ | ✓ | ✓ | — | CUS-05 ✓ |
| CUS-08—09 | ✓ | ✓ | ✓ | ✓ | ✓ | CUS-09 ✓ | CUS-09 ✓ |
| CUS-10—11 | ✓ | ✓ | ✓ | ✓ | ✓ | — | — |
| CUS-12—14 | ✓ | ✓ | — | ✓ | ✓ | — | CUS-14 ✓ |
| GRM-01—03 | ✓ | ✓ | ✓ | ✓ | ✓ | — | — |
| GRM-04—05 | ✓ | ✓ | — | ✓ | ✓ | GRM-04 ✓ | — |
| GRM-06—09 | ✓ | ✓ | ✓ | ✓ | ✓ | — | GRM-07 ✓ |
| GRM-10—11 | ✓ | ✓ | — | ✓ | ✓ | GRM-11 ✓ | — |
| GRM-12—16 | ✓ | ✓ | ✓ | ✓ | ✓ | GRM-13—16 ✓ | 删除项按现有实现 |
| GRM-17—19 | ✓ | ✓ | ✓ | ✓ | ✓ | GRM-19 标签 | GRM-19 ✓ |

## 8. 业务约束

- 必填与验证：认证凭据、onboarding role/display name，以及宠物、request、offer、service、availability/time off、profile、fit、review 各 Store 中现有必填和校验必须保留；Figma 不得通过隐藏字段绕过验证。
- 操作顺序：Customer 必须先有 pet，再发布 request；offer 必须归属 request；接受 offer 后才产生 booking/conversation；Customer review 位于 Groomer 完成之后。
- 权限：权威 profile role 决定根 Tab；Customer 不能完成 booking，Groomer 不能提交 Customer review；聊天仅参与者可用；只读 conversation 禁用 composer。
- 删除与取消：账户删除必须双重确认；作品照片删除必须确认；request/booking 取消不得隐式恢复 request。
- 保存：表单采用显式 Save/Publish/Submit；成功后按现有导航结果关闭 Sheet 或刷新数据，失败时保留当前 surface 与输入。Profile、availability、fit 和照片标签保存后留在页面。
- 状态转换：不得以仅 UI 的乐观状态替代 repository/RPC 结果；offer 接受必须原子生成 booking/conversation；Groomer completion 后才开放相应 Customer review 路径。
- 提示：校验、服务错误、权限拒绝和破坏性后果需有可见反馈；push/reminder 权限拒绝反馈为“待确认”。
- 导航结果：Sheet Cancel/成功关闭；portfolio delete 成功 dismiss detail；跨模块 chat 使用现有 Tab/focused ID；外部支持/条款继续使用系统浏览器或邮件 UI。
- 数据边界：私有图片继续经 repository/`PrivateImageLoader`；异步加载、错误、前台刷新去重和 Chat subscription 生命周期不能因重设计删除。

## 9. 设计待决策事项

以下 7 项没有足够产品证据，Figma 阶段应先确认，不在本文替产品作决定：

1. Groomer 是否应获得删除账户入口；若需要，应位于 Account 主列表还是二级危险操作区。
2. Groomer booking notification 应只切换 Schedule Tab，还是直接打开对应 booking detail。
3. Customer notification row 是否应进入具体业务对象；当前只确认列表与已读行为，目标路由待确认。
4. Push authorization 是否需要预提示页/说明，以及首次请求、拒绝和“稍后”后的反馈策略。
5. Appointment reminder 首次授权与调度失败是否需要页面级反馈或仅轻量提示。
6. 产品对“realtime chat”的承诺如何表述：已有 message event refresh，但未实现 typing、read receipt 和附件。
7. Offer 提交或接受成功后应留在当前详情展示新状态，还是自动返回上级；需以产品期望和运行时验证统一。

## 10. 代码追溯索引

路径均相对项目根目录。共享 Store/Repository 会被多个角色页面复用。

| 页面 ID | SwiftUI 文件 | ViewModel/Store | Model | Service/Repository | 测试文件 |
|---|---|---|---|---|---|
| ROOT-01、AUTH-01—04 | `ios/Beckon/Beckon/App/AppRootView.swift`; `ios/Beckon/Beckon/Features/Auth/AuthenticationBootstrapView.swift`; `AuthenticationView.swift`; `RoleOnboardingView.swift`; `AuthenticatedEntryView.swift`（同 Auth 目录） | `Features/Auth/AuthenticationStore.swift`; `AuthenticatedEntryStore.swift` | `Core/Models/AppEntryRoute.swift`; `UserRole.swift`; `MarketplaceProfile.swift` | `Core/Repositories/AuthSessionRepository.swift`; `ProfileRepository.swift` | `ios/Beckon/BeckonTests/AppEntryModelsTests.swift` |
| CUS-01、CUS-03 | `ios/Beckon/Beckon/Features/Customer/Pets/CustomerPetsView.swift` | `CustomerPetsStore.swift`（同目录） | `Core/Models/CustomerPet.swift` | `Core/Repositories/CustomerPetRepository.swift` | `ios/Beckon/BeckonTests/CustomerPetFeatureTests.swift` |
| CUS-02 | `Features/Customer/Notifications/CustomerNotificationsView.swift` | `CustomerNotificationsStore.swift` | `Core/Models/CustomerNotification.swift` | `Core/Repositories/CustomerNotificationRepository.swift` | `ios/Beckon/BeckonTests/CustomerNotificationsFeatureTests.swift` |
| CUS-04—07 | `Features/Customer/Requests/CustomerRequestWizardView.swift`; `CustomerRequestsView.swift`; `CustomerRequestDetailView.swift` | `Features/Customer/Requests/CustomerRequestsStore.swift` | `Core/Models/CustomerRequest.swift` | `Core/Repositories/CustomerRequestRepository.swift`; `BookingRepository.swift` | `ios/Beckon/BeckonTests/CustomerRequestFeatureTests.swift`; `CustomerRequestFeatureTests+Offers.swift`; `CustomerRequestFeatureTests+WizardPresentation.swift` |
| CUS-08—09、GRM-06—07 | `Features/Bookings/BookingsView.swift` | `Features/Bookings/BookingsStore.swift` | `Core/Models/Booking.swift` | `Core/Repositories/BookingRepository.swift` | `ios/Beckon/BeckonTests/BookingFeatureTests.swift` |
| CUS-10—11、GRM-08—09 | `Features/Chat/ChatView.swift` | `Features/Chat/ChatStore.swift` | `Core/Models/Chat.swift` | `Core/Repositories/ChatRepository.swift` | `ios/Beckon/BeckonTests/ChatFeatureTests.swift` |
| CUS-12—14 | `Features/Customer/Profile/CustomerProfileSettingsView.swift`; `Features/Auth/AuthenticatedAccountView.swift` | `Features/Customer/Profile/CustomerProfileStore.swift`; `AuthenticationStore.swift` | `Core/Models/CustomerProfile.swift` | `Core/Repositories/CustomerProfileRepository.swift`; `AuthSessionRepository.swift` | `ios/Beckon/BeckonTests/CustomerProfileFeatureTests.swift` |
| GRM-01 | `Features/Groomer/Home/GroomerHomeView.swift` | `Features/Groomer/Home/GroomerHomeStore.swift` | `Core/Models/GroomerRequest.swift`; `Booking.swift` | `Core/Repositories/GroomerRequestRepository.swift`; `BookingRepository.swift` | `ios/Beckon/BeckonTests/GroomerHomeFeatureTests.swift` |
| GRM-02 | `Features/Groomer/Notifications/GroomerNotificationsView.swift` | `GroomerNotificationsStore.swift` | `Core/Models/GroomerNotification.swift` | `Core/Repositories/GroomerNotificationRepository.swift` | `ios/Beckon/BeckonTests/GroomerNotificationsFeatureTests.swift` |
| GRM-03—05 | `Features/Groomer/Requests/GroomerRequestsView.swift`; `Features/Groomer/Offers/GroomerOffersView.swift` | `GroomerRequestsStore.swift`; `GroomerOffersStore.swift` | `Core/Models/GroomerRequest.swift` | `Core/Repositories/GroomerRequestRepository.swift`; `GroomerOfferRepository.swift` | `ios/Beckon/BeckonTests/GroomerRequestFeatureTests.swift`; `ios/Beckon/BeckonTests/GroomerOffersFeatureTests.swift` |
| GRM-10—19 | `Features/Groomer/Profile/GroomerProfileManagementView.swift`; `GroomerProfileAccountView.swift`; `GroomerProfileFormView.swift`; `GroomerServicesEditorView.swift`; `GroomerAvailabilityEditorView.swift`; `GroomerFitSignalsEditorView.swift`; `GroomerPortfolioEditorView.swift` | `Features/Groomer/Profile/GroomerProfileStore.swift` 及同目录 Store extensions | `Core/Models/GroomerProfile.swift` | `Core/Repositories/GroomerProfileRepository.swift` | `ios/Beckon/BeckonTests/GroomerProfileFeatureTests.swift` |

注：表中省略 `ios/Beckon/Beckon/` 前缀的 Feature/Core 路径均位于该目录。未发现独立 Service 的页面以 Repository 为业务边界；具体方法和字段映射见 `03`、`04`。

## 交付边界

本 brief 不授权新增业务、改变路由或修改权限。Figma 输出必须覆盖上述页面、状态与 15 条流程，并把第 9 节问题保持为待决策标注。
