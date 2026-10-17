# Beckon UI/UX 审查与优化方案

> **性质：外部审查草稿（仅供参考，不属于正式文档）。** 不改变分支、任务号、验证状态或产品状态。按惯例放在仓库根目录、不纳入 Git；被采纳后归档到 `docs/09_frozen/external_agent_reports/`。
> 基线：`main` @ `e8c2d2b5`（T-408），下一个可用任务号 T-409，2026-10-17。
> 证据来源：`DesignTokens.swift` 与 DesignSystem 原语、Feature 源码 grep 统计、Simulator 实时截图（Customer Home，2026-10-17）、TestOps 截图（2026-09-13～15）、Groomer approved 截图。
> 注意：Groomer 相关截图拍摄于 T-402（2026-10-04）之前，标 ⚠ 的条目需要在当前构建上复验。

---

## 0. 结论摘要

“不够精美、不统一”主要不是某个页面的问题，而是 **token 层的配色模型本身有结构缺陷**，各页面只是在放大它：

1. **主色没有问题，用法有问题。** 薄荷和珊瑚被透明度叠在暖白上（渲染成橄榄灰）、渐变跑到灰青、用中性灰或棕色当墨色字、深色调发灰，再加上彩色光晕和额外配色，所以看起来发闷、不舒服（详见 §5 D1）。
2. **品牌色和语义色撞色。** success 绿接近薄荷（亮度比 1.26），error 红接近珊瑚（1.54）。于是 Groomer 的“Confirmed”看起来像报错，Customer 的“Pending”看起来像已成功。
3. **状态色的映射在各 Feature 里各写一套。** 同一个状态在不同页面显示成不同颜色（见 §1.3）。
4. **系统蓝泄漏。** `AccentColor` 没有设值，根视图也没设 `.tint`，所以没显式着色的控件都会变成 iOS 默认蓝。
5. **透明度随手写。** 代码里有 59 种不同的“token.opacity(x)”组合，光薄荷就有 9 种透明度，渲染出来是十几种深浅不一的“薄荷”。
6. 还有文案和内容问题：时间里带 `-0700 (America/Los_Angeles)`、内部占位文字外露、复数形式错误、大小写规则不一致。

**D1（保留浅色主色 + 同色系深色字）、D2、D3 均已于 2026-10-17 确认**（见 §5 阶段 0）。建议路线：**ADR 落档 → 重构 token → 修 6 个原语 → 修文案和格式 → 按页面迁移 → 加门禁**。前三步做完，大约 70% 的“不统一”感会消失，而且不需要逐页重写。

---

## 1. 配色问题（重点）

### 1.1 Token 现状与对比度实测

| Token | 值 | 实测（WCAG） | 问题 |
|---|---|---|---|
| customerAccent | P3 `#93CEC2` | 当文字放在白底上 **1.77** | 只能当底色，不能当文字或图标色 |
| customerAccentStrong | P3 `#518B7F` | 白底 **3.93**，app 背景 3.67 | 被当作小字色用（StatusChip `.customer`、步骤标签、空状态），**未达 AA**，也**不在** `ACCESSIBILITY_RULES` 的允许配对表里 |
| groomerAccent / Dark | `#FF9A8B` / `#F58575` | 白底 2.05 / 2.47；白字压在上面 2.47 | Approved 的 Groomer Home 截图用了“白字珊瑚按钮”，但规则表禁止白字压珊瑚，设计稿和规则矛盾 |
| error | `#E56B6F` | 白底 3.15 | 被当正文色用 |
| warning | `#F2B84B` | 白底 1.79 | 用于星级图标还行，不能用于文字 |
| textSecondary / textTertiary | `#6F767E` / `#69717A` | 4.6 / 4.95 | **层级倒挂**：tertiary 比 secondary 更深；而且两者都是偏蓝的冷灰，和暖白背景 `#FAF7F2`、暖色边框 `#E8E2D8` 冷暖冲突 |
| customerAccentSoft / Subtle | `#B0D8D9` / `#B5DCD9` | — | 两个值肉眼几乎分不出来，属于重复 token |
| notificationUnread | `#FF3B30` | — | App 里实际有四种红/粉（error、coral、coralDark、系统红），而且没有统一的规则 |
| 色彩空间 | 薄荷用 Display P3，其他都是 sRGB | — | 同一屏混用两种色彩空间，色值不好推算，`design_tokens.json` 也没法对齐 |

