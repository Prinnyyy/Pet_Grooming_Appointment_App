# 页面功能、控件与操作规格

## 证据规则与状态词表

本规格覆盖 `01-screen-inventory.md` 中 38 个正式页面/surface。业务结果只在 action 能追到 Store/repository 方法时记录；纯导航、局部 UI state 与系统 UI 会明确标注。路径均相对于 `ios/Beckon/Beckon/`，除非另有说明。

状态记录统一检查：Initial、Loading、Loaded、Empty、Error、Disabled、Searching、Filtered、Saving、Saved、Deleting、Offline、Permission Denied、Validation Failed。若代码没有独立状态或 UI，写“未发现独立实现”，不代表底层永远不会返回同类错误。多数 repository 错误统一映射到 `errorMessage`，未发现专用 Offline/Permission Denied 页面。

全局未发现的交互 API：`.searchable`、`.swipeActions`、`.contextMenu`、`.onLongPressGesture`、`.fileImporter`、`ShareLink`、`.onMove`。正式 Feature 中未发现 `fullScreenCover` 或 `popover`。

---

## 页面：App 根状态容器

### 基本信息

- 页面 ID：ROOT-01
- SwiftUI 类型：`AppRootView`
- 文件路径：`App/AppRootView.swift`
- 所属模块：App；页面类型：Root；主要用户：所有启动用户。
- 页面核心目标：按配置、Auth session、profile 与角色选择唯一根内容。

### 页面展示的信息

| 信息或区域 | 数据来源 | 是否可为空 | 空值表现 | 是否可编辑 | 证据 |
|---|---|---|---|---|---|
| 当前根内容 | `route`、可选 stores/repositories | 否 | 依赖缺失显示 AUTH-01 | 否 | `body` switch/optional binding |

### 操作入口

本页面未发现直接用户控件；它只组合 AUTH-01/02/03/04 与 role shells。

### 表单字段

本页面未发现表单字段。

### 页面状态

| 状态 | 触发条件 | UI / 可执行操作 | 退出方式 | 代码证据 |
|---|---|---|---|---|
| Initial/Loaded | `route` 已给定 | 条件显示对应根 View | 下游 state replacement | `AppRootView.body` |
| Error | production dependencies 缺失 | AUTH-01 | 修复配置并重启；页面无 retry | authentication fallback |
| Loading/Empty/Disabled/Searching/Filtered/Saving/Saved/Deleting/Offline/Permission Denied/Validation Failed | 未发现 ROOT-01 自有实现 | 由下游页面承担 | 不适用 | 无相应属性 |

### 页面生命周期行为

ROOT-01 自身无 `.task`；`BeckonApp` 记录 launch/scene phase并处理 Auth callback。离开不保存，不监听业务通知。未确认事项：非 authentication route 的直接 production caller 未发现。

---

## 页面：配置/启动阻塞页

### 基本信息

- 页面 ID：AUTH-01；SwiftUI 类型：`AuthenticationBootstrapView`
- 文件路径：`Features/Auth/AuthenticationBootstrapView.swift`
- 模块/类型/用户：Auth / Utility / 所有启动用户。
- 核心目标：在 backend 配置不可用时阻止进入登录或业务 UI。

### 页面展示的信息

| 信息或区域 | 数据来源 | 是否可为空 | 空值表现 | 是否可编辑 | 证据 |
|---|---|---|---|---|---|
| 配置状态、标题、说明、图标 | `AuthenticationBootstrapState` | 否 | `.ready` 与 `.configurationError(message)` 分支 | 否 | `body` switch |

### 操作入口

未发现 Button、Link 或 retry。

### 表单字段

本页面未发现表单字段。

### 页面状态

| 状态 | 触发条件 | UI / 操作 | 退出 | 证据 |
|---|---|---|---|---|
| Loaded/Error | `.ready` 或 `.configurationError` | 状态说明；无操作 | 外部修复/重启 | `AuthenticationBootstrapState` |
| 其余状态 | 未发现独立实现 | 无 | 不适用 | 无 Store |

### 页面生命周期行为

无自动加载、保存、通知监听或副作用；只是纯渲染。配置错误是否可在不重启时恢复：待确认。

---

## 页面：登录与注册

### 基本信息

- 页面 ID：AUTH-02；类型：`AuthenticationView`
- 文件：`Features/Auth/AuthenticationView.swift`
- 模块/类型/用户：Auth / Authentication / signed-out 用户。
- 核心目标：登录或创建 Auth 账户。

### 页面展示的信息

| 区域 | 数据来源 | 可为空 | 空值表现 | 可编辑 | 证据 |
|---|---|---|---|---|---|
| Landing 品牌与入口 | local `surface` | 否 | 不适用 | 否 | `landingSurface` |
| Auth form、mode 标题 | `store.mode` | 否 | sign-in/sign-up 文案分支 | 是 | `authFormSurface` |
| notice/error | `store.noticeMessage/errorMessage` | 是 | nil 时隐藏 | 否 | `feedback` |

### 操作入口

| 操作 | 控件 | 位置 | 可用条件 | 触发方法 | 业务结果 | 成功/失败反馈 | 证据 |
|---|---|---|---|---|---|---|---|
| 打开注册/登录 | Button | Landing | `!isSubmitting` | `openForm(_:)` | 仅切 local surface/mode | 无/无 | `landingActions` |
| 返回 Landing | Button | form top bar | 始终 | `surface = .landing` | 本地 UI 切换 | 无 | `formTopBar` |
| 显示/隐藏密码 | Button | password field | 始终 | toggle `isPasswordVisible` | 无业务 mutation | icon/text 切换 | `passwordInput` |
| Submit | Primary Button | form bottom | `!isSubmitting` | `await store.submit()` | Auth sign-in/sign-up repository | root replacement/`errorMessage` | `authActions` |
| 切换 mode | Secondary Button | form bottom | `!isSubmitting` | `switchAuthMode()` | 清/切表单 mode | UI 更新 | `authActions` |

### 表单字段

| 字段 | 控件 | 数据类型 | 必填 | 默认 | 验证 | 错误提示 | 保存目标 |
|---|---|---|---|---|---|---|---|
| Email | `TextField` | String | 是 | `""` | trim/有效 email 由 Store | Auth Error banner | Auth repository |
| Password | `SecureField`/`TextField` | String | 是 | `""` | Store password rules | 同上 | Auth repository |
| Confirm password | `SecureField` | String | 注册时是 | `""` | 与 password 相等 | 同上 | 仅校验，不持久化 |

### 页面状态

| 状态 | 触发 | UI / 操作 | 退出 | 证据 |
|---|---|---|---|---|
| Initial | landing | hero + 2 actions | 打开 form | `surface = .landing` |
| Loaded/Filtered | form + `mode` | sign-in 或 sign-up 字段；mode 可切 | submit/back | local state |
| Saving | `isSubmitting` | ProgressView、按钮 disabled | async 完成 | Store |
| Saved | Auth 成功 | root replacement | 自动 | Auth root state |
| Error/Validation Failed | Store/repository fail | `BeckonErrorBanner` | 修改重试/切 mode | `errorMessage` |
| Disabled | submitting | action buttons disabled | async 完成 | `.disabled` |
| Loading/Empty/Searching/Deleting/Offline/Permission Denied | 未发现独立页面状态 | Offline/permission 可能合并 Error | 重试 | 无专用属性 |

### 页面生命周期行为

`.onAppear` 只启动 landing animation；监听 Reduce Motion。无自动 Auth 请求（Gate 负责 restore）；离开不自动保存。DEBUG quick login 被排除 production。

---

## 页面：角色与资料建立

### 基本信息

- 页面 ID：AUTH-03；类型：`RoleOnboardingView`
- 文件：`Features/Auth/RoleOnboardingView.swift`
- 模块/类型/用户：Auth / Onboarding / 已登录但无 profile 用户。
- 核心目标：选择权威角色并创建 marketplace profile。

### 页面展示的信息

| 区域 | 数据来源 | 可为空 | 空值表现 | 可编辑 | 证据 |
|---|---|---|---|---|---|
| session email | `AuthSessionSnapshot.email` | 是 | 条件隐藏/回退 | 否 | body |
| role choices | `UserRole.allCases` | 否 | 不适用 | 是 | role buttons |
| error | `store.errorMessage` | 是 | nil 隐藏 | 否 | error banner |

