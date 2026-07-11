# 现有 UI 组件与视觉规则盘点

## 盘点口径

本文只记录当前 SwiftUI 实现，不合并、不重构、不评价具体视觉质量。“仍在使用”以 production Feature 调用为准；仅被 DesignSystem 内部调用或当前零 Feature 调用的类型会明确标记。

## 组件总表

### 跨模块 DesignSystem

| 组件 | 类型 | 文件路径 | 使用页面 | 接收参数 | 支持状态 | 是否仍在使用 | 复用价值 |
|---|---|---|---|---|---|---|---|
| `BeckonPrimaryButtonStyle` | ButtonStyle | `DesignSystem/BeckonActionPrimitives.swift` | Auth、onboarding、pet/request、booking、profile等约14个Feature文件 | accent customer/groomer、full width | enabled/disabled/pressed | 是 | 高：主行动语义 |
| `BeckonSecondaryButtonStyle` | ButtonStyle | 同上 | 列表、表单、错误恢复等约16个文件 | customer/groomer/neutral、full width | enabled/disabled/pressed | 是 | 高：次级行动 |
| `BeckonLoadMoreButton` | View | 同上 | Requests、Bookings、Chat、Notifications等8个文件 | loading、accent、title、symbol、async action、a11y ID | idle/loading/disabled | 是 | 高：分页终点 |
| `BeckonCard` | generic View | 同上 | Account、Profile、Requests、Bookings等14个文件 | selected、padding、content | normal/selected | 是 | 高：通用surface容器 |
| `BeckonStatusChip` | View | 同上 | role、booking、request、offer等10个文件 | title、optional SF Symbol、tone | neutral/customer/groomer/success/warning/error | 是 | 高：状态语义 |
| `beckonShadow` | View extension + private ViewModifier | 同上 | Buttons/cards与局部surface | `ShadowStyle`、visible | visible/hidden | 是 | 中高：统一elevation |
| `beckonFormField` | View extension + private ViewModifier | `DesignSystem/BeckonFormPrimitives.swift` | Auth/Profile/Forms | 无公开参数 | default/focus由系统；disabled继承 | 是 | 高：基础输入容器 |
| `BeckonErrorBanner` | generic View | `DesignSystem/BeckonFeedbackPrimitives.swift` | Auth、Entry、feature errors约15个文件 | title、message、symbol、optional action | error/with action/without action | 是 | 高：页面级错误 |
| `BeckonPersistentErrorView` | generic View | 同上 | 全局反馈内部/少量页面 | persistent error、symbol、optional action | persistent/action/no action | 是（Feature直接1处） | 中：持久错误 |
| `BeckonBottomPrompt` | generic View | 同上 | feedback系统内部 | tone/content | active/queued/hidden | 间接使用；Feature直接0 | 中：底部提示布局 |
| `BeckonBottomPromptStack` | generic View | 同上 | feedback内部 | prompt collection | stacked/empty | 间接使用 | 中 |
| `BeckonBottomPromptArea` | generic View | 同上 | feedback overlay | content | safe-area/keyboard布局 | 间接使用 | 中 |
| `BeckonFeedbackCenter` | `@Observable` state coordinator | 同上 | Customer/Groomer Tab shell、global overlay | notices/errors/progress/debug recorder | active/queued/persistent/cleared | 是 | 高：跨页面反馈状态 |
| `BeckonNoticeForwarder` | View | 同上 | feature status views | message、clear closure、scope | notice/none | 是 | 高：Store→feedback桥接 |
| `BeckonGlobalFeedbackForwarder` | View | 同上 | Requests/Profile/Bookings/Chat状态视图 | notice/error/progress | combinations/none | 是 | 高 |
| `BeckonGlobalFeedbackOverlay` | View | 同上 | Customer/Groomer shells及Preview约3个Feature文件 | feedback center环境 | error/progress/notice/queue | 是 | 高 |
| `BeckonNoticeToast` | View | 同上 | feedback内部 | notice/tone | shown/hidden | 间接使用；Feature直接0 | 中 |
| `BeckonBottomErrorPrompt` | View | 同上 | feedback内部 | error/action | action/no action | 间接使用 | 中 |
| `BeckonStatusProgressToast` | View | 同上 | feedback内部 | progress/tone | active | 间接使用 | 中 |
| `BeckonLoadingView` | View | 同上 | Auth、Pets、Requests、Bookings、Chat、Profile等13个文件 | title、message、accent | customer/groomer/neutral loading | 是 | 高 |
| `BeckonEmptyState` | generic View | 同上 | lists/workspaces约8个文件 | title、message、symbol、accent、optional action | with/without action | 是 | 高 |
| `BeckonSectionHeader` | generic View | 同上 | Settings/Forms约7个文件 | title、subtitle、trailing content | subtitle/no subtitle、trailing/none | 是 | 高 |
| `BeckonModuleImage` | generic View | `DesignSystem/BeckonModuleImage.swift` | Pets/Profile/Booking/Request/Chat等8个文件 | image data、content mode/layout、placeholder | loaded/placeholder | 是 | 高：业务图片容器 |
| `BeckonDefaultProfileAvatar` | View | 同上 | Auth/Customer/Groomer约3个文件 | customer/groomer tone、symbol size | 两角色placeholder | 是 | 高 |
| `BeckonModuleImageLayout` | enum | 同上 | `BeckonModuleImage`调用点 | fill/fit等layout | layout variants | 是 | 中 |
| `FeaturePlaceholderView` | View | `DesignSystem/FeaturePlaceholderView.swift` | role tab依赖缺失fallback（2个tab文件） | title/message/symbol/accent | customer/groomer placeholder | 是但正常production依赖完整时不出现 | 低：fallback，不是业务组件 |
| `foregroundRefreshable` / `ForegroundRefreshModifier` | View extension + private ViewModifier | `Core/Infrastructure/ForegroundRefreshGate.swift` | Home、Requests、Bookings、Chat等前台刷新页面 | async action | initial load、active refresh、deduplicated in-flight | 是（7个调用点） | 高：生命周期行为组件 |