### 1.2 违规调用点（源码证据）

- `SharedFeatures/Address/BeckonAddressEditor.swift:268`：“Verify Address”用 `customerAccent` 当文字色，对比度 1.77。
- `Features/Customer/Requests/CustomerRequestsView.swift:309`：错误文案用 `Colors.error`，应改用 `errorText`。
- `Features/Bookings/BookingFulfillmentSection.swift:69`：“Refresh Outcome”渲染成**系统蓝**。原因是 `Assets.xcassets/AccentColor` 只有空的 `idiom`，没有色值，根视图也没设 tint。
- `.tint(groomerAccent)` 共 9 处、`.tint(groomerAccentDark)` 共 4 处：珊瑚色的图标/文字压在白底上（2.05–2.47），图形元素也没达到 3:1。
- `DesignSystem/BeckonFeedbackPrimitives.swift:1300`：EmptyState 的 Groomer 图标用 `groomerAccentDark`（2.47）。
- ⚠ 截图：Groomer Requests 行里“1000 related reviews…”用珊瑚色小字；顶部工具栏的珊瑚图标放在珊瑚浅底胶囊上。
- `Shadows.groomerAction` 里直接写了 `0xFF9A8B`，没有引用 token。

### 1.3 状态色映射漂移（同一状态，不同颜色）

`BeckonStatusChip.Tone` 把**角色色（`.customer`/`.groomer`）**和**语义色（success/warning/error）**混在一起，每个 Feature 自己写 `xxxTone`：

| 状态 | 位置 A | 位置 B | 结果 |
|---|---|---|---|
| Offer pending | `CustomerRequestDetailView.swift:1325` → `.customer`（薄荷），图标 `clock` | `GroomerOffersView.swift:500`、`GroomerRequestsView.swift:1433` → `.warning`（琥珀），图标 `paperplane.fill` | 同一个 Offer，两边看到的颜色和图标都不同 |
| Offer declined/expired | Customer → `.neutral` | Groomer → `.error` | 同上 |
| Request hasOffers | `CustomerRequestDetailView.swift:1295` → `.customer` | `CustomerRequestsDashboardView.swift:1354` → `.warning` | **同一角色**的列表页和详情页颜色不同 |
| Booking confirmed | `BookingsView.swift:1812` → 角色色（Groomer 是珊瑚） | completed → `.success` | 珊瑚“Confirmed”和 error 红很难区分 |

### 1.4 装饰性用色随意

- 宠物头像底色按物种随机取薄荷、黄、粉（Customer Home、Wizard），和品牌色系没有关系。
- Groomer Home 的“Needs attention”同时用了绿、黄、蓝三种图标底色，蓝色不属于任何 token。
- Hero 里的剪刀 emoji 是红色，压在薄荷底上；爪印装饰是深灰色 `#515555`。
- 主按钮 = 浅色渐变 + 半径 28、透明度 55% 的彩色光晕：视觉上发“糊”，而且显得过时。

### 1.5 设计文档和实现不一致

- `docs/08_design/design_tokens.json`：textPrimary `#232323`、textTertiary `#9AA0A6`、customerPrimary `#7ECFC0`，三个都和 Swift 不一致。
- `docs/ui-redesign/10-existing-visual-language-audit.md` 认为珊瑚“不应形成第二套产品品牌”，后来的 D-026/R-039 又把珊瑚定为 Groomer 的主 action 色，**两份文档的结论互相冲突，也没有记录取舍**。
- `DESIGN_SYSTEM.md` 写的是“mint/teal action roles”，实际主按钮是浅薄荷渐变，并不是 teal。
- `ACCESSIBILITY_RULES.md` 的允许配对表漏了 customerAccentStrong 作为文字色这种实际在用的情况。

---

## 2. 字体与层级