### 操作入口

| 操作 | 控件 | 位置 | 条件 | 方法 | 结果 | 反馈 | 证据 |
|---|---|---|---|---|---|---|---|
| 选角色 | 自定义 Button card | form | `!isSubmitting` | `store.selectedRole = role` | 本地 draft | selection style | role card |
| 创建 profile | Button | bottom | role/name valid、非 submitting | `await store.submit()` | `ProfileRepository.createProfile` | role shell / error | submit button |
| Sign Out | Button | toolbar/content | 非 submitting | `onSignOut()` | Auth session 清除 | root replacement/error | signOutButton |

### 表单字段

| 字段 | 控件 | 类型 | 必填 | 默认 | 验证 | 错误 | 保存目标 |
|---|---|---|---|---|---|---|---|
| Display name | TextField | String | 是 | `""` | trimmed non-empty | Store error | MarketplaceProfile |
| Role | Button selection | `UserRole?` | 是 | nil | 必须选择 | Store error | MarketplaceProfile.role |

### 页面状态

Initial/Empty：role nil/name empty，submit disabled；Loaded：form 可编辑；Saving：`isSubmitting` + Progress/disabled；Saved：state 变 customer/groomer；Error/Validation Failed：banner、可修改重试；其余 Loading/Searching/Filtered/Deleting/Offline/Permission Denied 未发现独立 UI（repository 错误合并 Error）。证据：`AuthenticatedEntryStore` fields/`submit()`。

### 页面生命周期行为

父 `AuthenticatedEntryView.task(id: session.userID)` 已调用 profile load；本页离开不自动保存，不监听通知。

---

## 页面：Profile 加载失败

### 基本信息

- 页面 ID：AUTH-04；类型：`AuthenticatedEntryView.loadFailureView(message:)`
- 文件：`Features/Auth/AuthenticatedEntryView.swift`
- 模块/类型/用户：Auth / Utility / 已登录但 profile lookup 失败用户。
- 目标：重试 profile lookup 或登出。

### 页面展示的信息

| 区域 | 来源 | 可为空 | 空值表现 | 可编辑 | 证据 |
|---|---|---|---|---|---|
| Profile Unavailable 错误 | `.failure(message)` | 否 | 不适用 | 否 | `loadFailureView` |

### 操作入口

| 操作 | 控件 | 条件 | 方法 | 结果/反馈 | 证据 |
|---|---|---|---|---|---|
| Retry | Primary Button | 始终 | `await store.retry()` | Loading→role/onboarding/error | failure view |
| Sign Out | destructive Button | `!authenticationStore.isSubmitting` | `signOut()` | AUTH-02 / error | failure view |

### 表单字段

本页面未发现表单字段。

### 页面状态

Error 是进入条件；Loading 在 Retry 后由 parent 条件显示；Disabled 仅 sign-out submitting；Saved 表现为替换到 role shell。其余 Empty/Searching/Filtered/Saving/Deleting/Offline/Permission Denied/Validation Failed 未独立区分。

### 页面生命周期行为

无自有 task；父 entry 监听 session ID并加载。离开无保存。

---

## 页面：Customer Home

### 基本信息

- 页面 ID：CUS-01；类型：`CustomerPetsView`
- 文件：`Features/Customer/Pets/CustomerPetsView.swift`
- 模块/类型/用户：Customer Home/Pets / Tab Root / Customer。
- 目标：聚合 pets、active request、next booking、通知和新建 request 入口。

### 页面展示的信息

| 区域 | 来源 | 可为空 | 空值表现 | 可编辑 | 证据 |
|---|---|---|---|---|---|
| greeting/unread badge | displayName、Notification Store | 否/可 0 | badge 0 | 否 | `CustomerHomeHeader` |
| pets | `CustomerPetsStore.pets`/photo cache | 是 | add-first/empty presentation | 通过 sheet | pet sections |
| active request | Requests Store | 是 | hero/empty action | 否 | request presentation |
| next booking | Bookings Store | 是 | unavailable/empty card | 否 | next booking presentation |

### 操作入口

| 操作 | 控件 | 位置 | 条件 | 方法 | 业务结果 | 成功/失败 | 证据 |
|---|---|---|---|---|---|---|---|
| Notifications | bell Button | header | 始终 | `isShowingNotifications = true` | Push only | destination/error N/A | header action |
| Start request | hero Button | main | eligibility | `startGroomingRequest()` | Store opens wizard | Sheet/error feedback | request hero |
| Add/Edit pet | custom card/buttons | pets | Store not busy | `startCreate/startEdit` | opens pet form | Sheet | pet cards |
| Active request | card Button | main | request exists | callback request ID | switch Requests tab | route/error if missing | callback |
| Booking chat | NavigationLink/card action | main | next booking exists | callback booking | switch Messages/focused | Chat error if missing | next booking card |

### 表单字段

本页面未发现内联表单字段；编辑发生在 CUS-03/CUS-04。

### 页面状态

Initial/Loading：`loadHome()` 并显示 aggregate loading；Loaded：sections；Empty：无 pets/request/booking 的对应 empty surfaces；Error：各 Store feedback；Disabled：request hero eligibility或 Store busy；Filtered/Searching/Saving/Saved/Deleting/Validation Failed 未作为 Home 自有状态；Offline/Permission Denied 合并 Error。证据：`CustomerHomeStatusView`、presentation properties。

### 页面生命周期行为

`.foregroundRefreshable { loadHome() }` 在首次/前台刷新 pets、requests、bookings、notifications；sheet flags驱动子页。无离开自动保存。

---

## 页面：Customer Notifications

### 基本信息

- 页面 ID：CUS-02；类型：`CustomerNotificationsView`
- 文件：`Features/Customer/Notifications/CustomerNotificationsView.swift`
- 模块/类型/用户：Notifications / List / Customer。
- 目标：查看 unread/read 通知并标记已读。

### 页面展示的信息

| 区域 | 来源 | 可为空 | 空值表现 | 编辑 | 证据 |
|---|---|---|---|---|---|
| 通知 rows/unread | `CustomerNotificationsStore.notifications` | 是 | Empty state | mark read | `content` |
| pagination/error | Store flags | 是 | load more/error banner | 否 | body |

### 操作入口

| 操作 | 控件 | 位置 | 条件 | 方法 | 结果 | 反馈 | 证据 |
|---|---|---|---|---|---|---|---|
| Mark all read | Toolbar Button | top trailing | unread > 0、非 busy | `markAllRead()` | repository update/list refresh | badge/notice/error | toolbar |
| Mark one read | row Button | row | item unread | `markRead(_:)` | repository update | row style/error | row |
| Load more | Button | list end | `canLoadMore` | `loadNextPage()` | append deduplicated rows | spinner/error | line 64 |

### 表单字段

本页面未发现表单字段。

### 页面状态

Loading/Loaded/Empty/Error/Disabled（busy/buttons）/Saving（marking read）由 Store flags；Saved 表现为 unread count/row 更新；Filtered 表现为 UI unread styling而非筛选；Searching/Deleting/Validation Failed 未发现；Offline/Permission Denied 合并 Error。

### 页面生命周期行为

Store 由 Home 预加载；进入页显示同一实例。未发现本页 `.task`，无离开保存或通知 observer。

---

## 页面：Pet 创建/编辑表单

### 基本信息

- 页面 ID：CUS-03；类型：`CustomerPetFormView`
- 文件：`Features/Customer/Pets/CustomerPetsView.swift`
- 模块/类型/用户：Pets / Sheet / Customer。
- 目标：创建或编辑 pet 与照片。

### 页面展示的信息

| 区域 | 来源 | 可为空 | 空值表现 | 编辑 | 证据 |
|---|---|---|---|---|---|
| mode/title、现有/pending photos | Pet Store form state | photos 可空 | upload tile | 是 | form body |
| fields | `form*` bindings | 多数可空 | placeholder/default controls | 是 | form sections |

### 操作入口