### Feature 内具有复用价值的组件

| 组件 | 类型 | 文件路径 | 使用页面 | 接收参数 | 支持状态 | 是否仍在使用 | 复用价值 |
|---|---|---|---|---|---|---|---|
| `GroomerWorkspaceSection` | generic View | `Features/Groomer/GroomerWorkspacePrimitives.swift` | Groomer Home/Requests/Account/Profile settings | title/content | content/empty由子级 | 是 | 高：Groomer section语义 |
| `GroomerGroupedSurface` | generic View | 同上 | Groomer Account/Settings/Lists | content | normal | 是 | 高：grouped settings surface |
| `GroomerWorkspaceDivider` | View | 同上 | Groomer grouped rows | leading inset | inset variants | 是 | 中高 |
| `AccountTabTitle` | View | `Features/Auth/AuthenticatedAccountView.swift` | Customer/generic Account | title | static | 是 | 中：页面标题 |
| `AccountReleaseLinksSection` | View | 同上 | Customer/generic Account | constants | URL available | 是 | 高：legal/support语义 |
| `AccountDangerActions` | View | 同上 | Customer/generic Account | AuthenticationStore | idle/confirming/deleting/error | 是 | 高：账号危险操作 |
| `CustomerAccountMenuLink` | generic NavigationLink wrapper | `Features/Customer/Profile/CustomerProfileSettingsView.swift` | Customer Account | title、symbol、destination | normal | 是 | 中高 |
| `GroomerAccountMenuLink` | generic NavigationLink wrapper | `Features/Groomer/Profile/GroomerProfileAccountView.swift` | Groomer Account | title、summary、symbol、ID、destination | normal | 是 | 高 |
| `GroomerAccountExternalLink` | View | 同上 | Groomer Account | title、symbol、URL、ID | enabled by URL | 是 | 中 |
| `CustomerAvatarImage` | View | Customer Profile file | Customer Account/Profile | data、size、placeholder size | image/placeholder | 是 | 中高 |
| `GroomerAvatarImage` | View | Groomer Profile Account file | Groomer Home/Account/Profile | data、size、corner radius、placeholder size | image/placeholder | 是 | 中高 |
| `BookingAvatar` | View | `Features/Bookings/BookingsView.swift` | Customer Bookings | booking image/model | image/placeholder | 是 | 中 |
| `ChatConversationAvatar` | View | `Features/Chat/ChatView.swift` | Messages | conversation/role image | image/placeholder/unread companion | 是 | 中 |
| `CustomerRequestWizardPetAvatar` | View | Request Wizard | Wizard pet selection | image data/name/size | image/emoji/placeholder | 是 | 低中：wizard-specific |
| `BookingSummaryRow` | View | Bookings file | Customer Bookings | booking/role/store callbacks | role/status/image | 是 | 高：appointment list row |
| `GroomerScheduleAppointmentRow` | View | Bookings file | Groomer Schedule | booking/store/chat | upcoming/status | 是 | 高 |
| `BookingDetailHeroCard` | View | Bookings file | both Booking Details | booking/role | Customer/Groomer/status | 是 | 高 |
| `BookingDetailInfoCard` | generic View | Bookings file | Booking Detail | title/content | flexible content | 是 | 中高 |
| `BookingDetailActionBar` | View | Bookings file | Booking Detail | presentation/actions | cancel/complete/chat/disabled/busy | 是 | 高 |
| `BookingReviewForm` | View | Bookings file | Customer Booking Detail | bindings/submit | editable/submitting/validation | 是 | 高 |
| `CustomerRequestProgressCarousel` | View | Requests Dashboard | Customer Requests | requests/store/actions | empty/content/selection | 是 | 高 |
| `CustomerRequestActionCardSummary` | View | Requests Dashboard | Customer Requests | request/handoff/actions | request status variants | 是 | 高 |
| `CustomerRequestTimelineRow` | View | Requests Dashboard | Customer Requests | request/presentation/actions | multiple statuses | 是 | 高 |
| `CustomerRequestBriefHeader` | View | Requests Dashboard | Customer Request cards/details | pet/request data | photo/placeholder/status | 是 | 中高 |
| `CustomerOfferSummaryRow` | View | Request Detail | Customer Offer list | offer/evidence | eligible/accepted/etc. | 是 | 高 |
| `GroomerRequestSummaryRow` | View | Groomer Requests | Matches | matched request/photo | loading image/status | 是 | 高 |
| `GroomerOfferRow` | View | Groomer Offers file | Offers segment | offer item | status/booking | 是 | 高 |
| `CustomerNotificationRow` | View | Customer Notifications | notification list | notification/mark action | read/unread/marking | 是 | 高 |
| `GroomerNotificationRow` | View | Groomer Notifications | notification list | notification/action | read/unread/marking/route | 是 | 高 |
| `ChatConversationRow` | View | Chat file | Messages | conversation/role | unread/read/image | 是 | 高 |
| `ChatMessageRow` | View | Chat file | Thread | message/participant | sent/received | 是 | 高 |
| `ChatComposerView` | View | Chat file | Thread | draft、sending、writable、send | enabled/disabled/sending/read-only | 是 | 高 |
| `CustomerProfileTextField` | View | Customer Profile file | Profile Settings | title、binding、prompt | normal/disabled inherited | 是 | 中 |
| `GroomerProfileTextField` | View | Groomer Profile Form file | Profile/Service/Time Off forms | title、binding、prompt | normal/disabled inherited | 是 | 高 |
| `CustomerPetFormLabeledTextField` | View | Customer Pets file | Pet Form | title、binding、placeholder | normal | 是 | 中 |
| `CustomerRequestWizardPrimaryButtonStyle` | ButtonStyle | Request Wizard file | Request Wizard固定底栏 | visually enabled | enabled/disabled/pressed | 是 | 中：wizard专属主行动 |
| `DetailMetadataRow` / `BookingDetailFactRow` / `GroomerOfferFactRow` | View family | Request/Booking/Offer files | multiple details | label/value/icon variants | optional values | 是 | 高语义、低代码统一度 |
| `CustomerHomeStatusView` / `CustomerPetsStatusView` / `CustomerProfileStatusView` / `CustomerRequestsStatusView` / `BookingsStatusView` / `ChatStatusView` / `GroomerRequestsStatusView` / `GroomerOffersStatusView` / `GroomerProfileStatusView` | feedback bridge Views | respective Feature files | feature roots/details | Store | error/notice/progress | 是 | 高业务桥接；视觉由DesignSystem |

