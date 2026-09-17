# 页面数据、状态与业务依赖图

## 盘点口径

本文覆盖 `01-screen-inventory.md` 的 38 个正式页面/surface，追踪 UI state 到 Store、Model、Repository、Service 和最终数据变化。生产依赖链为：

```text
SwiftUI View / Binding
→ @Observable Feature Store
→ Repository Protocol
→ Supabase implementation
→ Auth / Postgres RPC or Data API / Storage
```

未发现 SwiftData `@Query`、`@AppStorage`、`@EnvironmentObject` 或 production runtime fixture fallback。局部地址搜索仍使用 `@StateObject`/`ObservableObject`/`@Published`；其余 feature state 主要使用 Observation 的 `@Observable` + View `@State`/`@Bindable`。

## 状态与持久化机制总览

| 机制 | 位置/用途 | 是否业务事实源 | UI 重建约束 |
|---|---|---|---|
| `@State` | tab selection、focused IDs、route、sheet/alert flags、local draft | 否 | 必须保留跨 tab 跳转和临时 UI 生命周期 |
| `@Binding` | focused booking/request、requested profile route、Store form字段 | 否；但连接父子状态 | 不可改为无回写常量 |
| `@Observable` Store | Auth、entry、pets、requests、bookings、chat、notifications、profiles | UI协调层 | 必须继续作为 View 与 repository 边界 |
| `@StateObject` address search | Customer/Groomer address suggestion | 否 | 保留异步 suggestion/resolve 行为 |
| `@Environment` | scene phase、dismiss、Reduce Motion、debug/feedback center | 否 | 保留 dismiss、前台刷新、accessibility和反馈注入 |
| Supabase repositories | session/profile/domain records、RPC、Storage | 是 | View 不得直接调用 Supabase |
| `FileProfileSnapshotCache` | Customer/Groomer profile snapshot fast display | 否，cache | 不得把 cache 当 authoritative profile |
| `FilePrivateImageCache` / `FileCustomerPetPhotoCache` | authenticated image/pet photo bytes | 否，cache | sign-out/delete 时必须清理 |
| `UserDefaults` | request booking-handoff acknowledgement、push installation ID、operational diagnostics | 仅本地辅助状态 | 不得迁移为业务记录或角色事实 |
| `UNUserNotificationCenter` | push permission/device registration、appointment reminders | 系统副作用 | 保留用户授权和失败处理 |
| `AppointmentReminderScheduler` | booking/request成功后的 local reminder reconciliation | 系统副作用 | UI 重构不得遗漏 mutation后的调度调用 |
| Chat async stream | `ChatRepository.messageEvents` / subscription tasks | 服务端事件 | 不是完整 read-receipt/realtime产品；保留现有 subscription cleanup |

## 页面数据依赖表