- `Typography.caption`（兼容名，12pt medium）用了 **177 次**，是全 app 用得最多的字体，导致整体信息“小而灰”。兼容名 `headline` 50 次、`largeTitle` 6 次、`title` 4 次也还在用；文档写的是“用量归零后移除”，实际没有推进。
- 9 处 `Font.system(size:)`，11 处 `.font(.system…)`，另有 40 多处直接用平台字体（`.body`、`.title3`…），绕过了 token。
- `minimumScaleFactor(0.82)` ×3、`(0.84)` ×1，违反 A11Y-R1“不得低于 0.85”。
- 标题重复：Customer Offers 页先是导航标题“Offers”，下面又一个大号“Offers”，再下面是“PENDING OFFERS”分区标题，同一个词出现三次。
- 大小写规则混乱：Customer 用 Title Case（“Welcome Back”“Who Needs Grooming?”“I'm Flexible With Time”“Choose Another Date”），Groomer 用 sentence case（“Next appointment”“Needs attention”）。

## 3. 形状、间距、阴影

- 圆角：token 有 24/18/16/28，另有字面值 8、16、18、22、24、34、48，**实际至少 9 种**。
- `Spacing.screenHorizontal` 和 `Layout.pageHorizontalInset` 都是 20，重复定义。
- 阴影：卡片阴影 + 彩色按钮光晕，两种风格并存。Customer 是“卡片 + 阴影 + 边框 + 24 圆角”，Groomer 是分组列表，**两个角色看起来像两个产品**。共享页面（Bookings、Chat）又按角色换主题色，进一步放大了割裂感。
- `UI_CONSISTENCY_DEBT.md` 记录的 182 条历史债（T-396），主要集中在 GroomerHome（35 条）、Chat（24 条）、Bookings（23 条）。

## 4. 内容、文案与交互细节

| 问题 | 证据 | 建议 |
|---|---|---|
| 时间里带时区 ID，列表被截断 | `Core/Models/CustomerRequest.swift:351-359`（7 处调用）、`GroomerRequestsView.swift:1029`、`CustomerRequestWizardView.swift:708`、`BookingsView.swift:264` | 默认显示“Sep 19 · 10:00–11:00 AM”，只有服务时区和设备时区不一致时才加“PDT”缩写；完整 ID 放到详情页或无障碍标签里 |
| 原始值和占位文字外露 | “Service Details”“Location Details”“Customer ref 01CEF415”“(service time zone unconfirmed)”；Booking 详情里一整句加粗右对齐的长地址提示 | 模型层提供 `displayTitle` / 兜底文案；长提示改成独立的提示行 |
| 复数错误 | `Core/Models/MatchingEvidence.swift:18`：“from 1 customers” | 用 `String(localized:)` 的 inflection 或手写单复数分支 |
| 请求没有标题时显示成“…” | ⚠ Groomer Matches 列表 | 改为“宠物名 · 服务”兜底 |
| emoji、SF Symbol、照片混用 | 20 处 emoji 字面值（🐩🐱✂️） | 统一成中性底色上的 SF Symbol 占位图，照片优先 |
| Toast 盖住内容 | “Review Submitted”压在 Pet Fit Notes 上 | 改用 `safeAreaInset(edge: .bottom)` 给反馈区预留空间 |
| 时间选择器浮在表单上 | Wizard 截图（T-392） | 改用 sheet 或 `.compact` DatePicker |
| Debug 按钮“Finish Local Check”显示在页面顶部 | Wizard 截图 | 确认只在 DEBUG/TestOps 下出现 |
| Tab 角标“50”用纯红 | Customer Home 的 Tab | 统一角标 token，超过 99 显示“99+” |

---

## 4.5 审查覆盖范围与局限

很多页面只有在创建了对应数据之后才会出现（例如：有 Offer 的请求、已确认/已完成/已取消的 Booking、Chat 会话、通知、评价、空状态和错误状态）。在模拟器里直接点，到不了这些页面。本次各页面的证据来源如下：

| 证据级别 | 覆盖内容 |
|---|---|
| 实时运行（2026-10-17） | 只有 Customer Home 一屏（模拟器操作权限未获批，没能继续点击浏览） |
| 历史 TestOps 截图（2026-09-13～15，T-390～T-392 生命周期跑出的数据） | Customer Offers、Request Wizard（选宠物、选时间）、Booking 详情（两种角色）、Groomer Requests/Offer 详情 |
| Groomer approved 截图 | Groomer Home、Requests、Account、Edit Profile（设计目标，不代表当前实现） |
| 只看了源码 | 其余页面，包括 Notifications、Chat 会话、Reschedule、Fulfillment 各状态、Availability/Fit Signals 编辑器、各种空状态和错误状态 |

