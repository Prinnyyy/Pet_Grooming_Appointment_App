# Figma UI Redesign — Phase 0 Discovery Plan

> 状态：Phase 0 完成。本文只锁定产品理解、设计方向、Figma 结构与 v1 范围；未创建或修改任何 Figma 文件、页面、变量、组件或节点，也未修改生产代码。

## P0.a 产品和用户场景总结

### 用户、环境与高频任务

Beckon 服务两类用户：Customer 在移动场景中维护宠物、发布美容需求、比较报价、查看预约和沟通；Groomer 在门店或服务现场快速处理匹配请求、报价、当天日程、客户沟通和履约状态。代码中的双角色五 Tab、Groomer 日程时间轴、未读 badge、前台自动刷新与大量单行压缩处理，说明界面不仅用于浏览，也需要在忙碌、易被打断的工作环境中快速扫描。

高频任务集中在：查看当前请求/预约状态、打开详情、切换预约范围或日期、进入聊天、提交 offer、完成服务。低频但高风险任务包括取消 request/booking、删除账户、删除作品和接受 offer。

### 关键业务对象

`CustomerProfile → Pet → GroomingRequest → Match → Offer → Booking ↔ Conversation → Review`。Groomer 侧的 `Profile`、`Service`、`Availability/TimeOff`、`FitSignals/Evidence`、`PortfolioPhoto` 支撑匹配和成交，而不是独立交易链。

### 页面任务类型

| 类型 | 页面/模块 | 设计重点 |
|---|---|---|
| 高频操作 | 双角色 Home、Requests、Bookings/Schedule、Chat | 少步骤、明确主操作、避免误触 |
| 快速扫描/状态识别 | Groomer Schedule、请求/offer/booking 列表、Notifications | 时间、对象、状态、下一步必须形成稳定扫描顺序 |
| 信息展示 | Request/Offer/Booking Detail、Evidence、Portfolio Detail | 分组层级与事实/状态分离 |
| 表单录入 | Auth、Pet、Request Wizard、Offer、Service、Availability、Profile、Fit、Review | Dynamic Type、键盘、校验、保存中和失败后保留输入 |
| 低频管理 | Account、Services、Portfolio、权限提示 | 可发现但不能挤占核心流程 |

### 最重要页面与失败风险

P0 页面是认证、Customer Home/Requests/Bookings/Messages 与 Groomer Home/Requests/Schedule/Messages。最严重风险不是视觉不一致，而是：接受错误 offer、取消错误预约、重复提交、保存失败却显示成功、角色越权、表单失败丢失输入、状态颜色成为唯一信息来源，以及跨 Tab focused ID 丢失导致用户落到错误上下文。

代码验证来源包括 `AppRootView`、双角色 `TabView`、`BookingsView`/`BookingsStore`、Customer/Groomer Requests、Chat subscription、Repository/RPC 调用和 `07-ui-redesign-brief.md` 的追溯索引。

## P0.b 当前 UI 与代码约束

### 重建必须保留

- Auth session、profile role gate 与 Customer/Groomer 权限边界。
- 每个 Tab 独立 `NavigationStack`，以及 `focusedRequestID`、`focusedConversationBookingID`、`requestsRoute`、`requestedProfileRoute` 等程序化导航结果。
- Request Wizard、编辑表单和 Sheet 的现有 `Binding`/draft；失败时保留输入，成功/Cancel 按现有规则 dismiss。
- Store 中的必填、范围、状态与角色验证；不得由 Figma 视觉简化绕过。
- Offer 接受后原子创建 booking/conversation；Groomer 完成后 Customer 才能 review。
- Repository 返回结果驱动 UI，不能以纯视觉乐观状态替代成功事实。
- Chat participant/read-only 判断、message subscription 生命周期、前台刷新去重、私有图片加载。
- 账户删除双重确认、作品删除确认、request/booking 取消规则及成功后的导航结果。

### 容易破坏的功能