| 页面 | 状态对象 | 数据模型 | 数据来源 | 写入目标 | 加载方法 | 更新方法 | 错误来源 |
|---|---|---|---|---|---|---|---|
| ROOT-01 App Root | immutable route + optional dependencies | `AppEntryRoute` | `AppComposition` | 无 | composition init | root conditional replacement | configuration construction |
| AUTH-01 Bootstrap | value state | `AuthenticationBootstrapState` | config loader result | 无 | `AppComposition.init` | 无 | `SupabaseConfiguration.load` |
| AUTH-02 Authentication | `@Bindable AuthenticationStore`; local `@State surface/passwordVisible` | `AuthSessionSnapshot`、`AuthenticationMode` | `AuthSessionRepository` | Supabase Auth session/account | Gate `start()`；user submit | `submit/signIn/signUp/handleAuthCallback` | validation/Auth repository |
| AUTH-03 Onboarding | `@Bindable AuthenticatedEntryStore` | `MarketplaceProfile`、`UserRole` | `ProfileRepository.profile` | profile row via `createProfile` | parent `load(userID:)` | `submit()` | form validation/Profile repository |
| AUTH-04 Profile Error | same Entry/Auth stores | entry failure message | Profile repository thrown error | retry only；sign-out affects Auth | `retry()` | retry/signOut | Profile/Auth repositories |
| CUS-01 Home | `@State` Pets/Requests/Bookings/Notifications stores | pets、requests、bookings、notifications | 4 repositories + caches | navigation state；mutations delegated to sheets | `loadHome()` | child stores load/refresh | any participating repository/image cache |
| CUS-02 Notifications | shared `CustomerNotificationsStore` | `CustomerNotification`、page request | CustomerNotificationRepository | notification read fields | `load/loadNextPage` | `markRead/markAllRead` | notification repository |
| CUS-03 Pet Form | `@Bindable CustomerPetsStore` + local PhotosPicker item | `CustomerPetDraft`、photo models | Store draft/existing pet | pet rows + Storage photo objects/metadata | `startCreate/startEdit` | save/update/delete photo | validation/Pet repository/Storage |
| CUS-04 Request Wizard | `@Bindable CustomerRequestsStore`; local photo/address states | request draft、pet、taxonomy、photos | Pet/Request/Profile repositories | request RPC/data + Storage photos | wizard start/onAppear | publish/upload/cancel draft | validation/Request/Profile/Storage |
| CUS-05 Requests | `@State CustomerRequestsStore`; Bindings focused/handoff | request/offer/booking handoff/page models | CustomerRequest + Booking repositories、UserDefaults ack | cancel/acknowledge/request create via wizard | `load/loadNextPage` | cancel/republish/ack handoff | repositories/reminder scheduler/defaults |
| CUS-06 Request Detail | shared Requests Store | request/offers/photos/booking | Store + Request repository | accept/republish/handoff | `.task(id: request.id)` related data | Store accept/republish callbacks | repository/RPC/image load |
| CUS-07 Offer Detail | shared Requests Store | offer + groomer fit evidence | loaded offer data | atomic accept through BookingRepository | parent/detail load | `acceptOffer` | validation/conflict/RPC |
| CUS-08 Bookings | `@State BookingsStore`; local scope; optional Requests Store | `Booking`、page request | BookingRepository | none directly；republish via Request Store | `load/loadNextPage` | scope local；wizard mutation | Booking/Request repositories |
| CUS-09 Booking Detail | shared Bookings Store + local review draft | `Booking`、review/fit outcomes | BookingRepository | booking status、review row | parent Store loaded | `cancel/createReview` | validation/Booking RPC/reminder scheduler |
| CUS-10 Messages | `@State/shared ChatStore`; `@Binding focusedBookingID` | conversations/page/unread | ChatRepository | local unread marker only | `loadConversations` | load page/open focused | Chat repository/missing conversation |
| CUS-11 Chat Thread | shared Chat Store + local message draft | messages/conversation | ChatRepository + async message events | message row | `loadMessages` | `sendMessage/loadNextMessagesPage` | validation/Chat repository/event stream |
| CUS-12 Account | `@State CustomerProfileStore`; `@Bindable AuthenticationStore` | customer profile/avatar/session | CustomerProfileRepository + snapshot/image cache | Auth sign-out/delete；profile via child | `store.load()` | Auth actions | Profile/Auth repositories/cache/image |
| CUS-13 Profile Settings | shared CustomerProfileStore; `@StateObject` address search | profile draft/avatar/address | profile repository + cache + address completer | profile row + avatar Storage path | parent load | `saveProfile/uploadAvatarPhoto` | validation/Profile repository/Storage/address resolve |
| CUS-14 Delete Account | local dialog `@State`; Auth Store | Auth account/session | Auth repository | delete Auth account + server cleanup；clear local caches | none | `deleteAccount` | Auth/server cleanup |
| GRM-01 Home | `@State GroomerHomeStore`; shared notification counts | profile snapshot、matches/offers、booking summaries | Profile/Request/Booking repositories + snapshot/image cache | no domain writes | `load()` | route callbacks/refresh | partial per-repository load issues |
| GRM-02 Notifications | shared GroomerNotificationsStore | `GroomerNotification`/route/page | GroomerNotificationRepository | read fields | `load/loadNextPage` | `markRead/markAllRead` | repository/route missing data |
| GRM-03 Requests | `@State` Requests + Offers stores; `@Binding GroomerRequestsRoute` | matches/offers/photos/page | GroomerRequestRepository | dismiss/withdraw/create offer through detail | stores `load` | segment/route/load page/mutations | repository/image load |
| GRM-04 Request/Create Offer | shared stores + local offer form `@State` | matched request + offer draft | GroomerRequestRepository | match dismissal or offer row/RPC | `.task(id:)` init/load photos | `dismiss/submitOffer/withdrawOffer` | validation/repository/RPC conflict |
| GRM-05 Offer Detail | shared GroomerOffersStore | offer/request/booking summary | GroomerRequestRepository | offer withdrawal | parent Store loaded | `withdraw`/refresh | repository |
| GRM-06 Schedule | shared Bookings Store + local selected day | bookings + schedule presentation | BookingRepository | none at root | `load/loadNextPage` | local filter | Booking repository |
| GRM-07 Booking Detail | shared Bookings Store | Booking | BookingRepository | cancel/complete booking status | parent loaded | `cancel/complete` | Booking repository/RPC/reminder scheduler |
| GRM-08 Messages | shared Chat Store + focused binding | conversations | ChatRepository | local unread marker | `loadConversations` | pagination/focused route | Chat repository |
| GRM-09 Chat Thread | shared Chat Store + draft | messages | ChatRepository/event stream | message row | `loadMessages` | `sendMessage/loadNextMessagesPage` | validation/repository/events |
| GRM-10 Account | `@State GroomerProfileStore`; route bindings | profile/services/portfolio/availability/fit/evidence | GroomerProfileRepository + caches | sign-out；child settings | `store.load()` | activate route/child mutations | any profile sub-read/Auth |
| GRM-11 Edit Profile | shared Profile Store; local PhotosPicker; `@StateObject` address search | GroomerProfile draft/avatar | repository + cache/address completer | profile row + avatar Storage | parent load/populate | `saveProfile/uploadAvatarPhoto` | validation/repository/Storage |
| GRM-12 Services | shared Profile Store | services | GroomerProfileRepository | service delete；form child writes create/update | parent `load` | start form/delete | repository |
| GRM-13 Service Form | shared Profile Store draft | `GroomerServiceDraft`/service | existing service/local defaults | service row | `startCreate/startEdit` | `saveService/cancelServiceForm` | validation/repository |
| GRM-14 Availability | shared Profile Store | availability windows/preferences/time off | GroomerProfileRepository | replace windows/preferences/delete time off | parent load/populate | `saveAvailability/deleteTimeOff` | validation/repository |
| GRM-15 Time Off Form | shared Profile Store draft + dismiss environment | time-off draft | local defaults | time-off row | `startCreateTimeOff` | `createTimeOff/cancelTimeOffForm` | validation/repository |
| GRM-16 Fit Signals | shared Profile Store + local drag indices | taxonomy/fit claims/range | GroomerProfileRepository + taxonomy | replace fit claims | parent load/populate | toggle/range/`saveFitClaims` | validation/repository |
| GRM-17 Evidence | shared Profile Store | pet-fit evidence summary | GroomerProfileRepository | 无 | parent `load` | 无 | profile repository load |
| GRM-18 Portfolio | shared Profile Store + PhotosPicker state | portfolio photos/data/tags | GroomerProfileRepository + PrivateImageLoader/cache | Storage photo + metadata | parent load/image reads | `uploadPortfolioPhoto` | image decode/Storage/repository |
| GRM-19 Photo Detail | shared Profile Store + delete dialog state + dismiss | photo/fit tags/image data | Profile Store | fit-tag relation；delete photo object/metadata | parent loaded | `savePortfolioFitTags/deletePortfolioPhoto` | repository/Storage |