所以，§1.3 的状态色漂移、§1.2 的违规调用、§4 的时间格式问题，都**以源码为准**，不依赖某个页面能不能打开。只看源码的页面上，截图可能会暴露更多视觉问题。

**建议在迁移时补上“状态矩阵 Preview”，不靠真实造数据来做视觉审查**：

- 目前 Features 下只有 11 个 `#Preview`，大部分依赖数据的页面没有 Preview。建议每个页面迁移时，按 `PREVIEW_AND_TEST_FIXTURES.md` 允许的方式，补上用预览 fixture 渲染的 Preview：loading / empty / content / error，再加上该页面的关键领域状态（例如 Offer 的 pending/accepted/declined/withdrawn，Booking 的 confirmed/completed/cancelled/unfulfilled），并分别出默认字号和 AX3 两个版本。
- 扩展 `BeckonComponentCatalog`，把所有状态 chip × 两个角色放在同一页对照；改完 D2–D3 之后，一屏就能检查完。
- 需要真实端到端截图的页面，复用 TestOps 的种子账号和生命周期场景生成数据后再截图（远程写入仍要按现有规则单独授权），不要临时手工造数据。

## 5. 优化方案

### 阶段 0：决策（已全部确认）

**D1 品牌色策略 —— 最终方案：保留浅色主色 + 同色系深色字（2026-10-17）**

> 修订记录：用户先选了方案 B“两套角色色都改成白字实色”，随后明确表示**对现有主色调满意，只是细节看着不舒服**，并把方案选择交给设计判断。因此方案 B 的“两套角色色”结构保留，“白字实色”部分作废。

选择理由：
1. **保留用户认可的品牌识别**：薄荷 `#93CEC2`、珊瑚 `#FF9A8B` 和暖白背景都不变。
2. **问题本来就不在主色本身**，而在用法：透明度叠加、渐变跑色、中性灰字压彩色、深色调发灰、额外颜色太多、彩色光晕（原型诊断表 1–8）。这些只改 token 和原语就能修好。
3. **全部配对达到 AA**，而且现有按钮结构本来就是“深色字压浅色”，迁移成本最低。
4. 白字实色会让界面整体变重、变暗，偏离 `DESIGN_SYSTEM.md` 里“Friendly, calm”的定位。

角色色色板（sRGB，全部实测）：

| Token（建议名） | Customer 薄荷 | Groomer 珊瑚 | 用途 / 替代了什么 |
|---|---|---|---|
| `{role}Fill` | `#93CEC2` **保持**（代码里是 Display P3，等价于 sRGB `#81D0C2`；实施时统一用 sRGB 等价值，薄荷系其他颜色也按此推导，详见 `UI_COLOR_IMPLEMENTATION_HANDOFF.md` §1.1） | `#FF9A8B` **保持** | 主按钮、Hero、强调面 |
| `{role}FillPressed` | `#7FC3B5` | `#FF8A79` | 按下态（不再用反转渐变） |
| `{role}Ink` | `#0F3D35`（压在填充色上 6.81） | `#4A1C14`（压在填充色上 6.98） | 填充色上的文字和图标，替代中性灰 `#333333` 和发闷的棕色 `#642620` |
| `{role}Deep` | `#1E6E5F`（白底 6.09 / 背景 5.69 / 浅底 5.31） | `#B23A2B`（白底 5.94 / 背景 5.56 / 浅底 5.25） | 链接、文字按钮、Tab 选中、进度条、小号强调文字、控件 tint；替代发灰的 `#518B7F`，以及直接拿珊瑚当文字（2.05） |
| `{role}Tint` | `#E3F3EE`（实色） | `#FFEDE9`（实色） | 选中底、图标底块、Tab 选中底；替代各种 `accent.opacity()` |
| Hero 辅助色 | 渐变终点 `#A9DACF`、气泡 `#BEE4DA`、爪印 `#7DBDB0`（都和薄荷同色相） | —（Groomer 不用 Hero 渐变） | 替代偏灰青的 `#B0D8D9`/`#B5DCD9`，以及冷灰色爪印 `#515555` |

配套硬规则：