| 操作 | 控件 | 位置 | 条件 | 方法 | 结果 | 反馈 | 证据 |
|---|---|---|---|---|---|---|---|
| Cancel | Toolbar Button | top | 非 busy | `cancelForm()` | reset + close Sheet | 无 | toolbar |
| Save | Primary Button | bottom | valid、非 busy | `await save()` | pet repository insert/update + photos | close/notice；error保持 | save action |
| Add photo | PhotosPicker | photo section | photo limit/非 busy | `addPendingPhoto` | local pending upload | preview/error | photo picker |
| Remove photo | Button | photo tile | photo exists | pending remove/delete path | pending/remote photo removal | UI/error | photo tile |

### 表单字段

| 字段 | 控件 | 类型 | 必填 | 默认 | 验证 | 错误 | 保存目标 |
|---|---|---|---|---|---|---|---|
| Name | TextField | String | 是 | `""`/existing | trimmed non-empty | form error | CustomerPet.name |
| Species | segmented/buttons | enum | 是 | dog（Store 默认） | supported enum | form error | species |
| Breed | TextField | String | 否 | `""` | trim | error banner | breed |
| Coat type | choice chips | enum | 否 | `.notSure` | supported taxonomy value | form error | coatType |
| Weight | Slider 5...101 step 1 | Double | 否 | Store value | range enforced by Slider | 无独立 | weight |
| Birthday known/date | Toggle + DatePicker | Bool/Date | 否 | false/current | date selection | form error | birthday |
| Notes/medical/temperament | multiline TextField | String | 否 | `""` | trim/Store limits | error banner | pet fields |
| Photos | PhotosPicker | Data | 否 | empty/existing | readable image/limits | Store error | pet photo repository/storage |

### 页面状态

Initial=create defaults或 edit snapshot；Loaded=form；Empty=photo empty；Saving/Deleting/Disabled=`isSaving/isUploading/isBusy`；Saved=flag false关闭；Error/Validation Failed=error banner且保留输入；Searching/Filtered/Offline/Permission Denied 未独立实现。

### 页面生命周期行为

Sheet presentation前 Store初始化 draft；PhotosPicker change有上传副作用。Cancel/成功保存显式关闭；离开手势 dismiss 是否调用 draft reset：待确认（无 `onDisappear`）。

---

## 页面：Grooming Request Wizard

### 基本信息

- 页面 ID：CUS-04；类型：`CustomerRequestWizardView`
- 文件：`Features/Customer/Requests/CustomerRequestWizardView.swift`
- 模块/类型/用户：Requests / Sheet / Customer。
- 目标：形成并发布 request/republish draft。

### 页面展示的信息

| 区域 | 来源 | 可为空 | 空值表现 | 编辑 | 证据 |
|---|---|---|---|---|---|
| progress/current step | Store wizard state | 否 | 不适用 | navigation buttons | header/bottom bar |
| pets/services/time/location/photos/fit/review | Store + taxonomy/profile | 部分可空 | add/validation prompts | 是 | step views |

### 操作入口

| 操作 | 控件 | 条件 | 方法 | 结果 | 反馈 | 证据 |
|---|---|---|---|---|---|---|
| Close/Back/Next | custom Buttons | step/validation/submitting | Store step methods/cancel | local wizard navigation/close | inline error | header/bottom |
| Select pet/service/date/time/location/fit | cards/buttons/toggle/menus/sliders | option available | bindings/setters | draft update | selected style | step components |
| Add pet | custom Button | closure provided | `onAddPet()` | closes wizard then opens pet sheet | parent-driven | add pet button |
| Add photo | PhotosPicker | limit/非 submitting | `addPendingRequestPhoto` | pending draft photo | tile/error | photo step |
| Publish | Primary Button | final step + valid | Store publish method | repository/RPC create request | close/notice；error保留 | bottom bar |

### 表单字段

| 字段组 | 控件 | 类型 | 必填 | 默认 | 验证/错误 | 保存目标 |
|---|---|---|---|---|---|---|
| Pet | choice cards | UUID | 是 | preselected/none | pet required | request draft snapshot |
| Service | option cards | enum | 是 | none | service required | service type |
| Date/time | custom strip/buttons + DatePickers | Date | 是 | Store proposed defaults | end > start/future/window | preferred window |
| Flexible time | Toggle | Bool | 否 | Store default | 无独立 | flexibility |
| Location mode | cards | enum | 是 | none/default | mode required | location mode |
| Address | TextFields + Menu suggestions/state | Strings/enum | mode-dependent | profile/empty | address completeness/ZIP | request address |
| Service notes | multiline TextField | String | 否 | `""` | Store length/trim | notes |
| Radius/fit sliders/chips | Slider/Buttons | numeric/sets | 否 | Store defaults | bounded controls | matching inputs |
| Photos | PhotosPicker | Data[] | 否 | empty | readable/limit | request Storage metadata |

### 页面状态

Initial=draft created；Loaded=current step；Empty=no pets有 add-pet path；Filtered=pet/service/fit choices by current data；Saving/Disabled=publishing；Saved=Sheet closes；Error/Validation Failed=inline/global feedback，保留 draft；Loading=dependent pets/profile may load before/on appear；Searching 是 address suggestion object但无 `.searchable` 页面；Deleting=remove pending photo local；Offline/Permission Denied 合并 Error。

### 页面生命周期行为

`.onAppear` prepares wizard/address defaults；bindings持续写 Store。照片读取有副作用。Cancel丢弃 sheet draft；无离开自动保存。

---

## 页面：Customer Requests

### 基本信息

- 页面 ID：CUS-05；类型：`CustomerRequestsView`
- 文件：`Features/Customer/Requests/CustomerRequestsView.swift`（dashboard 子视图在相邻文件）
- 模块/类型/用户：Requests / Tab Root / Customer。
- 目标：查看 request timeline、offers/action cards、cancelled items并创建/取消/republish。

### 页面展示的信息

| 区域 | 来源 | 可为空 | 空值表现 | 编辑 | 证据 |
|---|---|---|---|---|---|
| active progress/timeline/action cards | Requests Store | 是 | `CustomerRequestsEmptyDashboard` | 通过详情/操作 | dashboard views |
| cancelled requests、pagination | Store | 是 | section隐藏 | republish | cancelled section |

### 操作入口

| 操作 | 控件 | 条件 | 方法 | 结果 | 反馈 | 证据 |
|---|---|---|---|---|---|---|
| New request | Toolbar Button | 非 busy | wizard start | opens Sheet | wizard/error | toolbar |
| Open request | NavigationLink/card | item exists | push | CUS-06 | destination missing state | dashboard |
| Cancel request | Button + Alert | cancellable | select + `cancel` | repository mutation/refresh | notice/error | alert |
| Republish | Button | cancelled eligible | Store republish draft | wizard Sheet | publish feedback | action row |
| Booking handoff/chat | Button/Navigation destination | booking exists | set handoff/callback | detail或Messages | route feedback | dashboard |
| Load more | custom button | `canLoadMore` | `loadNextPage()` | append | progress/error | Store/status |

### 表单字段

本页面未发现内联表单字段；新建/republish 使用 CUS-04。

### 页面状态

Initial/Loading=Store load；Loaded=dashboard；Empty=empty dashboard；Error=global feedback；Disabled/Saving/Deleting=Store busy/cancelling/publishing flags；Saved=notice + refreshed state；Filtered=视图按 request status 分组；Searching 未发现；Offline/Permission Denied合并 Error；Validation Failed发生在 wizard而非本页。

### 页面生命周期行为

进入/前台由 Store load/refresh；监听 `focusedRequestID` 以程序化打开。sheet/alert/destination由 bindings驱动；离开不保存。

---

## 页面：Customer Request Detail

### 基本信息

- 页面 ID：CUS-06；类型：`CustomerRequestDetailView`
- 文件：`Features/Customer/Requests/CustomerRequestDetailView.swift`
- 模块/类型/用户：Requests / Detail / request owner Customer。
- 目标：查看完整 request、照片、状态、offers及后续 handoff。

### 页面展示的信息

| 区域 | 来源 | 可空 | 空值表现 | 编辑 | 证据 |
|---|---|---|---|---|---|
| pet/request facts、location/time/status | `CustomerGroomingRequest` | 否 | request missing显示 unavailable status | 否 | body branches |
| photos/offers/booking/republish | Store related data | 是 | section隐藏/empty explanation | action only | photo/offer sections |