## 操作到业务逻辑映射

“是否可逆”只描述当前代码提供的直接反向操作，不代表后台管理员可恢复。

| 页面 | 用户操作 | View Action | ViewModel 方法 | Service/Repository | 最终数据变化 | 是否可逆 |
|---|---|---|---|---|---|---|
| AUTH-02 | Sign In | Task submit | `AuthenticationStore.submit` | `AuthSessionRepository.signIn` | 建立 Auth session | 是：Sign Out |
| AUTH-02 | Sign Up | Task submit | `AuthenticationStore.submit` | `AuthSessionRepository.signUp` | 创建 Auth identity/session | 仅通过 Delete Account |
| AUTH-03 | Create Profile | Task submit | `AuthenticatedEntryStore.submit` | `ProfileRepository.createProfile` | 新建 role/profile | UI 未提供角色更改/删除 |
| AUTH-04 | Retry | Task | `AuthenticatedEntryStore.retry` | `ProfileRepository.profile` | 无写入；重读 | 是 |
| CUS-02 | Mark read/all | row/toolbar Task | Notification Store methods | CustomerNotificationRepository | `isRead/readAt` 更新 | UI 未提供 unread 恢复 |
| CUS-03 | Create pet | Save | Pet Store save | `createPet` + optional `uploadPhoto` | pet row + Storage metadata/object | pet soft delete可能可逆但UI恢复未发现 |
| CUS-03 | Edit pet | Save | Pet Store save | `updatePet` | pet fields替换 | 可再次编辑，不是历史回滚 |
| CUS-03 | Delete photo | tile action | Pet Store delete | `deletePhoto` | photo metadata/object删除 | 否 |
| CUS-04 | Publish request | final action | Requests Store publish | `CustomerRequestRepository.createRequest` + uploads | request row/photos；后端matching副作用 | 只能取消；不等于撤销发布 |
| CUS-05 | Cancel request | Alert confirm | Requests Store cancel | `cancelRequest` | request status cancelled | 否；可republish为新request |
| CUS-05 | Acknowledge handoff | open handoff | Store ack | repository ack + `UserDefaults` fallback/marker | handoff提示已确认 | UI未提供恢复 |
| CUS-07 | Accept offer | Button Task | Requests Store accept | `BookingRepository.acceptOffer` RPC | offer/request状态 + booking + conversation | 否；booking可取消但不重开request |
| CUS-09 | Cancel booking | action Task | `BookingsStore.cancel` | `cancelBooking` | booking status cancelled | 否 |
| CUS-09 | Submit review | form Task | `BookingsStore.createReview` | `createReview` RPC | review row/fit outcomes | UI未提供编辑/删除 |
| CUS-11 | Send message | composer Task | `ChatStore.sendMessage` | `ChatRepository.sendMessage` | message row | 否 |
| CUS-13 | Save profile | Button Task | `CustomerProfileStore.saveProfile` | `updateProfile` | profile fields | 可再次编辑 |
| CUS-13 | Upload avatar | PhotosPicker Task | `uploadAvatarPhoto` | ProfileRepository/Storage | object + profile path | 可替换；删除入口未发现 |
| CUS-14 | Delete Account | final Alert | `AuthenticationStore.deleteAccount` | Auth repository/server cleanup | account/profile data cleanup + session/cache clear | 否 |
| GRM-02 | Mark read/all | row/toolbar Task | Notification Store methods | GroomerNotificationRepository | read state | UI未提供恢复 |
| GRM-04 | Dismiss match | Button Task | `GroomerRequestsStore.dismiss` | `GroomerRequestRepository.dismiss` | groomer-private match dismissal | UI未提供恢复 |
| GRM-04 | Create offer | Button Task | `submitOffer` | `GroomerRequestRepository.createOffer` | offer row/status | 可在eligible状态withdraw |
| GRM-04/05 | Withdraw offer | Button Task | request/offer Store withdraw | `withdrawOffer` | offer status withdrawn | 否 |
| GRM-07 | Cancel booking | Button Task | `BookingsStore.cancel` | `cancelBooking` | booking cancelled | 否 |
| GRM-07 | Complete booking | Button Task | `BookingsStore.complete` | `completeBooking` RPC | booking completed | 否 |
| GRM-09 | Send message | composer Task | `ChatStore.sendMessage` | ChatRepository | message row | 否 |
| GRM-11 | Save profile | Button Task | `GroomerProfileStore.saveProfile` | `updateProfile` | profile fields/active/modes | 可再次编辑 |
| GRM-11 | Upload avatar | PhotosPicker Task | `uploadAvatarPhoto` | repository/Storage | avatar object/path | 可替换 |
| GRM-12 | Delete service | row Menu Task | `deleteService` | GroomerProfileRepository | service deleted | 否 |
| GRM-13 | Create/update service | Sheet Save | `saveService` | `createService/updateService` | service row | update可再次编辑；create可删除 |
| GRM-14 | Save availability | Button Task | `saveAvailability` | `replaceAvailability` + `updateBookingPreferences` | windows/preferences替换 | 可再次编辑，非历史回滚 |
| GRM-14 | Delete time off | row Task | `deleteTimeOff` | ProfileRepository | time-off row删除 | 否 |
| GRM-15 | Add time off | Sheet Save | `createTimeOff` | ProfileRepository | time-off row | 可删除 |
| GRM-16 | Save fit signals | Button Task | `saveFitClaims` | `replaceFitClaims` | fit-claim set替换 | 可再次编辑 |
| GRM-18 | Upload photo | PhotosPicker Task | `uploadPortfolioPhoto` | repository/Storage | photo object/metadata | 可删除 |
| GRM-19 | Save photo tags | Button Task | `savePortfolioFitTags` | `replacePortfolioFitTags` | photo-tag relations替换 | 可再次编辑 |
| GRM-19 | Delete photo | dialog confirm | `deletePortfolioPhoto` | repository/Storage | photo object/metadata删除 | 否 |
| Account pages | Sign Out | Button Task | `AuthenticationStore.signOut` | AuthSessionRepository | session清除 + protected caches clear | 可重新登录 |