## 重复实现

以下只记录相似性，不建议在本阶段合并。

| 重复族 | 现有实现 | 相同点 | 差异/不能直接合并的原因 |
|---|---|---|---|
| Appointment cards/rows | `BookingSummaryRow`、`GroomerScheduleAppointmentRow`、`GroomerHomeNextBookingCard`、request booking handoff card、`ChatBookingContextCard` | 时间、状态、参与者、图片、进入detail/chat | Customer list、Groomer timeline、Home summary、Chat context职责不同 |
| 状态 badge/pill | `BeckonStatusChip`、`ChatBookingStatusPill`、request timeline/status pills、offer badges、unread dots | 短文本+tone+shape | 有些是状态语义，有些是notification unread或role标签；颜色映射分散 |
| 头像/缩略图 | `BeckonDefaultProfileAvatar`、`CustomerAvatarImage`、`GroomerAvatarImage`、`BookingAvatar`、`ChatConversationAvatar`、request/pet thumbnails | image/placeholder、裁切、边框 | shape、size、角色tone、数据模型和认证图片来源不同 |
| Primary actions | `BeckonPrimaryButtonStyle`为主；Wizard自有底部按钮style/press animation；若干plain Button手工背景 | 满宽、强调色、disabled/loading | Wizard的step语义和固定底栏；危险操作不能使用主行动视觉 |
| Empty states | `BeckonEmptyState`、`CustomerRequestsEmptyDashboard`、`GroomerScheduleEmptyDayView`、`GroomerPortfolioEmptyState`、`GroomerServicesEmptyState`、Home unavailable surfaces | symbol、title、message、optional action | dashboard/日程/图库需要领域布局和上下文，不全是通用空页 |
| Error states | `BeckonErrorBanner`、`BeckonPersistentErrorView`、各Feature `*StatusView`、Home unavailable/load issue surfaces | title/message/action/重试 | transient global、persistent page和partial aggregate error语义不同 |
| Loading states | `BeckonLoadingView`、button内 `ProgressView`、list load-more、image placeholders、Home loading surface | progress反馈 | page、operation、pagination、image四种不同scope |
| Form rows | `CustomerProfileTextField`、`GroomerProfileTextField`、`CustomerPetFormLabeledTextField`、Wizard address fields、offer fields | label+input+validation | keyboard/content type、address suggestions、multiline、数值转换不同 |
| Section headers | `BeckonSectionHeader`、`GroomerWorkspaceSection` title、`AccountTabTitle`、Customer/Groomer custom page headers | title/subtitle/trailing | 页面title、内容section和workspace group层级不同 |
| Grouped settings rows | Customer Account menu、Groomer Account menu、Availability rows、Service rows、release links | icon+title+summary+chevron/action | NavigationLink、Menu、Toggle、External Link交互不同 |
| Photo tiles | pet photo tile、request photo tile、portfolio tile、detail artwork | authenticated/local image+placeholder/delete | pending vs persisted、可删除权限、fit-tag detail不同 |
| Toolbar patterns | native cancellation ToolbarItem、top add button、mark-all-read、hidden custom headers | leading cancel/back、trailing action | Push与Sheet返回语义不同；部分页面隐藏navigation bar使用自定义header |
| Segmented filters | Customer booking scope、Groomer Matches/Offers、pet/service choice chips、wizard steps | selected/unselected Button集合 | list filter、business segment、single/multi selection语义不同 |