### 操作入口

| 操作 | 控件 | 条件 | 方法 | 结果 | 反馈 | 证据 |
|---|---|---|---|---|---|---|
| Open Offer | NavigationLink | offer exists | push | CUS-07 | 无 | offer section |
| Accept Offer | 由 Offer detail | eligible | Store accept | booking/conversation created | refreshed/error | child action |
| Republish | Button | cancelled/eligible | Store republish | CUS-04 via parent state | feedback | republish card |
| Booking/chat handoff | Button | booking exists | callbacks | CUS-09/Message tab | route feedback | action cards |

### 表单字段

本页面未发现表单字段。

### 页面状态

Initial/Loading related photos/offers via `.task(id: request.id)`；Loaded；Empty（无 offers/photos）；Error；Disabled/ Saving由 Store mutation flags；Saved=authoritative refresh；Filtered=offer eligibility/status presentation；Searching/Deleting/Offline/Permission Denied/Validation Failed 未独立实现。

### 页面生命周期行为

request ID task加载关联数据；Store变化会重新渲染。无离开保存。

---

## 页面：Customer Offer Detail

### 基本信息

- 页面 ID：CUS-07；类型：`CustomerOfferDetailView`（private）
- 文件：`Features/Customer/Requests/CustomerRequestDetailView.swift`
- 模块/类型/用户：Offers / Detail / request owner Customer。
- 目标：评估并接受 Groomer offer。

### 页面展示的信息

| 区域 | 来源 | 可空 | 空值表现 | 编辑 | 证据 |
|---|---|---|---|---|---|
| groomer、price、time、message、fit evidence/status | offer/request Store data | message/evidence可空 | section隐藏/empty copy | 否 | detail cards |

### 操作入口

| 操作 | 控件 | 条件 | 方法 | 结果 | 反馈 | 证据 |
|---|---|---|---|---|---|---|
| Accept Offer | Primary Button | offer/request eligible、非 busy | `await store.acceptOffer(...)` | atomic booking/conversation | notice/refreshed；error banner | accept button |

### 表单字段

本页面未发现表单字段。

### 页面状态

Loaded/Empty(optional evidence)/Disabled/Saving/Saved/Error按 offer eligibility与 Store flags；Validation Failed/Permission/conflict均映射 Error；Loading/Searching/Filtered/Deleting/Offline 未专门显示。

### 页面生命周期行为

共享父 Store；无自有 task或保存；accept 后响应 Store刷新。

---

## 页面：Customer Bookings

### 基本信息

- 页面 ID：CUS-08；类型：`BookingsView(role: .customer)`
- 文件：`Features/Bookings/BookingsView.swift`
- 模块/类型/用户：Bookings / Tab Root / Customer。
- 目标：按状态查看 booking并进入 detail或 republish。

### 页面展示的信息

| 区域 | 来源 | 可空 | 空值 | 编辑 | 证据 |
|---|---|---|---|---|---|
| filtered booking rows/metadata | `BookingsStore.bookings` | 是 | `BeckonEmptyState` | 否 | customer content |
| scope selector/pagination | local `BookingListScope`/Store | 否/可无下一页 | selected style/隐藏 load more | 是筛选 | scope control |

### 操作入口

| 操作 | 控件 | 条件 | 方法 | 结果 | 反馈 | 证据 |
|---|---|---|---|---|---|---|
| Filter scope | custom Buttons | always | local scope assign | filtered list | UI selection | `BookingScopeControl` |
| Open booking | NavigationLink | row exists | push | CUS-09 | 无 | list row |
| Republish | Button | cancelled eligible | request Store start | CUS-04 Sheet | wizard/error | empty/action area |
| Load more | Button | Store canLoadMore | `loadNextPage()` | append | progress/error | load more |

### 表单字段

本页面未发现表单字段。

### 页面状态

Initial/Loading/Loaded/Empty/Error；Filtered由 `BookingListScope`；Disabled/LoadingMore由 Store；Saving/Saved/Deleting只在 detail/wizard；Searching/Offline/Permission Denied/Validation Failed未独立实现。

### 页面生命周期行为

`.task`/foreground refresh加载 bookings；scope是本地 disposable state。无离开保存。

---

## 页面：Customer Booking Detail

### 基本信息

- 页面 ID：CUS-09；类型：`BookingDetailView(role: .customer)`
- 文件：`Features/Bookings/BookingsView.swift`
- 模块/类型/用户：Bookings/Reviews / Detail / booking Customer participant。
- 目标：管理 booking、聊天和 completed review。

### 页面展示的信息

| 区域 | 来源 | 可空 | 空值 | 编辑 | 证据 |
|---|---|---|---|---|---|
| booking hero/status/time/location/partner/request | `BookingsStore.booking(id)` | 可因刷新移除 | unavailable status view | 否 | detail body |
| existing review或review form | Booking review state | 是 | eligible时显示 form，否则隐藏 | 是 | review branches |

### 操作入口

| 操作 | 控件 | 条件 | 方法 | 结果 | 反馈 | 证据 |
|---|---|---|---|---|---|---|
| Open Chat | Button | booking supports chat | `onOpenChat(booking)` | switch Messages | route feedback | action bar |
| Cancel | Button | Customer cancellable | `await store.cancel` | repository update | notice/error | action bar |
| Submit Review | Button | completed、无 review、valid | `store.createReview` | review repository/RPC | review display/notice；error | review form |

### 表单字段

| 字段 | 控件 | 类型 | 必填 | 默认 | 验证 | 错误 | 保存目标 |
|---|---|---|---|---|---|---|---|
| Rating | Picker | Int | 是 | 5（View state） | supported range | Store error | Review.rating |
| Review content | TextEditor | String | 依 Store contract | empty | trim/length | Store error | Review.content |
| Fit outcome | Picker(s) | enum selections | 否/contract-dependent | nil/default | supported choices | Store error | review fit outcomes |

### 页面状态

Loaded/Empty(booking unavailable)/Error；Disabled/Saving=`isCancelling/isSubmittingReview`；Saved=booking/review刷新；Validation Failed=review validation；Deleting不适用；Loading继承列表 Store；Searching/Filtered/Offline/Permission Denied未专用。

### 页面生命周期行为

共享 Bookings Store，无自有 load；操作后 Store替换 booking。离开不保存 review draft。

---

## 页面：Customer Messages

### 基本信息

- 页面 ID：CUS-10；类型：`ChatConversationsView(role: .customer)`
- 文件：`Features/Chat/ChatView.swift`
- 模块/类型/用户：Chat / Tab Root / Customer participant。
- 目标：查看 conversations/unread并进入 thread。

### 页面展示的信息

| 区域 | 来源 | 可空 | 空值 | 编辑 | 证据 |
|---|---|---|---|---|---|
| conversation rows、partner/booking/unread | `ChatStore.conversations` | 是 | empty state | 否 | content |

### 操作入口

| 操作 | 控件 | 条件 | 方法 | 结果 | 反馈 | 证据 |
|---|---|---|---|---|---|---|
| Open thread | NavigationLink/programmatic destination | conversation exists | push; `markConversationRead` | CUS-11/local unread clear | error if focused missing | links/focused method |
| Load more | Button | `canLoadMoreConversations` | Store load | append | progress/error | list end |
| Refresh | foreground refresh | foreground | `loadConversations()` | authoritative list | status feedback | task/gate |

### 表单字段

本页面未发现表单字段。

### 页面状态

Initial/Loading/Loaded/Empty/Error/Disabled/loading-more；Filtered仅 unread presentation，不是列表筛选；Saving/Deleting/Validation/Searching/Offline/Permission未独立。Focused route missing产生 Error。

### 页面生命周期行为

`.task` 首次 load；foreground refresh；监听 `focusedBookingID` 与 scene phase，找到 conversation 后程序化 push并清 ID。

---

## 页面：Customer Chat Thread

### 基本信息

- 页面 ID：CUS-11；类型：`ChatThreadView(role: .customer)`
- 文件：`Features/Chat/ChatView.swift`
- 模块/类型/用户：Chat / Detail / conversation Customer participant。
- 目标：读取历史并发送 text message。