## 状态转换

只有 `AuthenticationRootState`、`AuthenticatedEntryState` 等明确 enum 会称为状态机。其余均标记“根据条件逻辑整理”。

### Auth root（明确 enum）

```text
loading
→ signedOut
→ signedIn(session)

signedIn
→ signedOut          (signOut / session event / deleteAccount)

submit
→ isSubmitting=true
→ signedIn | errorMessage
```

证据：`AuthenticationRootState`、`AuthenticationStore.start/submit/signOut/deleteAccount`、session async stream。

### Authenticated profile entry（明确 enum）

```text
loading
→ onboarding         (profile == nil)
→ customer(profile)
→ groomer(profile)
→ failure(message)

failure
→ loading            (retry)

onboarding
→ isSubmitting
→ customer | groomer | onboarding+error
```

证据：`AuthenticatedEntryState`、`AuthenticatedEntryStore.load/retry/submit`。

### 通用分页 Store（根据条件逻辑整理）

适用：Requests、Bookings、Chat conversations/messages、Customer/Groomer Notifications。

```text
items=[] + isLoading=false
→ isLoading=true
→ items=firstPage + nextPageRequest? + isLoading=false
                 ↘ errorMessage + isLoading=false

canLoadMore
→ isLoadingMore=true
→ deduplicated append + nextPageRequest? + false
                 ↘ preserve existing items + errorMessage + false
```