- 把共享 `BookingsView` 或 Chat 页面视觉合并后忽略角色不同的操作权限。
- 用统一卡片隐藏 request、offer、booking 生命周期差异。
- 将 Wizard 分步校验改成一次提交，或让 Sheet 嵌套 handoff 丢失 draft。
- 将异步 error/loading 做成覆盖层而遮蔽仍可用内容。
- 仅靠颜色表达状态，或固定高度/单行截断造成 Dynamic Type 信息丢失。
- 重做导航时丢失 notification 和 Home 的跨 Tab 跳转目标。

### 不应直接延续的视觉实现

现有 `DesignTokens.swift` 和 Feature 内硬编码只代表当前实现，不是新规范。不得直接继承当前品牌色、渐变、固定阴影、局部圆角、页面 padding、卡片层叠、`minimumScaleFactor` 或大量 `lineLimit`。当前多个 Feature 自建 card、badge、primary style 和 feedback bridge，也不应被当成理想组件架构。

### 有复用价值的语义

可保留的是职责与 API，而非外观：Action（primary/secondary/destructive/loading）、Feedback（loading/empty/error/persistent）、Status Badge、Request/Offer/Booking Card、Pet Avatar、Conversation/Notification Row、Form Section/Field、Account Row、Private Image、Foreground Refresh Gate。

## P0.c Figma 环境检查结果

### 连接与能力

Figma MCP 已连接到 `Fengyuan Lian`（Starter team，Full seat）。

| 能力 | 状态 | Phase 0 说明 |
|---|---|---|
| 读取文件/节点 | 可用 | `get_metadata`、`get_design_context`、只读 `use_figma` |
| 创建 Design/ FigJam/Slides 文件 | 可用 | `create_new_file` 明确区分 editorType；本阶段未调用 |
| 创建/修改节点 | 可用 | `use_figma` Plugin API；本阶段未调用 |
| Variables | 可读写 | Variable definitions、local/remote variables API |
| Components/Variants | 可读写 | Component、ComponentSet、properties、imports |
| 截图 | 可用 | `get_screenshot` 与 node screenshot |
| metadata/结构 | 可用 | `get_metadata` 与 Plugin API traversal |
| 本地/团队设计库 | 可查询 | `get_libraries`、`search_design_system`；需目标 fileKey |
| Code Connect | 可查询/写入 | 仓库未发现 Swift `FigmaConnect` 或 `.figma.*` 映射 |

### 目标文件检查

仓库未发现 `figma.com/design/`、`/board/`、`/slides/` URL 或 fileKey；当前请求也未提供目标文件。现有 MCP 没有列出账户全部文件的接口，因此结论是“未发现可定位的项目专用文件”，不是“已证明不存在”。没有 fileKey 时无法检查页面、变量、样式、组件和库订阅。

建议下一阶段新建 **Figma Design** 文件 `Pet Grooming App — UI Redesign`。不得使用 FigJam 或 Slides；创建前仍应让用户提供可能存在的 Design URL，避免重复文件。本阶段未创建。

## P0.d 设计系统现状与差距

| 层 | 当前事实 | 差距 |
|---|---|---|
| Code colors | `DesignTokens.Colors` 与局部硬编码存在 | 需重建 primitive→semantic、Light/Dark、状态语义；不能直接搬值 |
| Typography | 主要使用 SwiftUI system text styles，局部 weight/line limit | 缺少正式角色、用途、缩放规则与 Figma text styles |
| Spacing/Radius/Shadow | 有 Token 与大量局部值 | 缺统一语义层、变量 scope 与可访问性验证 |
| Components | 有 Button、feedback、card/row/badge/avatar/form 等语义实现 | 重复 family 需在 Figma v1 统一 API，不在 Phase 0 合并代码 |
| Assets | Asset Catalog 仅 AppIcon、AccentColor；业务图多为私有/运行时图片，图标以 SF Symbols 为主 | 需要图片占位/加载/失败规范；不应复制真实私有数据 |
| Figma local | 无可定位 fileKey | 页面、变量、样式、组件状态待 Phase 1 前只读检查 |
| External library | MCP 支持查询，但无目标 fileKey | Apple iOS/SF Symbols/团队库可访问性待文件确定后验证；不能先假定可用 |
| Code Connect | 仓库搜索未发现映射 | Phase 4 再建立 SwiftUI 映射；Phase 0 不创建 |