### 页面展示的信息

| 区域 | 来源 | 可空 | 空值 | 编辑 | 证据 |
|---|---|---|---|---|---|
| header/booking context/messages | conversation + `ChatStore.messages` | messages可空 | thread empty/status | message draft | thread body |
| read-only reason | booking/conversation state | 是 | nil隐藏 | 否 | `ChatReadOnlyBanner` |

### 操作入口

| 操作 | 控件 | 条件 | 方法 | 结果 | 反馈 | 证据 |
|---|---|---|---|---|---|---|
| Back | Button | always | `dismiss()` | pop Messages | 无 | header |
| Load older | Button/scroll trigger | has previous page | Store prepend | older messages | progress/error | history control |
| Send | Button | draft non-empty、writable、非 sending | Store `sendMessage` | repository insert + append | draft clear/error | composer |

### 表单字段

| 字段 | 控件 | 类型 | 必填 | 默认 | 验证 | 错误 | 保存目标 |
|---|---|---|---|---|---|---|---|
| Message | multiline TextField | String | 是 | `""` | trimmed non-empty；writable | Chat error | Message body |

### 页面状态

Loading/Loaded/Empty/Error；Disabled=read-only/sending/empty draft；Saving=send；Saved=message append/draft clear；Validation Failed=empty disables；Filtered=reader anchor/window；Searching/Deleting/Offline/Permission未专用。

### 页面生命周期行为

`.task(id: conversation.id)` load thread并 mark read；`onAppear`/scroll logic维护 anchor；离开不保存 draft，未发现 realtime listener。

---

## 页面：Customer Account

### 基本信息

- 页面 ID：CUS-12；类型：`CustomerAccountView`
- 文件：`Features/Customer/Profile/CustomerProfileSettingsView.swift`
- 模块/类型/用户：Account / Tab Root / Customer。
- 目标：查看 profile summary、进入设置/外部支持、sign out/delete。

### 页面展示的信息

| 区域 | 来源 | 可空 | 空值 | 编辑 | 证据 |
|---|---|---|---|---|---|
| display name/detail/avatar/role | Customer Profile Store | avatar可空 | default avatar | 通过 settings | profile card |
| release links/Auth error | constants/Auth Store | error可空 | 隐藏 | 否 | sections |

### 操作入口

Profile Settings（NavigationLink→CUS-13）；Privacy/Support/Terms（`Link`→external）；Sign Out（AccountDangerActions Button→Auth Store）；Delete Account（Button→CUS-14）。条件：Auth action非 submitting。成功 root replacement或外部系统；失败 Auth error banner。证据：`CustomerAccountView.body`、shared account primitives。

### 表单字段

本页面未发现表单字段。

### 页面状态

Initial/Loading=`store.load()`且 background feedback；Loaded；Empty profile details用 fallback；Error；Disabled/Saving/Deleting由 Auth/Profile Store；Saved表现为 profile card刷新；其余 Searching/Filtered/Offline/Permission/Validation未独立。

### 页面生命周期行为

`.task { await store.load() }`；响应 profile Store变化；无离开保存。DEBUG Console入口不属于 production。

---

## 页面：Customer Profile Settings

### 基本信息

- 页面 ID：CUS-13；类型：`CustomerProfileSettingsView`
- 文件：`Features/Customer/Profile/CustomerProfileSettingsView.swift`
- 模块/类型/用户：Account/Profile / Settings / Customer。
- 目标：编辑 contact/address/avatar。

### 页面展示的信息

profile/avatar/contact/address 来自 `CustomerProfileStore`，profile可初始为空时显示 loading，avatar可空显示 default。全部字段可编辑；证据：settings body/status view。

### 操作入口

Save Profile（Button→`saveProfile`；非 saving/uploading；成功 notice且停留，失败 error）；Upload/Replace Photo（PhotosPicker→encoder→`uploadAvatarPhoto`；成功更新图，失败 error）；address suggestion Button（resolve并回填，仅本地/系统 geocoder）。Back由NavigationStack。

### 表单字段

| 字段 | 控件 | 类型 | 必填 | 默认 | 验证 | 错误 | 保存目标 |
|---|---|---|---|---|---|---|---|
| Nickname | TextField | String | 是/Store contract | profile display name | trim | Profile error | CustomerProfile.nickname |
| Email | TextField | String | 否/contract | session/profile | email format | error | contactEmail |
| Phone | TextField | String | 否 | existing/empty | Store normalization | error | phoneNumber |
| Street/City/ZIP | TextFields | String | address group-dependent | existing/empty | address draft validation | error | profile address |
| State | Menu | `USStateCode?` | 否 | existing/nil | enum | error | state |
| Avatar | PhotosPicker | Data | 否 | existing/none | readable PNG/JPEG | “could not read”/Store error | Storage/avatar path |

### 页面状态

Initial/Loading/Loaded；Empty avatar；Saving/Disabled；Saved notice；Error/Validation Failed；Searching=address suggestions（无 searchable modifier）；Filtered=suggestions prefix(4)；Deleting未发现；Offline/Permission合并 Error。

### 页面生命周期行为

父 Account已 load同一 Store；字段 binding实时更改 draft，地址 field变化触发 address search。离开不自动保存，无 unsaved confirmation。

---

## 页面：删除账户双重确认

### 基本信息

- 页面 ID：CUS-14；类型：`AccountDangerActions` + system dialogs
- 文件：`Features/Auth/AuthenticatedAccountView.swift`
- 模块/类型/用户：Account/Auth / Utility / authenticated Customer。
- 目标：以两次确认执行不可逆 account deletion。

### 页面展示的信息

两层 warning和删除影响说明，来自静态 UI；无可空数据/编辑字段。

### 操作入口

Delete Account Button→`showsDeletionWarning=true`；Continue→final alert；Cancel关闭；最终 Delete→`authenticationStore.deleteAccount()`；成功清 session/root replacement，失败回 Account error。控件在 Store submitting时 disabled。证据：`AccountDangerActions.body`。

### 表单字段

本页面未发现表单字段。

### 页面状态

Initial隐藏；Loaded=dialog/alert显示；Deleting=`isSubmitting`；Saved=Root替换到 Auth；Error=父 Account banner；Disabled=submitting；其余 Loading/Empty/Searching/Filtered/Saving/Offline/Permission/Validation未独立。

### 页面生命周期行为

纯本地 Bool驱动系统 UI；delete有远端与local cleanup副作用。dismiss/Cancel不保存。

---

## 页面：Groomer Home

### 基本信息

- 页面 ID：GRM-01；类型：`GroomerHomeView`
- 文件：`Features/Groomer/Home/GroomerHomeView.swift`
- 模块/类型/用户：Groomer Home / Tab Root / Groomer。
- 目标：显示 next booking、attention counts、availability和快捷路由。

### 页面展示的信息

header/avatar/unread、next booking、matches/offers/messages attention、availability summary来自 `GroomerHomeStore` + Notification/Chat counts；各项可空，使用 loading/unavailable/empty surfaces；只读。

### 操作入口

Bell NavigationLink→GRM-02；Requests/Offers/Messages/Booking/Availability custom Button rows/cards→shell callbacks；可用条件取决于 presentation/data readiness。只改变路由，不直接 mutation。证据：Home body和传入 actions。

### 表单字段

本页面未发现表单字段。

### 页面状态

Initial/Loading/Loaded/Empty/partial Error（`loadIssues`/unavailable sections）；Disabled=route/data readiness；Saved/Saving/Deleting/Validation/Searching/Filtered未实现；Offline/Permission通常表现为 load issue。

### 页面生命周期行为

`.task { await store.load() }`，foreground refresh；读取cache-first avatar/private image。无离开保存。

---

## 页面：Groomer Notifications

### 基本信息

- 页面 ID：GRM-02；类型：`GroomerNotificationsView`
- 文件：`Features/Groomer/Notifications/GroomerNotificationsView.swift`
- 模块/类型/用户：Notifications / List / Groomer。
- 目标：读/标记通知并路由业务 tab。

### 页面展示的信息

notification rows/unread/route/pagination来自 `GroomerNotificationsStore`；为空显示 empty。不可编辑内容，read state可 mutation。