1. **角色色只表示“可点击 / 已选中 / 当前角色”**，不用于状态 chip、错误提示和通知角标。
2. **填充色上一律用同色系的 Ink**：不用白字，也不用中性灰。
3. **浅色 Fill 不能当文字、细线或进度条**（白底上薄荷只有 1.77，珊瑚只有 2.05），这些地方一律用 Deep。
4. **浅底一律用预混好的实色 Tint，禁止把 `accent.opacity()` 叠在暖白上**：14% 薄荷叠在 `#FAF7F2` 上，实际渲染成色相 110° 的橄榄灰（本来应该是 168°），这是“看着脏”的首要原因。
5. **珊瑚和 error 要分开**：珊瑚 Fill 和 error `#B3203F` 的亮度比是 3.21，可以区分；但 Groomer Deep `#B23A2B` 和 error 的亮度几乎一样（1.11）。所以 Deep 只用于可点击元素（带 › 或按钮形态）和选中态；错误提示永远是“error 色 + 感叹号图标 + 错误容器”。Groomer 的破坏性操作用白底 + error 文字/边框，**绝不用珊瑚**。
6. **薄荷和 success 要分开**：success `#276B2B` 是深绿，和薄荷 Fill 亮度比 3.67，而且永远搭配对勾图标。
7. **共享页面（Bookings、Chat）只有按钮和链接随角色换色**；状态 chip、卡片、分组、排版完全一致。
8. **按钮不用渐变和彩色光晕**；Customer Hero 可以保留同色相的轻渐变。
9. 宠物和头像占位图用中性暖灰 `#F1ECE4`，不再按物种配黄色、粉色；待办图标统一用 Ink 色加中性底块，不再用绿、黄、蓝多色。
10. Groomer approved 截图里的“白字珊瑚按钮”**不采用**，改为珊瑚 Fill + `#4A1C14` 墨色字。

中性色（保留暖白背景，统一冷暖、修正层级倒挂）：textPrimary `#2E2A26`（背景上 13.3）、textSecondary `#625B53`（6.26）、textTertiary `#756D65`（4.76）；边框 `#ECE6DC`；卡片阴影只留 `0 1px 2px` 6% 暖黑。