必须保留：limit+1/page token语义、去重、失败时保留已有内容、message prepend时reader anchor。

### Customer pet form（根据条件逻辑整理）

```text
closed
→ startCreate | startEdit
→ editing + isShowingPetForm=true
→ validating
→ isSaving / isUploading
→ repository success + refreshed pets/photos + form=false
→ validation/repository error + form remains open
```

删除照片是独立 async分支；pending local photos不可当作已保存成功。

### Request wizard / publication（根据条件逻辑整理）

```text
closed
→ new/republish draft + isShowingWizard=true
→ step editing
→ step validation
→ final publishing
→ createRequest success
→ optional photo uploads + authoritative refresh + wizard=false

validation/repository/upload failure
→ errorMessage + recoverable draft remains
```

跨记录 publication/matching必须继续经过 repository/backend contract，禁止UI乐观伪造成功。

### Offer acceptance（根据条件逻辑整理）

```text
offer eligible
→ isAccepting=true
→ BookingRepository.acceptOffer
→ request/offers/bookings refresh
→ accepted booking/conversation visible

RPC conflict/permission/failure
→ isAccepting=false + errorMessage
→ original authoritative state retained/refreshed
```

### Bookings mutation/review（根据条件逻辑整理）

```text
loaded booking
→ isCancelling | isCompleting | isSubmittingReview
→ repository/RPC
→ replace booking / attach review + notice
→ reminder reconciliation where invoked

failure
→ clear busy flag + errorMessage + preserve current record
```