### 操作入口

Mark all read toolbar Button；row Button执行 mark read并调用 `routeAction(notification.route)`；Load more Button。条件由 unread/busy/canLoadMore。成功更新badge/路由，失败 error。证据：View body/row、Store methods。

### 表单字段

本页面未发现表单字段。

### 页面状态

Loading/Loaded/Empty/Error/Disabled/Saving(read mutation)/Saved；Filtered只体现read styling；Searching/Deleting/Validation/Offline/Permission无专用。

### 页面生命周期行为

Home/shell预加载 store；无自有 task。row action可产生跨 tab副作用。

---

## 页面：Groomer Requests

### 基本信息

- 页面 ID：GRM-03；类型：`GroomerRequestsView`
- 文件：`Features/Groomer/Requests/GroomerRequestsView.swift`
- 模块/类型/用户：Requests/Offers / Tab Root / Groomer。
- 目标：在 Matches/Offers segment查看、分页并进入 detail。

### 页面展示的信息

segment header、matched request rows、offer groups、photos/status来自 `GroomerRequestsStore`/`GroomerOffersStore`；列表可空，显示各 segment empty。

### 操作入口

segment Buttons→写 `route.segment`；Refresh toolbar→并行/顺序 load stores；row NavigationLink/focused destination→GRM-04/05；Dismiss/Withdraw quick buttons（若显示）→Store methods；Load more→对应 Store。成功刷新/notice，失败 error。

### 表单字段

本页面未发现内联字段；offer form在 GRM-04。

### 页面状态

Initial/Loading/Loaded/Empty/Error；Filtered=Matches/Offers segment；Disabled/Saving/Deleting=Store busy/dismiss/withdraw；Saved=lists refreshed；Searching/Validation/Offline/Permission无专用。

### 页面生命周期行为

进入 `.task` load；监听 route变化并消费 requestID/offerID做programmatic navigation；foreground refresh。无离开保存。

---

## 页面：Groomer Request Detail / Create Offer

### 基本信息

- 页面 ID：GRM-04；类型：`GroomerRequestDetailView`
- 文件：`Features/Groomer/Requests/GroomerRequestsView.swift`
- 模块/类型/用户：Requests/Offers / Create / matched Groomer。
- 目标：评估 match、dismiss或提交 offer。

### 页面展示的信息

request/pet/location/time/photos/fit evidence、existing offer状态来自 matched request和Stores；photo/evidence可空，section隐藏/placeholder；offer fields可编辑。

### 操作入口

Dismiss Match Button→`requestsStore.dismiss`；Withdraw（existing eligible）→Store；Submit Offer→`submitOffer(...)`；日期控件/字段修改local draft。busy时disabled。成功刷新/notice但未明确pop；失败error。

### 表单字段

| 字段 | 控件 | 类型 | 必填 | 默认 | 验证 | 错误 | 保存目标 |
|---|---|---|---|---|---|---|---|
| Proposed start/end | DatePicker | Date | 是 | `defaultOfferRange` | end > start/future/conflict由 Store/backend | Store error | offer times |
| Price estimate | TextField | String→numeric | 是 | empty/existing | parse positive price | error | offer price |
| Message | multiline TextField | String | 否 | `""` | trim/limits | error | offer message |

### 页面状态

Initial defaults via `.task(id: request.id)`；Loaded；Empty optional photos/evidence；Saving/Disabled submit；Deleting/dismissing/withdrawing；Saved refreshed；Error/Validation Failed；Filtered by match/offer eligibility；Loading related photos；Offline/Permission合并 Error；Searching无。

### 页面生命周期行为

request ID task初始化 form/load photos；local draft不会自动保存。操作后响应 Store变化；未确认自动pop。

---

## 页面：Groomer Offer Detail

### 基本信息

- 页面 ID：GRM-05；类型：`GroomerOfferDetailView`
- 文件：`Features/Groomer/Offers/GroomerOffersView.swift`
- 模块/类型/用户：Offers / Detail / offer owner Groomer。
- 目标：查看 offer/request/booking/message状态并撤回 eligible offer。

### 页面展示的信息

hero、facts、request、booking、message cards来自 `GroomerOfferSummary`；booking/message可空，section条件显示；只读。

### 操作入口

Withdraw Button（eligible且非 busy）→`GroomerOffersStore.withdraw`；成功刷新/notice，失败 error，未发现dismiss。Back为系统导航。

### 表单字段

本页面未发现表单字段。

### 页面状态

Loaded/Empty optional cards/Error/Disabled/Deleting(withdraw)/Saved；Loading继承Store；Filtered按offer status presentation；Searching/Saving/Validation/Offline/Permission无专用。

### 页面生命周期行为

共享 Offers Store，无自有task；响应 Store变更。

---

## 页面：Groomer Schedule

### 基本信息

- 页面 ID：GRM-06；类型：`BookingsView(role: .groomer)`
- 文件：`Features/Bookings/BookingsView.swift`
- 模块/类型/用户：Bookings / Tab Root / Groomer。
- 目标：按日期浏览 appointment timeline。

### 页面展示的信息

day strip、selected day summary、timeline rows/empty day来自 `GroomerSchedulePresentation(Store.bookings)`；可无当天 booking，显示 empty day。

### 操作入口

日期 Button chips→local selected date；appointment NavigationLink→GRM-07；load more→Store；refresh→load。条件由可用 dates/canLoadMore。仅导航/筛选，无表单。

### 表单字段

本页面未发现表单字段。

### 页面状态

Initial/Loading/Loaded/Empty/Error；Filtered=selected day；Disabled/loading-more；Saved/Saving/Deleting在detail；Searching/Validation/Offline/Permission无专用。

### 页面生命周期行为

首次/foreground load；selected date为local state，离开不保存。

---

## 页面：Groomer Booking Detail

### 基本信息

- 页面 ID：GRM-07；类型：`BookingDetailView(role: .groomer)`
- 文件：`Features/Bookings/BookingsView.swift`
- 模块/类型/用户：Bookings / Detail / booking Groomer participant。
- 目标：查看、取消、完成 booking或进入chat。

### 页面展示的信息

同 CUS-09 shared hero/facts/partner/status；review display可读但不显示Customer review form。

### 操作入口

Open Chat callback；Cancel→`BookingsStore.cancel`；Complete→`BookingsStore.complete`。可用性由 `BookingDetailActionPresentation`/status/Store busy。成功更新detail/notice，失败error。

### 表单字段

本页面未发现表单字段。

### 页面状态

Loaded/Empty/Error/Disabled；Saving=`isCancelling/isCompleting`；Saved=booking status刷新；Validation/Permission/conflict合并Error；Loading继承Store；其余Searching/Filtered/Deleting/Offline未专用。

### 页面生命周期行为

共享 Store，无自有task；操作后重渲染。离开无保存。

---

## 页面：Groomer Messages

### 基本信息

- 页面 ID：GRM-08；类型：`ChatConversationsView(role: .groomer)`
- 文件：`Features/Chat/ChatView.swift`
- 模块/类型/用户：Chat / Tab Root / Groomer。
- 核心目标、信息、控件、状态与 lifecycle同 CUS-10；role改变标题/presentation和participant scope。

### 页面展示的信息

Groomer conversation rows、booking partner、unread、pagination；Store可空显示 empty。

### 操作入口

row Push、focused booking programmatic Push、load more、foreground refresh。成功进入 GRM-09；focused conversation不存在时 Store error。

### 表单字段

本页面未发现表单字段。

### 页面状态

Initial/Loading/Loaded/Empty/Error/Disabled；其余Searching/Filtered/Saving/Saved/Deleting/Offline/Permission/Validation无独立差异。

### 页面生命周期行为

`.task` load，监听 scene/focused ID；无离开保存。

---

## 页面：Groomer Chat Thread

### 基本信息

- 页面 ID：GRM-09；类型：`ChatThreadView(role: .groomer)`
- 文件：`Features/Chat/ChatView.swift`
- 模块/类型/用户：Chat / Detail / Groomer participant。
- 目标：读取/发送 booking text chat。

### 页面展示的信息

同 CUS-11，以 Groomer role调整 header/row alignment/context。

### 操作入口