## 当前设计 Token

来源：`DesignSystem/DesignTokens.swift`。

### 颜色：统一 Token

| Token | Hex/别名 | 语义 |
|---|---|---|
| `appBackground` / `background` | `#FAF7F2` | App页面背景 |
| `surface` / `surfaceRaised` | `#FFFFFF` | 卡片、输入、raised surface |
| `border` | `#E8E2D8` | 标准边框 |
| `borderSoft` / `divider` | `#EFEAE1` | 弱边框/分隔线 |
| `textPrimary` / `primaryText` | `#232323` | 主文本/主按钮前景 |
| `textSecondary` / `secondaryText` | `#6F767E` | 次文本 |
| `textTertiary` | `#69717A` | tertiary/disabled辅助文本 |
| `customerPrimary` | `#7ECFC0` | Customer accent |
| `customerPrimaryDark` / pressed | `#5FBFAE` | Customer强调/pressed |
| `groomerAccent` | `#FF9A8B` | Groomer accent |
| `groomerAccentDark` / pressed | `#F58575` | Groomer强调/pressed |
| `success` | `#6CBF84` | 成功状态 |
| `warning` | `#F2B84B` | 警告状态 |
| `error` | `#E56B6F` | 错误/危险状态 |

说明：项目也大量使用 token `.opacity(...)` 派生背景/边框；这些不是独立Color token。系统颜色如 `.clear`、Material、默认 `ProgressView` tint在局部出现。