### Chat thread（根据条件逻辑整理）

```text
conversation selected
→ loadingConversationIDs contains id
→ newest message window loaded + local unread cleared
→ optional event subscription

load older
→ loadingEarlier... contains id
→ prepend messages while preserving anchor

draft valid + writable
→ sendingConversationIDs contains id
→ sendMessage
→ message list refresh/append + draft clear
→ error keeps/recovers input according to View callback
```

### Groomer aggregate profile load（根据条件逻辑整理）

```text
profile/services/portfolio/availability/preferences/timeOff/fit/evidence empty
→ isLoading=true
→ parallel/sequential repository reads
→ populate models + form snapshots + image cache requests
→ isLoading=false

partial/total failure
→ errorMessage; cached profile snapshot may still support limited presentation
```

Cache不是权威事实，成功网络结果必须覆盖/refresh cache。

### Groomer service/time-off Sheets（根据条件逻辑整理）

```text
closed
→ startCreate/startEdit + populate draft + flag=true
→ editing
→ validating
→ isSaving=true
→ repository success + list update + reset draft + flag=false
→ failure + errorMessage + flag remains true

cancel
→ reset draft + flag=false
```

### Profile / Availability / Fit / Photo tags（根据条件逻辑整理）

```text
loaded server snapshot
→ bindings edit local Store fields
→ validating
→ isSaving=true
→ repository replace/update
→ model/snapshot/notice update; remain on page

failure
→ isSaving=false + errorMessage; user remains on page
```

这些页面没有自动保存和unsaved-change confirmation；UI重建不得悄然改变成自动持久化。

## UI 重建时必须保留的业务边界

### 不能因重做 UI 而改变的方法/调用链

- Auth：`AuthenticationStore.start/submit/handleAuthCallback/signOut/deleteAccount`。
- Entry：`AuthenticatedEntryStore.load/retry/submit`；角色必须来自 `MarketplaceProfile.role`。
- Requests：`CustomerRequestsStore` publication/cancel/republish/accept-handoff链；`GroomerRequestsStore.dismiss/submitOffer/withdrawOffer`。
- Booking：`BookingsStore.cancel/complete/createReview` 与 `BookingRepository.acceptOffer`。
- Chat：`loadConversations/loadMessages/loadNext*/sendMessage` 以及 focused booking resolution。
- Profile：Customer/Groomer Store save/upload方法；Groomer service/availability/fit/portfolio/time-off mutations。
- 所有 View 必须继续依赖 repository protocols，不得直接创建 Supabase query/RPC/Storage调用。