Back、load older、Send；条件/方法/结果与 CUS-11相同。

### 表单字段

Message：multiline TextField/String/trimmed non-empty/writable；保存到 Chat repository message。

### 页面状态

Loading/Loaded/Empty/Error/Disabled/Saving/Saved/Validation Failed；Searching/Filtered/Deleting/Offline/Permission无专用。

### 页面生命周期行为

conversation task load/mark read；无 realtime listener，离开不保存 draft。

---

## 页面：Groomer Account

### 基本信息

- 页面 ID：GRM-10；类型：`GroomerProfileManagementView` + `GroomerAccountHomeView`
- 文件：`Features/Groomer/Profile/GroomerProfileManagementView.swift`、`GroomerProfileAccountView.swift`
- 模块/类型/用户：Groomer Profile / Tab Root / Groomer。
- 目标：聚合 business、matching/schedule、support settings入口与Sign Out。

### 页面展示的信息

profile/avatar/location/status、service/portfolio/availability/fit/evidence counts来自 `GroomerProfileStore`；profile可加载失败/为空显示 loading或fallback summaries。

### 操作入口

NavigationLinks：Edit Profile、Services、Portfolio、Availability、Fit Signals、Evidence；External Links：Privacy/Support；Sign Out Button→Auth store。Home requested route可程序化Push Availability。成功为导航/root replacement，失败由profile/Auth feedback。

### 表单字段

本页面未发现表单字段。

### 页面状态

Initial/Loading=`shouldShowInitialLoading`；Loaded；Empty summaries；Error；Disabled/ Saving/Deleting由共享Store/SignOut；Saved=summary刷新；Searching/Filtered/Offline/Permission/Validation无专用。

### 页面生命周期行为

`.task { store.load(); activateRequestedRouteIfReady() }`；监听 `requestedRoute`；service form Sheet挂在本页；无离开保存。

---

## 页面：Edit Groomer Profile

### 基本信息

- 页面 ID：GRM-11；类型：`GroomerProfileEditorView`
- 文件：`Features/Groomer/Profile/GroomerProfileFormView.swift`
- 模块/类型/用户：Groomer Profile / Edit / Groomer。
- 目标：编辑business identity、地址、服务半径/模式、active和avatar。

### 页面展示的信息

profile draft/avatar/address suggestions来自 Groomer Profile Store/address search；字段可编辑，avatar可空显示默认。

### 操作入口

Save Profile Button→`store.saveProfile()`；PhotosPicker→`uploadAvatarPhoto`；address suggestion Button→resolve/apply；location mode/active controls更新 bindings。busy时disabled。成功notice停留；失败error。

### 表单字段

| 字段组 | 控件 | 类型/必填 | 默认 | 验证/错误 | 保存目标 |
|---|---|---|---|---|---|
| Business name | TextField | String/是 | profile/empty | trimmed non-empty | GroomerProfile |
| Bio | multiline TextField | String/否 | empty | Store limits | bio |
| Years experience | `GroomerExperiencePicker` | Int/否 | 0/profile | picker允许值 | yearsExperience |
| Street/City/State/ZIP | TextFields + Menu | address fields | profile/empty | `makeProfileDraft` validation | base address |
| Service radius | Slider/custom range | Int | 12/profile | bounded | serviceRadiusMiles |
| Location modes | Toggle/buttons | Set enum | profile/empty | at least contract-dependent | modes |
| Active | Toggle | Bool | false/profile | none | isActive |
| Avatar | PhotosPicker | Data/否 | existing | readable image | Storage/avatar path |

### 页面状态

Initial populated from Store；Loaded；Searching/Filtered=address suggestions；Saving/Uploading/Disabled；Saved notice；Error/Validation Failed；Empty avatar；Deleting未发现；Offline/Permission合并 Error。

### 页面生命周期行为

共享 Store已load；address input触发 search，PhotosPicker有上传副作用。Back不自动保存/确认。

---

## 页面：Services

### 基本信息

- 页面 ID：GRM-12；类型：`GroomerServicesEditorView`
- 文件：`Features/Groomer/Profile/GroomerServicesEditorView.swift`
- 模块/类型/用户：Groomer Services / Settings / Groomer。
- 目标：查看、创建、编辑、删除services。

### 页面展示的信息

service rows/type/price/duration/size policy/active来自 Store；列表可空显示 empty。

### 操作入口

Add toolbar Button→`startCreateService`；row Edit→`startEditService`；row Menu含 Edit/Delete；Delete→`deleteService`；均由 shared Store busy限制。Add/Edit打开 GRM-13；delete成功列表更新，失败error。

### 表单字段

本页面未发现内联表单字段。

### 页面状态

Loaded/Empty/Error；Disabled/Saving/Deleting=`isBusy`；Saved=rows/notice更新；Loading继承Account Store；Filtered=service type Menu只用于动作/显示，不是search；Searching/Validation/Offline/Permission无专用。

### 页面生命周期行为

共享 Store，无自有load；sheet在父Management挂载。离开无保存。

---

## 页面：Service 创建/编辑表单

### 基本信息

- 页面 ID：GRM-13；类型：`GroomerServiceFormView`
- 文件：`Features/Groomer/Profile/GroomerServicesEditorView.swift`
- 模块/类型/用户：Groomer Services / Sheet / Groomer。
- 目标：新增/更新单项 service。

### 页面展示的信息

form title/type/details/custom size/active来自 shared Store；edit/create defaults不同。

### 操作入口

Cancel toolbar→`cancelServiceForm()`；Save bottom→`saveService()`；service type Picker/Menu、custom size Toggle/slider、active Toggle更新 draft。成功 flag false关闭 Sheet/notice；失败保持/error。

### 表单字段

| 字段 | 控件 | 类型 | 必填 | 默认 | 验证 | 错误 | 保存目标 |
|---|---|---|---|---|---|---|---|
| Type | custom Picker | enum | 是 | fullGroom/existing | supported type | form error | GroomerService.type |
| Title | TextField | String | 是 | type title/existing | trimmed non-empty | error | title |
| Description | TextField | String | 否 | empty/existing | trim | error | description |
| Base price | TextField | String→Double | 是 | empty/existing | parse positive | error | basePrice |
| Duration | TextField | String→Int | 是 | empty/existing | parse positive | error | durationMinutes |
| Visible | Toggle | Bool | 否 | true/existing | none | error | isActive |
| Custom size policy | Toggle + range slider/size toggles | Bool/range | 否 | false/existing | normalized lower≤upper | error | acceptedPetSizes |

### 页面状态

Initial create/edit；Loaded；Saving/Disabled；Saved closes；Error/Validation Failed保持；Deleting不在form；Empty description/sizes allowed by contract；Searching/Filtered/Offline/Permission无专用。

### 页面生命周期行为

由 Store start method准备 draft；Cancel/成功显式reset。手势dismiss是否reset待确认。

---

## 页面：Availability

### 基本信息

- 页面 ID：GRM-14；类型：`GroomerAvailabilityEditorView`
- 文件：`Features/Groomer/Profile/GroomerAvailabilityEditorView.swift`
- 模块/类型/用户：Availability / Settings / Groomer。
- 目标：管理matching availability、weekly hours、booking preferences和time off。

### 页面展示的信息

active、7日hours、timezone、capacity、advance notice、auto-ready、time-off rows来自 Store；time off可空显示 empty/add入口。

### 操作入口

Available Toggle；weekday Toggles + start/end Menu；capacity/notice Menus；auto-ready Toggle；Save→`saveAvailability()`；Add Time Off→`startCreateTimeOff`；Delete row→`deleteTimeOff`。成功notice/更新且停留（time-off form除外），失败error。

### 表单字段

| 字段组 | 控件 | 类型/必填 | 默认 | 验证 | 保存目标 |
|---|---|---|---|---|---|
| Available for requests | Toggle | Bool | profile/false | none | profile active/matching |
| Weekly days | Toggle + time Menus | day states | default schedule | enabled day start<end | availability windows |
| Capacity | Menu | Int | 4/profile | allowed menu values | preferences |
| Advance notice | Menu | Int days | 0/profile | allowed values | preferences |
| Auto-ready | Toggle | Bool | false/profile | none | preferences |

### 页面状态