### 字体：统一 Token 与系统默认

| Token | 实现 | 语义 |
|---|---|---|
| `Typography.largeTitle` | `Font.largeTitle.weight(.bold)` | 页面大标题 |
| `Typography.title` | `Font.title.weight(.bold)` | 模块/卡片标题 |
| `Typography.headline` | `Font.headline.weight(.bold)` | 强调行标题 |
| `Typography.body` | `Font.body` | 正文/控件 |
| `Typography.caption` | `Font.caption.weight(.medium)` | 辅助文本/chip |

无自定义字体文件；使用SwiftUI系统动态字体。局部存在 `.font(.system(size:...))` 硬编码，例如 Auth hero 46/42/19/62、Account title 36、Home/卡片icon与数字、Customer/Groomer list thumbnails。部分显式使用rounded design和black/heavy weight。

### 间距：统一 Token

| Token | 值 |
|---|---:|
| `xs` | 4 |
| `sm` | 8 |
| `md` | 12 |
| `lg` / `standard` | 16 |
| `xl` / `large` | 24 |
| `screenHorizontal` | 20 |
| `screenHorizontalLarge` | 24 |

卡片默认内边距：`BeckonCard` 为 `Spacing.lg`（16），可由调用者覆盖。页面水平边距大多20；少数大屏/特定布局使用24。

### 圆角与 Shape

| Token | 值/实现 | 语义 |
|---|---|---|
| `CornerRadius.card` | 24 | 标准卡片 |
| `CornerRadius.button` | 18 | 主/次按钮 |
| `CornerRadius.input` | 16 | 输入框 |
| `CornerRadius.bottomSheet` | 28 | bottom sheet语义；当前正式sheet多用系统presentation |
| `Shapes.chip` | Capsule | chip/status |
| `Shapes.circular` | Circle | 圆形avatar/icon背景 |

### 阴影

| Token | color / radius / x / y / spread evidence | 用途 |
|---|---|---|
| `softCard` | black 5% / 22 / 0 / 8 / 0 | 标准卡片 |
| `smallCard` | black 5% / 16 / 0 / 6 / 0 | 小卡/错误banner |
| `primaryAction` | customer 55% / 28 / 0 / 14 / -8 | Customer primary button |
| `groomerAction` | groomer 50% / 28 / 0 / 14 / -8 | Groomer primary button |

SwiftUI无spread参数；`BeckonShadowModifier`以`radius + spread`近似，不能把记录值当CSS完全等价。

### 动画：系统默认与局部常量

未发现统一Animation token。实际使用包括：

- ButtonStyle pressed/enable：`.easeOut(duration: 0.12)`、scale `0.98`。
- Customer/Groomer跨tab：`.easeInOut(duration: 0.22)`。
- Booking/date controls：`.easeInOut(duration: 0.18)`。
- Service custom size：`.easeInOut(duration: 0.2)`。
- Requests carousel：`.smooth(duration: 0.35)`。
- Auth：多组spring response `0.30...0.38`、damping `0.88...0.90`，bubble循环 `2.8...4.0s`。
- TestOps可在App根transaction关闭动画；Reduce Motion仅在部分Auth动画显式处理。

## 局部硬编码与来源分类

### 重复硬编码

| 数值/模式 | 出现位置 | 分类 |
|---|---|---|
| 页面底部 `120` | Customer Profile、Groomer Account等 | 为固定save/tab避让；重复硬编码 |
| `Spacing.xl * 4/5` | Lists、Home、forms | token组合，但具体倍数局部决定 |
| 44×44 touch target | toolbars、rows、delete/add controls | 多处重复；符合系统最小点击语义但非独立token |
| 48/52/56/64头像或icon容器 | notifications、home、booking、request | 重复尺寸族，未token化 |
| radius 8/14/16/18/22/32/34/38/44 | thumbnails、chat bubbles、hero cards、avatars | 一部分与token重合，一部分局部硬编码 |
| `.padding(.vertical, 3)` / `.horizontal, 7` | micro badges/chips | 重复微间距，未token化 |
| title size 36 | Account/Bookings/Chat customer headers | 重复硬编码字体 |

### 有明确局部语义的硬编码