### 必须保留的 Bindings 与导航结果

- `CustomerTabView.selection`、`focusedRequestID`、`focusedConversationBookingID`。
- `GroomerTabView.selection`、`requestsRoute`、`focusedConversationBookingID`、`requestedProfileRoute`。
- `ChatConversationsView.focusedBookingID` 消费并清空的行为。
- `GroomerProfileManagementView.requestedRoute → activeRoute` 必须等待 profile loaded。
- `isShowingPetForm/isShowingWizard/isShowingServiceForm/isShowingTimeOffForm` 成功/cancel/失败时的现有关闭语义。
- portfolio photo删除成功后的 `dismiss()`；profile/availability/fit保存后停留页面。

### 必须保留的权限与角色判断

- Root/Auth/profile gate：配置失败、signed-out、profile missing、Customer/Groomer互斥。
- booking动作必须由 role + booking status presentation决定；Customer不可Complete，Groomer不可提交Customer review。
- request/offer mutation必须依赖后端ownership/status验证，不因隐藏按钮而替代授权。
- conversation/message只对booking participant；read-only conversation必须禁用composer。
- private image始终通过authenticated `PrivateImageLoader`/repository，不可改公开 URL直读。
- DEBUG quick login/Debug Console不得进入release production路径。

### 必须保留的验证规则

- Auth email/password/confirmation；onboarding display name/role。
- Pet name/taxonomy/weight/date/photo constraints。
- Request pet/service/time order/location/address/photo limits与republish eligibility。
- Offer start/end/price/message和duplicate-submit protection。
- Review eligibility/rating/content/fit outcome contract。
- Customer/Groomer profile address、email/phone及draft normalization。
- Service title/type/price/duration/accepted size range；availability enabled-day时间范围；time-off start/end。
- Fit range bounds/taxonomy IDs；portfolio image decode/limit和fit-tag IDs。

### 必须保留的异步加载与错误处理

- `AuthenticationGateView.task` session restore与async session events。
- `AuthenticatedEntryView.task(id: session.userID)` profile load；Customer push registration task只在Customer ID active时运行。
- role shells预载notification/chat badge；foreground refresh gate避免无界重复加载。
- 分页失败保留现有rows，retry/load-more不得重复records。
- private image/cache读取失败显示placeholder/error，不得伪造image成功。
- mutation busy flags和guard必须保留，防止重复submit。
- errorMessage/notice/progress继续通过feedback center/status forwarders呈现。

### Persistence与系统副作用边界

- sign-out/delete account必须清 `FileProfileSnapshotCache`、`FilePrivateImageCache`、Customer pet photo cache。
- request booking-handoff acknowledgement的repository/UserDefaults兼容行为不得丢失。
- push installation ID保存在UserDefaults；device token register/unregister必须保持role/session约束。
- `AppointmentReminderScheduler`相关成功mutation后副作用不得因换View遗漏。
- 不得把preview/test fixtures或cache当production fallback。

## 有测试覆盖的关键行为

| 领域 | 主要测试文件 | UI重构必须保持 |
|---|---|---|
| Entry/Auth | `AppEntryModelsTests.swift`、Auth相关测试 | root/profile/role状态分支 |
| Pets | `CustomerPetFeatureTests.swift` | form validation、photos、mutation状态 |
| Requests/Offers | `CustomerRequestFeatureTests*.swift` | wizard、offers、republish、bookings handoff |
| Bookings/Reviews | `BookingFeatureTests.swift` | role actions、cancel/complete/review、schedule presentation |
| Chat | `ChatFeatureTests.swift` | pagination、newest window、send、reader anchor/read-only |
| Notifications | Customer/Groomer notification tests | unread、mark read/all、pagination/routes |
| Customer Profile | `CustomerProfileFeatureTests.swift` | profile/avatar save/error |
| Groomer Home | `GroomerHomeFeatureTests.swift` | partial load summaries/routes |
| Groomer Requests/Offers | request/offer feature tests | segment/routes/dismiss/submit/withdraw |
| Groomer Profile | `GroomerProfileFeatureTests*.swift` | profile/services/availability/fit/portfolio |
| Tabs | `TabBadgeFeatureTests.swift` | badge count/role tab behavior |
| Private images/cache | `PrivateImageLoaderTests.swift` | authenticated loading/cache/retry/clear |
| Foreground refresh | `ForegroundRefreshGateTests.swift` | first/active refresh gating |
| Accessibility/selectors | `DesignTokenAccessibilityTests.swift`、TestOps UI flows | identifiers和关键导航入口 |