原型对照：本地截图 `artifacts/evidence/UI-COLOR-HANDOFF/`（包括 `*-tuned.png`、`*-current.png` 和 `color-diagnosis.png`）。在线版本 [Beckon 首页原型](https://claude.ai/artifact/2C5StYqGPkT8jTSMR1BMTT) 需要登录，只有所有者能打开。

**D2 语义色和角色色拉开距离 —— 已确认（2026-10-17）**：状态色**永远不用角色色**。

| 角色 | 文字/图标（白底实测） | 浅底（文字压在上面的实测值） |
|---|---|---|
| success | `#276B2B`（6.51） | `#E6F2E6`（5.65） |
| warning / pending | `#8A5A00`（5.93） | `#FBF0D9`（5.24） |
| error | `#B3203F`（6.57；白字压在上面也是 6.57） | `#FBE8EC`（5.59） |
| info | `#2F5F8A`（6.72） | `#E7EFF7`（5.79） |
| neutral | textSecondary | borderSoft |

**D3 统一的状态映射表 —— 已确认（2026-10-17）**：新增一个状态展示的唯一来源（例如 `BeckonStatusPresentation`，按领域状态返回 tone、图标和文案），删除 `BeckonStatusChip.Tone` 里的 `.customer`/`.groomer`。建议映射：

| 领域状态 | Tone | 图标 |
|---|---|---|
| Request open / waiting | info | `clock` |
| Request hasOffers | warning（需要用户处理） | `tag` |
| Offer pending | warning | `clock` |
| Booking confirmed | info | `calendar.badge.checkmark` |
| Completed / accepted / booked | success | `checkmark.circle` |
| Declined / cancelled / expired | neutral（被动结束）；只有失败用 error | `xmark.circle` |

### 阶段 1：Token 重构（T-409 候选，只改 DesignSystem）

1. **三层结构**：`Palette`（原始色阶：teal 50–900、warm neutral 0–900、coral、green、amber、red、blue）→ `Colors`（语义角色）→ 组件内部使用。Feature 代码只能用语义角色。
2. **语义角色清单**：`appBackground`、`surface`、`surfaceSubtle`、`border`、`borderStrong`、`textPrimary/Secondary/Tertiary`、按角色提供 `{customer,groomer}{Fill,FillPressed,Ink,Deep,Tint}`（数值见 D1 色板），再加一层**角色解析**：用 `BeckonRole` 环境值把 `actionFill`/`actionInk`/`actionDeep`/`actionTint` 映射到当前角色，组件只读这层解析值，不在 Feature 里写 `role == .groomer ? … : …`；`actionSecondaryBorder`、`selectedBorder`、`focusRing`、`status{Success,Warning,Error,Info,Neutral}{Text,Fill,Border}`、`badge`、`brandHighlight`。
3. **暖灰中性色**（和暖白背景统一，修正层级倒挂）：textPrimary `#2E2A26`（13.3）、textSecondary `#625B53`（6.26）、textTertiary `#756D65`（白底 5.08 / 背景 4.76）。这三个都能在背景色上直接使用，可以删掉“secondary 不能放在背景上”这条特殊规则。
4. **透明度 token 化**：`tintSubtle`（≈0.08）、`tintSoft`（≈0.14）、`tintBorder`（≈0.32），或者直接预计算成不透明色。目标是把 59 种组合收敛到 ≤6 种。
5. **全部使用 sRGB**（或全部使用 P3），二选一；删除 `customerAccentSoft`/`Subtle` 这类重复项。
6. **设置 `AccentColor` 资源（用 Customer Deep `#1E6E5F` 作为登录前的默认值），角色外壳根视图设置 `.tint(当前角色的 Deep)`**（tint 会用到链接和光标上，所以必须用 Deep，不能用浅色 Fill），消除系统蓝。
7. **阴影只留一级**（卡片：`0 1px 2px` 6% 暖黑），删除彩色按钮光晕；主按钮改为**实色 Fill**，不再用渐变。
8. **圆角收敛到 4 级**：`card` 20/24、`control` 14/16（按钮和输入框统一）、`chip` Capsule、`sheet` 28；字面值全部映射到这几级。
9. **字体**：退役兼容名；新增 `meta = .footnote`，取代大部分 `caption`；`caption` 只用于徽标和角标。
10. **对比度单元测试**：遍历允许配对表，断言 ≥4.5 / 3.0。配对表由 token 自动生成，不再手写，防止文档和实现再次不一致。

### 阶段 2：修正原语（DesignSystem）

| 原语 | 改动 |
|---|---|
| `BeckonPrimaryButtonStyle` | 保留 `accent: .customer/.groomer` 参数（或改为读取角色环境值），填充 `{role}Fill` + `{role}Ink` 文字，不用渐变和光晕；按下态换成深一级颜色；禁用态 = surfaceSubtle + textTertiary（不再整体 opacity 0.64） |
| `BeckonSecondaryButtonStyle` | 白底 + `border` + `{role}Deep` 文字 |
| 新增 Tertiary/Link 样式 | `{role}Deep` 文字，替换所有裸 `Button`（修掉系统蓝和“Verify Address”的问题） |
| 破坏性按钮 | 白底 + error `#B3203F` 文字/边框 + 确认步骤，替换现在的红边卡片式“Sign Out”；两个角色都**不用**角色色表示破坏性操作 |
| `BeckonStatusChip` | 只保留语义 tone，由 D3 的映射表驱动 |
| `BeckonEmptyState` / Feedback toast | 图标用 `{role}Deep` 放在 `{role}Tint` 底块上；toast 放进 safe-area inset |
| 头像 / 宠物占位 | 统一中性暖灰底 `#F1ECE4` + SF Symbol，按物种只换图标、不换底色 |
| Tab 角标、通知角标 | 统一 `badge` token 和“99+”规则 |

### 阶段 3：文案与数据展示

- 新增统一的 `BeckonDateTimeFormatter`：区间合并显示（“Sep 19 · 10:00–11:00 AM”），只在时区和设备不一致时显示缩写；替换 §4 列出的 10 处调用。
- 模型层提供展示用兜底文案（`displayTitle`、`displayServiceName`、`displayLocation`），禁止在 UI 上显示 ID 和内部占位文字。
- 统一 **sentence case**（Apple HIG 推荐），按钮可以保留 Title Case。这条规则写进 `UX_RULES.md`，再统一扫一遍字符串。
- 修复复数（`MatchingEvidence.swift:18` 以及同类字符串）。

### 阶段 4：按页面迁移顺序

先改两个角色共用的页面，一次改动两边都受益：

1. **Bookings**（列表 + 详情 + 履约区块）和 **Chat**：去掉角色主题化，统一状态 chip。
2. **Customer**：Home（hero、宠物卡）→ Request Wizard（进度、选择卡、时间选择）→ Offers/Request Detail。
3. **Groomer**：Home（Needs attention 图标去掉多色）→ Requests/Offers（时间格式、无标题兜底、证据行颜色）→ Account（Sign Out 改样式）。
4. Auth 和其余编辑器页面。

每个页面的验收：默认字号 + AX3 截图对比、对比度表、VoiceOver 走查（沿用 A11Y-R10 的检查清单）。

### 阶段 5：治理门禁（`UI_CODE_GOVERNANCE` 新增规则）

- **UI012**：Feature 代码里出现 `Colors.<token>.opacity(` → 报错（只允许在 DesignSystem 内部）。
- **UI013**：`foregroundStyle` 或 `tint` 使用 `customerAccent`、`groomerAccent*`、`error`、`warning`、`success` 等填充色 → 报错。
- **UI014**：在 `BeckonStatusChip(` 调用处直接传 tone → 报错（必须经过状态映射表）。
- 裸 `Button(` / `Link(` 没有使用 Beckon 按钮样式：作为代码审查项，不另立规则。（注：UI009–UI011 已被键盘规则占用，新规则从 UI012 开始。）
- 允许配对表从 token 自动生成，并纳入对比度单元测试。

### 文档整理

- `design_tokens.json`：要么由 Swift 自动生成，要么冻结到 `09_frozen`，避免继续误导。
- `DESIGN_SYSTEM.md`：Visual Direction 保留“mint / coral 角色色”，补充 Fill / Ink / Deep / Tint 四种用法；记录 D1–D3 的 ADR（包括“白字实色”方案作废的修订记录）；写入 D1 的 10 条硬规则。
- `ACCESSIBILITY_RULES.md`：允许配对表改为自动生成，补上 action/link/status 三类配对。
- `GROOMER_UI_REDESIGN.md`：珊瑚 `#FF9A8B` 保持不变；`groomerOnAccent #642620` 改为 Ink `#4A1C14`，文字和链接场景用 Deep `#B23A2B`。approved 截图里的白字珊瑚按钮标注为“已被取代”。
- `ACCESSIBILITY_RULES.md`：保留“白字不能放在 mint/coral 上”的禁令；把 `textPrimary`/`groomerOnAccent` 配对替换为 Ink/Fill、Deep/白底、Deep/背景、Deep/Tint 四组配对；新增“禁止 accent.opacity() 叠在背景上”。
- `docs/ui-redesign/10-existing-visual-language-audit.md` 中“珊瑚不应形成第二品牌”的结论，在 ADR 里标注为：两套角色色保留（D1），用 Fill/Ink/Deep/Tint 的用法约束来避免珊瑚变成第二品牌。

---

## 6. 建议任务拆分（从 T-409 起，供 Codex 认领）

> 已被根目录 `UI_COLOR_IMPLEMENTATION_HANDOFF.md` 取代（7 个工作包 T-409～T-415，含逐包提示词）。下表仅保留为历史参考。

| ID | 内容 | 风险 | 依赖 |
|---|---|---|---|
| T-409 | ADR：D1（浅色主色 + 同色系深色字）+ D2–D3；配色样板（Customer/Groomer 主按钮、chip、选中卡在同一 Preview 里对照，并跑对比度测试） | 低 | 无（D1–D3 已确认） |
| T-410 | Token 三层化 + 暖灰中性色 + 透明度 token + AccentColor/tint + 对比度测试 | 中（全局视觉变化） | T-409 |
| T-411 | 按钮、Chip、EmptyState、Toast、占位图原语修正 + 状态映射表 | 中 | T-410 |
| T-412 | 日期时间格式化器 + 展示兜底文案 + 复数 + sentence case | 低 | 无（可以和 T-410 并行） |
| T-413 | Bookings + Chat 迁移 | 中 | T-411 |
| T-414 | Customer 主流程迁移 | 中 | T-411 |
| T-415 | Groomer 主流程迁移（包括复验本文标 ⚠ 的条目） | 中 | T-411 |
| T-416 | 治理规则 UI012–UI014 + 文档同步 | 低 | T-411 |

按“一个任务一个 session”的配额惯例：每个任务开一个 session，只在 T-411、T-415 两个节点跑完整回归。