项目最低部署目标为 iOS 18.0，目标设备 family 为 iPhone 与 iPad；iPhone 支持 portrait 与 landscape，iPad 支持四方向。代码大量使用 system fonts、accessibility identifiers/labels/traits，但未发现全局 Dynamic Type 上限；局部 `lineLimit` 和 `minimumScaleFactor` 是重设计风险。v1 应以 iPhone portrait 为主画板，同时验证 landscape、iPad 自适应和至少常用辅助 Dynamic Type 尺寸。

## P0.e 三个视觉方向

### 方向 A：Operational Timeline（运营时间轴）

- 核心关键词：时间优先、状态前置、紧凑分组、行动明确。
- 信息密度：中高；首屏优先今日任务与下一步。
- 卡片：仅作为可操作业务单元；日程采用连续时间轴/分组行，避免每条都重阴影悬浮。
- 导航层级：原生 Tab + NavigationStack；标题、日期/范围控制和 toolbar 形成稳定层次。
- 色彩：低彩度中性 surface，品牌色用于主操作；状态色仅作辅助并配文字/图标。
- 字体：San Francisco 动态文本样式，时间/金额可用等宽数字特性。
- 状态：成功、警告、危险、信息使用语义 token；badge 与整卡状态分离。
- 适合原因：最符合 Groomer 忙碌环境与 Customer 预约追踪，扫描快、误触边界清晰。
- 缺点：宠物品牌情感表达较克制；低密度页面需避免显得工具化。
- SwiftUI 复杂度：低到中，原生 List/ScrollView、safe area、toolbar 可实现。
- Dynamic Type/深色风险：低；时间轴需防止横向日期条与大字冲突。

### 方向 B：Pet Profile Canvas（宠物档案画布）

- 核心关键词：宠物身份、影像主导、柔和分区、关系感。
- 信息密度：中低；宠物照片和服务故事占更高权重。
- 卡片：较大档案卡连接宠物、请求与预约；详情采用连续内容画布。
- 导航层级：原生导航不变，以宠物作为 Customer 侧上下文锚点。
- 色彩：温暖中性色与克制的角色 accent；图片承担情绪，不依赖高饱和背景。
- 字体：SF Rounded 可限于品牌/短标题，正文仍用 SF Pro 动态样式。
- 状态：语义色收敛为小 badge、边框与文本，避免覆盖宠物图像。
- 适合原因：强化信任、宠物个体感和 Customer 侧情感价值。
- 缺点：Groomer 日程和密集请求效率下降；图片缺失/加载失败时体验落差大。
- SwiftUI 复杂度：中；图片裁切、占位和跨尺寸布局更多。
- Dynamic Type/深色风险：中；大卡片和图片文字叠加不适合超大字体，应避免 overlay 文案。

### 方向 C：Structured Ledger（结构化工作台）

- 核心关键词：表格感、分栏、边界清楚、数据可信。
- 信息密度：高；同屏展示时间、宠物、服务、状态与金额。
- 卡片：弱化卡片，使用 section、分隔线、summary band；详情以 facts grid 为主。
- 导航层级：Tab + 明确 section header；iPad 可自然扩展双栏，但不改变当前导航逻辑。
- 色彩：近单色 surface，角色/状态色只出现在标签和关键数值。
- 字体：SF Pro；层级更多依靠 size/weight/spacing，数值对齐稳定。
- 状态：状态列/标签固定位置，危险操作保持独立区域。
- 适合原因：大量预约和门店运营扫描效率最高，适合未来 iPad。
- 缺点：Customer 侧可能过于行政化；触控设备上密度过高会增加误触。
- SwiftUI 复杂度：中；自适应 grid、横竖屏与 iPad 布局需要额外工程。
- Dynamic Type/深色风险：中高；多列在大字体下必须退化为纵向行，不能固定列宽。

## P0.f 推荐视觉方向

默认推荐 **方向 A：Operational Timeline**，但不视为自动批准。