## 高风险页面

| 页面 | 风险等级 | 为什么容易破坏 | 重构保护措施 |
|---|---|---|---|
| ROOT-01/AUTH-02/03/04 | 极高 | async session、profile缺失≠error、角色权威路由、callback | 保持两个明确state层和repository boundaries |
| CUS-01 Home | 高 | 4个Store聚合、多个Sheet、cross-tab route、badge/foreground refresh | 不把Store合并为静态view data；验证每个callback |
| CUS-04 Wizard | 极高 | 多步draft、validation、profile/address、photos、republish、RPC | 视觉拆分不能重置Store draft或跳过publish路径 |
| CUS-05/06/07 | 极高 | request/offer/booking关联、atomic accept、handoff ack、分页 | 保留IDs/Bindings/RPC后refresh，不乐观伪造booking |
| CUS-09/GRM-07 Booking Detail | 极高 | 同View双角色、不同action、review/reminder | 继续用role/status presentation，不仅靠按钮文案 |
| CUS-10/11、GRM-08/09 Chat | 极高 | focused route、pagination方向、anchor、async events、read-only | 保留shared Store、conversation ID和task lifecycle |
| CUS-13/GRM-11 Profile | 高 | address async search、avatar Storage、cache、unsaved draft | 保存仍显式；cache仅fast path；upload经repository |
| GRM-03/04/05 | 极高 | 双Store segment、notification deep route、offer状态机 | 保留route IDs与duplicate guards；mutation后refresh |
| GRM-10 Account | 高 | 一次load多个子域、service Sheet挂在父级、Home availability route | 不拆断共享Profile Store或requested route activation |
| GRM-13/14/15 | 高 | shared draft flags、replace semantics、cancel reset、Sheet dismiss | 保留flag/reset顺序与validation；失败不关Sheet |
| GRM-16/17 | 中高 | taxonomy range normalization、evidence只读来源 | 保留ID集合/范围归一化，不把evidence变可编辑假数据 |
| GRM-18/19 | 高 | authenticated image bytes、Storage metadata、delete后dismiss | upload/delete仍经repository；只有确认删除后pop |

## 已确认的不使用项与不确定项

- 未发现 `@Query`、`@AppStorage`、`@ObservedObject`、`@EnvironmentObject` 在正式feature页面；地址搜索使用 `@StateObject`。
- 未发现页面把UserDefaults当profile/request/booking事实源；其使用限于handoff ack、push installation与diagnostics。
- ChatRepository存在`messageEvents`且Store创建subscription tasks；产品文档曾称realtime out of scope，当前具体事件订阅覆盖范围需后续运行/协议审计确认，不能在UI重建时扩大为read receipt/typing功能。
- Customer push registration task存在，但APNs dispatcher仍受外部凭证阻塞；UI不得宣称远端push已完整可用。
- Groomer booking notification携带的booking ID未用于直接打开detail；保持现状或另立产品/导航任务，不在UI重构中“顺便修复”。
- Groomer普通production删除账户入口未确认；不要凭generic account content新增入口。

## 本阶段停止点

本文完成页面数据、状态、业务写入、持久化边界和高风险映射，不继续UI重构、功能修复、backend验证或Figma设计。