- 宠物卡片 172×252、hero 160×160、request wizard photo 112×112：特定内容比例。
- Schedule day chip 64×78、request/booking thumbnails：领域布局。
- Chat bubble radius 22、composer按钮 52/56：chat-specific。
- Save bar bottom padding 120/128：固定底栏与tab bar避让，但来源未集中。
- Auth hero/animation数值：品牌landing专属。

### 系统默认值

- `NavigationStack` push/back、`TabView` tab bar、Sheet转场、Alert/Confirmation Dialog。
- `Font.largeTitle/title/headline/body/caption`动态类型基准。
- `PhotosPicker`图像选择、`Link`外部打开。
- `.ultraThinMaterial`用于部分固定save区域。

### 无法确认来源的数值

局部frame、font、radius、animation的多数具体数值没有代码注释、设计token或资源metadata说明；只能确认实现值，无法确认其原始设计来源。不要把它们误记为批准的全局设计规范。

## Asset Catalog、图标与图片资源

### Asset Catalog

| 资源 | 类型 | 用途 | 结论 |
|---|---|---|---|
| `AppIcon.appiconset` | App Icon set | iOS应用图标 | 在用；Contents.json定义平台槽位 |
| `AccentColor.colorset` | Color set | 系统accent入口 | 在用/项目资源存在；实际页面主要显式使用DesignTokens accent |

未发现业务插画、logo image set、pet/groomer placeholder位图或自定义font资源。

### 图标来源

- 正式UI主要使用SF Symbols。已确认包括导航/操作：`house`、`person.2`、`calendar`、`message`、`person.crop.circle`、`bell`、`chevron.*`、`plus`、`pencil`、`trash`、`camera`、`paperplane`、`arrow.clockwise`、`rectangle.portrait.and.arrow.right`。
- 业务/状态symbols包括：`pawprint`、`scissors`、`clock`、`location.fill`、`dollarsign.circle`、`star.fill`、`checkmark.*`、`exclamationmark.triangle.fill`、`lock.*`、`photo.*`、`sparkles`、`chart.bar.xaxis`等。
- Auth landing使用狗emoji而非Asset Catalog logo。
- 用户业务照片来自PhotosPicker或Supabase private Storage，通过`BeckonModuleImage`/feature image wrappers渲染。
- 未发现自定义SVG/PDF图标或独立图标字体。

## Figma 重设计时建议保留的语义组件

以下只定义组件职责与状态，不定义颜色、尺寸、排版或布局。

### Foundations / Actions / Feedback

| 建议Figma名称 | 业务职责 | 必须支持状态 |
|---|---|---|
| `Action/PrimaryButton` | 关键提交/保存/发布 | Customer、Groomer、enabled、pressed、disabled、loading |
| `Action/SecondaryButton` | 次级/取消/加载更多 | Customer、Groomer、Neutral、enabled、pressed、disabled、loading |
| `Action/DestructiveButton` | 删除/取消booking/account | default、pressed、disabled、loading、confirmation-required |
| `Surface/Card` | 通用内容surface | default、selected、interactive、disabled |
| `Status/Badge` | 领域状态/role/outcome | neutral、customer、groomer、success、warning、error |
| `Status/UnreadIndicator` | notification/message unread | unread/read、single/multi-count |
| `Feedback/ErrorBanner` | 页面/模块错误 | message、retry action、no action、persistent |
| `Feedback/NoticeToast` | mutation成功/一般notice | Customer、Groomer、Neutral、queued |
| `Feedback/Progress` | operation进度 | saving、uploading、deleting、pagination |
| `State/Loading` | 页面或模块load | page、section、row/image |
| `State/Empty` | 无数据 | passive、primary action、secondary action |
| `Section/Header` | 内容section标题 | title、subtitle、trailing action |
| `Form/Field` | label+input容器 | default、focused、filled、disabled、error |
| `Form/SaveBar` | 固定保存动作 | enabled、disabled、saving、error/saved feedback |

### Marketplace / Customer