它在高频预约操作、状态扫描和门店中断环境间最平衡：比 Pet Profile Canvas 更适合当天日程，比 Structured Ledger 更不易在 iPhone 上误触。它可依赖 SwiftUI 原生 Tab、NavigationStack、toolbar、动态文本和语义色实现，Light/Dark 维护成本较低；主要风险仅是日期条和紧凑行在辅助字号下需切换为纵向布局。可从方向 B 借用宠物身份元素，但不采用大图主导的信息架构。

## P0.g Design Tokens v1 范围

Phase 1 只建立下列基础集合，不复用当前硬编码值：

- Primitive Colors：neutral scale、brand seed、blue/green/amber/red primitives、black/white/transparent。
- Semantic Colors（Light/Dark）：background、surface、surface elevated、text primary/secondary/disabled/inverse、border、accent、focus、success/warning/error/info、interactive/destructive。
- Typography：large title、title 1/2/3、headline、body、callout、subheadline、footnote、caption、button；记录 Dynamic Type 对应关系。
- Spacing：2/4/8 基础节奏至页面级间距，不预设当前 Swift 值为真值。
- Radius：none/small/medium/large/full。
- Border：hairline/default/emphasis/focus。
- Shadow：none/subtle/elevated，Dark Mode 单独验证而非简单复制。
- Icon Size：small/standard/large；基于 SF Symbols optical sizing。
- Touch Target：minimum 44×44 pt，紧凑视觉元素仍保留命中区域。
- Animation Duration：instant/fast/standard/slow，并提供 Reduce Motion 行为。

## P0.g Components v1 范围

第一批严格限定为：Primary Button、Secondary Button、Destructive Button、Icon Button、Appointment Card、Status Badge、Pet Avatar、Customer Row、Service Row、Form Field、Date and Time Row、Search Field、Section Header、Empty State、Error State、Loading State。

共同状态至少包括适用的 default/pressed/disabled/loading/focused/error/selected；组件属性应暴露文本、图标和必要 instance swap。Search Field 属于跨模块前瞻基础组件，但当前正式页面未发现 `.searchable`，不得据此新增产品搜索功能。本阶段不创建组件。

## P0.h Figma 页面结构

建议 Design 文件结构：

- `00 Cover`
- `01 Foundations`
- `02 Components`
- `03 App Structure`
- `10 Appointments`
- `20 Requests & Offers`
- `30 Customers & Pets`
- `40 Groomer Services`
- `50 Availability & Calendar`
- `60 Messages & Notifications`
- `70 Account & Settings`
- `80 Auth & Onboarding`
- `90 Archive`

`10 Appointments` 专注 booking/schedule；Request Wizard 放在 `20 Requests & Offers`，但试点 flow 可用链接/占位状态展示两者 handoff。编号为后续扩展留空间。

## P0.h 首个试点模块

### 推荐：Appointments（双角色预约/日程）

代码确认它具有代表性：共享 `BookingsView` 和 `BookingsStore` 同时承载 Customer 列表与 Groomer Schedule；有 scope filter、日期 strip、summary band、timeline/card、Push detail、toolbar/navigation、role-specific actions、review form、cancel confirmation、request republish Sheet、loading/empty/error/pagination、提醒权限反馈与跨 Tab chat。

它不具备独立的“创建预约”表单或文本搜索——产品是 request-first，预约由接受 offer 创建。不能为了满足组件清单而虚构直接创建/编辑 appointment。试点用现有 scope/date filter 代表筛选，用 cancelled booking → Request Wizard Sheet 代表合法创建 handoff。

### 试点页面与状态

| Surface | 必须设计的状态/交互 |
|---|---|
| Customer Bookings | upcoming/history/cancelled scope、loading、empty、error、loaded、pagination、reminder notice |
| Groomer Schedule | selected day、summary、timeline、loading、empty day、error、pagination |
| Customer Booking Detail | normal、chat handoff、cancel confirmation、cancelled→republish、review validation/saving/error/saved |
| Groomer Booking Detail | normal、chat、complete enabled/disabled、cancel confirmation、service completion error |
| Request Wizard handoff Sheet | 从 cancelled booking 带入上下文、Cancel、validation、saving、error、success dismiss |
| System/permission feedback | reminder permission/调度失败形式待产品决定，不先画成正式页面 |