Initial populated；Loaded；Empty time off；Saving/Deleting/Disabled；Saved notice；Error/Validation Failed；Filtered=enabled days；Loading继承 Store；Searching/Offline/Permission无专用。

### 页面生命周期行为

共享 Store；无自有load。Home requested route可进入。离开不自动保存；time-off Sheet由本页挂载。

---

## 页面：Add Time Off

### 基本信息

- 页面 ID：GRM-15；类型：`GroomerTimeOffFormView`
- 文件：`Features/Groomer/Profile/GroomerAvailabilityEditorView.swift`
- 模块/类型/用户：Availability / Sheet / Groomer。
- 目标：创建time-off window。

### 页面展示的信息

title/start/end draft来自 Store；全可编辑。

### 操作入口

Cancel toolbar→`cancelTimeOffForm(); dismiss()`；Add Time Off→`createTimeOff()`，成功 flag false后dismiss，失败保持。按钮busy时disabled。

### 表单字段

| 字段 | 控件 | 类型 | 必填 | 默认 | 验证 | 错误 | 保存目标 |
|---|---|---|---|---|---|---|---|
| Reason/title | TextField | String | 是/Store contract | empty | trimmed | error | timeOff title |
| Start | DatePicker | Date | 是 | current | before end | error | startDate |
| End | DatePicker | Date | 是 | current+default | after start | error | endDate |

### 页面状态

Initial/Loaded；Saving/Disabled；Saved closes；Error/Validation Failed保持；其余Loading/Empty/Searching/Filtered/Deleting/Offline/Permission无专用。

### 页面生命周期行为

Store start method resets dates/title。Cancel/成功显式dismiss；无自动保存。

---

## 页面：Fit Signals

### 基本信息

- 页面 ID：GRM-16；类型：`GroomerFitSignalsEditorView`
- 文件：`Features/Groomer/Profile/GroomerFitSignalsEditorView.swift`
- 模块/类型/用户：Pet Fit / Settings / Groomer。
- 目标：选择core fit claims、size band range和skill groups。

### 页面展示的信息

taxonomy groups、selected counts/range来自 taxonomy + Store；选择可空显示未选择状态。

### 操作入口

claim chip/buttons→`toggleFitClaim`；dual range slider/custom gesture→`setSizeBandFitClaimRange`；Save→`saveFitClaims()`。busy时disabled；成功notice并停留，失败error。

### 表单字段

| 字段 | 控件 | 类型 | 必填 | 默认 | 验证 | 错误 | 保存目标 |
|---|---|---|---|---|---|---|---|
| Size range | custom dual Slider/DragGesture | ClosedRange<Int> | 依contract | normalized existing | lower≤upper/bounds | Store error | fit claims |
| Fit claims/skills | Button chips/toggles | Set<String> | 否 | existing/empty | taxonomy IDs | error | GroomerFitClaim set |

### 页面状态

Initial ensure normalized range；Loaded；Empty selections；Filtered=grouped taxonomy；Saving/Disabled；Saved notice；Error/Validation Failed；Searching/Deleting/Offline/Permission无专用。

### 页面生命周期行为

共享 Store；drag gestures仅本地 draft。离开不自动保存/无unsaved alert。

---

## 页面：Evidence

### 基本信息

- 页面 ID：GRM-17；类型：`GroomerEvidenceDashboardView`
- 文件：`Features/Groomer/Profile/GroomerFitSignalsEditorView.swift`
- 模块/类型/用户：Pet Fit Evidence / Settings / Groomer。
- 目标：只读查看后端汇总的fit evidence。

### 页面展示的信息

evidence overview/group counts/rows来自 `store.sortedPetFitEvidenceSummary()`；可空显示明确 empty state；不可编辑。

### 操作入口

仅系统 Back；未发现 Button、form、search或mutation。

### 表单字段

本页面未发现表单字段。

### 页面状态

Loaded/Empty；Loading/Error继承 Account Store；其余Disabled/Searching/Filtered/Saving/Saved/Deleting/Offline/Permission/Validation未独立实现。

### 页面生命周期行为

无自有task；显示 shared Store加载结果，离开无副作用。

---

## 页面：Portfolio

### 基本信息

- 页面 ID：GRM-18；类型：`GroomerPortfolioEditorView`
- 文件：`Features/Groomer/Profile/GroomerPortfolioEditorView.swift`
- 模块/类型/用户：Portfolio / Settings / Groomer。
- 目标：查看gallery、上传照片并进入detail。

### 页面展示的信息

sorted photos、image data/unavailable state、overview来自 Store；photos可空显示 empty；gallery只读，上传可变更。

### 操作入口

Add toolbar PhotosPicker→load data→`uploadPortfolioPhoto`；photo NavigationLink→GRM-19。Add disabled条件来自 presentation（busy/limit）。成功更新gallery/notice，失败error。

### 表单字段

Photos：PhotosPicker/Data/非必填/空；验证可读图片、数量/大小由 Store；保存到 Storage+portfolio metadata。

### 页面状态

Initial/Loaded/Empty；Loading image data；Saving(uploading)/Disabled；Saved=tile出现；Error；Deleting在detail；Filtered=sorted photos；Searching/Offline/Permission/Validation无专用（图片读取失败映射Error/unavailable）。

### 页面生命周期行为

共享 Store已load并缓存图片；PhotosPicker selection触发upload，结束后清selected item。离开不保存。

---

## 页面：Portfolio Photo Detail

### 基本信息

- 页面 ID：GRM-19；类型：`GroomerPortfolioPhotoDetailView`
- 文件：`Features/Groomer/Profile/GroomerPortfolioEditorView.swift`
- 模块/类型/用户：Portfolio / Detail / Groomer。
- 目标：查看照片、编辑fit tags/notes并删除。

### 页面展示的信息

full artwork、caption/summary、selected fit tags来自 photo + Store；image data可缺失显示 placeholder；tags可空。

### 操作入口

tag chips→`togglePortfolioFitTag`；Save→`savePortfolioFitTags`；Delete Button→Confirmation Dialog→`deletePortfolioPhoto`，确认照片移除后 `dismiss()`。成功save停留，delete返回gallery；失败error。

### 表单字段

| 字段 | 控件 | 类型 | 必填 | 默认 | 验证 | 错误 | 保存目标 |
|---|---|---|---|---|---|---|---|
| Fit tags/notes | Button chips（代码模型为 tags） | Set<String> | 否 | existing | taxonomy tag IDs | Store error | photo fit-tag relation |

### 页面状态

Loaded/Empty image placeholder；Saving/Disabled；Saved；Deleting + Confirmation；Error；Validation Failed未专用；Loading image继承 Store；Searching/Filtered/Offline/Permission无专用。

### 页面生命周期行为

无自有load；共享 Store。delete成功有显式dismiss；取消不变更。

---

## 跨页面控件与状态补充

### Customer/Groomer Tab Shell（正式结构但非单独页面 ID）

- `CustomerTabView`/`GroomerTabView`：`TabView(selection:)`、每 tab 一个 `NavigationStack`；`.task` 预载 notification/chat badge；`.onAppear` 注入 feedback/debug recorder；selection变化记录diagnostic event。
- Tab badges：Customer Home=notifications、Messages=unread conversations；Groomer Messages=unread conversations，Home接收 unread数字但 tab badge函数对Home返回0。
- cross-tab route bindings会在目标 Store加载后消费；找不到 conversation时清 route并显示error。

### 全局反馈与权限/网络状态

- 多数页面通过 `BeckonGlobalFeedbackForwarder`/`BeckonFeedbackCenter`显示 notice/error/progress，而非每页自建alert。
- 没有统一 `Offline` enum或offline banner；网络错误通常由 repository error mapper写入 `errorMessage`。
- 没有统一 `Permission Denied`页面；Auth/RLS/Storage错误同样进入error feedback。唯一系统权限相关可见入口是 PhotosPicker；代码未提供自定义photo permission页。
- 没有页面级search UI；地址“Searching/Filtered”来自 address search observable的suggestions，不是 `.searchable`。

## 本阶段停止点

本文完成38个正式页面的功能、控件、表单、状态和生命周期静态规格，不继续UI评价、重设计、代码修改或Figma原型。