| 建议Figma名称 | 业务职责 | 必须支持状态 |
|---|---|---|
| `Pet/Avatar` | pet photo/placeholder | image、placeholder、loading、unavailable |
| `Pet/Card` | Home pet summary/entry | normal、selected、add-new、disabled |
| `Pet/FormPhotoTile` | pending/persisted pet photo | empty、pending、uploaded、deleting、error |
| `Request/ProgressCard` | active request stage | published、matching、offers、accepted、cancelled |
| `Request/TimelineRow` | request lifecycle event/action | complete、current、pending、error |
| `Request/SummaryRow` | request/pet facts | photo/placeholder、status、actionable |
| `Request/PhotoTile` | request evidence photo | image、loading、unavailable |
| `Offer/SummaryRow` | groomer offer comparison | available、accepted、withdrawn/expired、fit evidence present/absent |
| `Offer/FitEvidenceBlock` | fit explanations | claims、evidence、empty |
| `Wizard/StepHeader` | request creation progress | first/middle/last、valid/invalid |
| `Wizard/ChoiceCard` | pet/service/location selection | default、selected、disabled、error |
| `Form/DateTimeRow` | request/offer date time | default、selected、invalid、disabled |
| `Form/AddressSuggestions` | address completion | loading、results、empty、error |

### Appointment / Messaging

| 建议Figma名称 | 业务职责 | 必须支持状态 |
|---|---|---|
| `Appointment/Card` | booking list/home summary | Customer/Groomer、upcoming/completed/cancelled、image/placeholder |
| `Appointment/TimelineRow` | Groomer schedule row | upcoming/current/completed/cancelled |
| `Appointment/StatusBadge` | booking status | scheduled、completed、cancelled |
| `Appointment/ActionBar` | role-correct booking actions | Customer cancel/chat/review；Groomer cancel/complete/chat；busy/disabled |
| `Appointment/ReviewForm` | Customer review | empty/valid/invalid/submitting/submitted |
| `Message/ConversationRow` | inbox summary | read/unread、Customer/Groomer、image/placeholder |
| `Message/Bubble` | chat message | sent/received、single/grouped、pending/error（若未来实现） |
| `Message/Composer` | text send | empty、typing、sending、read-only、error |
| `Message/BookingContext` | thread booking summary | active/completed/cancelled |
| `Notification/Row` | app notification | read/unread、marking、routable/non-routable |

### Groomer Configuration

| 建议Figma名称 | 业务职责 | 必须支持状态 |
|---|---|---|
| `Groomer/WorkspaceSection` | Account/settings group | title、summary、rows |
| `Settings/NavigationRow` | 跳转到配置页 | title、summary、icon、disabled |
| `Settings/ExternalLinkRow` | Privacy/Support | enabled/unavailable |
| `Service/SelectionRow` | service list item | active/inactive、default/custom sizes、menu-open |
| `Service/Form` | create/update service | create/edit、valid/invalid、saving |
| `Availability/DayRow` | weekday hours | enabled/disabled、valid/invalid range |
| `Availability/PreferenceRow` | capacity/notice/auto-ready | default/selected/disabled |
| `Availability/TimeOffRow` | time-off summary/delete | normal/deleting/error |
| `Fit/ClaimChip` | fit capability selection | selected/unselected/disabled |
| `Fit/SizeRange` | supported pet size interval | handles/range、invalid/disabled |
| `Evidence/SummaryRow` | read-only backend evidence | value/empty/loading/error |
| `Portfolio/GalleryTile` | portfolio photo | loaded/loading/unavailable/add |
| `Portfolio/PhotoDetail` | photo+fit tags | viewing/editing/saving/deleting/error |
| `Profile/AvatarEditor` | Customer/Groomer profile photo | empty/loaded/uploading/error/replace |
| `Customer/ContactRow` | contact/profile field summary | value/empty/editing/error |

## 重设计边界提示

- Figma语义组件可以统一视觉，但不得把角色、status、busy、read-only或validation状态删减为单一静态variant。
- `BeckonStatusChip`可作为视觉基线，但booking/request/offer/unread不是同一个业务枚举，Figma variants应保留领域命名。
- 图片组件必须包含private image loading、placeholder、unavailable和uploading/deleting状态，不能只画成功图。
- 主按钮必须包含async loading/disabled；分页、保存、上传、删除不能共用无法表达scope的单一spinner。
- Sheet与Push的Toolbar语义不同；未来组件可以共享外观，不能交换dismiss/save行为。
- 当前硬编码数值是实现证据，不等同于未来Figma token决策。

## 本阶段停止点

本文完成现有组件、重复实现、视觉token、资源与Figma语义组件盘点，不进行组件合并、代码修改或具体视觉设计。