## P0.i SwiftUI 重建必须保留的业务边界

- `BookingsView(role:)` 的角色差异和 `BookingsStore` scope/state，不把双角色操作集合并。
- `BookingDetailView` 的 Customer review、Groomer complete、双方 cancel/chat 的权限条件。
- `onOpenChat` 切换 Messages 并聚焦 booking conversation 的结果。
- cancelled booking 只能通过现有 request republish/new request handoff，而非直接恢复 booking。
- reminder scheduler、repository/RPC 错误与成功后刷新；不能用本地外观提前宣告成功。
- Review/取消/完成的验证、destructive confirmation、disabled/loading 防重复提交。
- Accessibility identifiers 可在实现重建时保留或等价迁移；可见状态不得只靠颜色。

## P0.j 风险和待决策事项

1. 是否批准 Operational Timeline 为默认方向，或需混入 Pet Profile Canvas 的情感强度。
2. 是否存在尚未提供的项目 Figma Design URL；若存在，应先只读审计再决定复用。
3. Groomer 是否需要删除账户入口。
4. Groomer booking notification 应切 Schedule 还是直接打开 detail。
5. Customer notification row 的目标业务路由。
6. Push authorization 的预提示、时机及拒绝反馈。
7. Reminder permission/调度失败采用页面级、inline 还是 transient feedback。
8. “Realtime chat”的产品表述边界。
9. Offer 提交/接受成功后 stay 还是 pop。
10. v1 是否需要同时交付 iPad 专属布局；建议先 iPhone responsive foundation，再验证 iPad，不改变设备支持。

## P0.k Phase 1—Phase 4 执行顺序

- **P1.a** 获取/确认目标 Design fileKey，只读检查 pages、local variables/styles/components、libraries 与 Code Connect；若确认无文件，经用户指令后创建建议文件。
- **P1.b** 锁定方向与 token 值，创建 Primitive/Semantic variables、Light/Dark modes、text/effect styles；逐批 metadata/截图验证。
- **P2.a** 建立编号页面骨架与 Foundations 文档，不创建业务页面。
- **P2.b** 按依赖顺序逐个创建 Components v1；每个组件独立验证 variants、bindings、Dynamic Type 与 Dark Mode。
- **P3.a** 设计 Appointment 试点的 Customer 列表、Groomer Schedule、双角色详情和合法 Request Wizard handoff。
- **P3.b** 完成 prototype：筛选、Push、Sheet、chat handoff、取消、完成、review、loading/empty/error。
- **P3.c** 评审并锁定可复用模式；未通过前不扩展到其他模块。
- **P4.a** 依优先级扩展 Requests/Offers、Home、Chat、Profiles/Settings 等页面。
- **P4.b** 做全文件 accessibility、命名、变量绑定、状态、原型链接、截图和 Code Connect QA。

任何 Phase 均采用小步写入、每步验证；不得一次大型 Figma 调用。

## Phase 0 Summary

- 已读取的主要文件：`docs/ui-redesign/README.md`、`01`—`07` 全部盘点文档；`BeckonApp.swift`、`AppRootView.swift`、双角色 Tab/Navigation、`DesignTokens.swift`、DesignSystem primitives、Bookings/Requests/Chat/Profile 核心文件、Asset Catalog、Xcode deployment 配置与 accessibility/Dynamic Type 相关调用。
- Figma 连接状态：已连接，具备 Design 文件、节点、Variables、Components/Variants、截图、metadata、library search 和 Code Connect 能力。
- 目标文件：未发现可定位的项目专用 Design fileKey；建议名 `Pet Grooming App — UI Redesign`，本阶段未创建。
- 推荐视觉方向：Operational Timeline。
- 推荐试点：Appointments 双角色预约/日程 + 合法 Request Wizard handoff。
- 仍需产品决策：10 项，见 P0.j；其中目标文件和默认方向是进入正式写入前的关键决策。
- 生产代码：未修改。
- Figma：未写入，未创建文件、页面、变量、组件或节点。
