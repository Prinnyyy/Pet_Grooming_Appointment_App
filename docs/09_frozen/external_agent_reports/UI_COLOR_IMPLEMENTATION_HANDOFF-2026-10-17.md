# Beckon 配色与 UI 一致性实施交接文档（交给 Codex）

> **性质：外部交接草稿，不属于正式文档。** 按惯例放在仓库根目录、不纳入 Git；Codex 认领时先把本文件名和 `UI_UX_AUDIT_AND_OPTIMIZATION_PLAN.md` 加进 `.gitignore` 和 `.rgignore`，完成后归档到 `docs/09_frozen/external_agent_reports/`。
> 基线：`main` @ `e8c2d2b5`（T-408），2026-10-17。任务号以 `docs/00_memory/CURRENT_STATE.md` 为准（当前 `next_task_id` = T-409），下文 T-409～T-415 是预期编号，实际编号以分配时为准。
> 依据：根目录 `UI_UX_AUDIT_AND_OPTIMIZATION_PLAN.md`（审查报告），以及 §0.1 列出的**本地原型截图**。（Claude 原型链接需要登录，Codex 不要依赖它。）
> **决策权威：** 本文 §1 的配色、语义色和状态映射已在 2026-10-17 由用户确认（D1–D3）。Codex 实施时不需要重新讨论，但仍要遵守 `AGENTS.md` 和 `docs/05_workflow/DEVELOPMENT_GUIDE.md` 的全部规则。

---

## 0. 给 Codex 的总说明

- **目标：** 保留现有主色（Customer 薄荷、Groomer 珊瑚、暖白背景），修正配色的**用法**，同时统一状态色、按钮、浅底、文字层级和文案格式。不改产品流程、导航、数据模型和后端。
- **一个工作包对应一个任务号、一个 session。** 只在 T-410、T-414 和最终收尾时跑完整回归，其余工作包跑针对性验证（遵守“一个任务一个 session”的配额惯例）。
- **不做的事：** 不加依赖；不碰后端、迁移、RLS/RPC、Storage；不做 Dark Mode；不新增产品能力（例如收入统计、公共 Groomer 目录）；不改 `accessibilityIdentifier`（TestOps 依赖它们）；不改 Bundle、Scheme、签名。
### 0.1 视觉参考（本地截图，已忽略、不入库）

目录：`artifacts/evidence/UI-COLOR-HANDOFF/`（属于 `.gitignore` 里的 `artifacts/evidence/`）。全部是 @2x PNG，逻辑尺寸 390×1120pt；诊断表是 560×1120。

| 文件 | 内容 |
|---|---|
| `customer-home-tuned.png` | **Customer Home 目标效果**：Hero、宠物卡、Active request 卡片（三段进度、琥珀色 chip、Review 入口）、Tab 栏 |
| `groomer-home-tuned.png` | **Groomer Home 目标效果**：角色 chip、下一个预约卡、实色珊瑚按钮 + Ink 字、Needs attention 中性图标、营业状态、Tab 栏 |
| `customer-home-current.png` / `groomer-home-current.png` | 同一布局套用**当前**配色，用于对比；不代表 app 现在的真实布局 |
| `color-diagnosis.png` | 8 条配色问题的“当前 / 调整后”对照，以及调整后的色板 |

截图的使用边界：
- 截图来自 HTML 原型，**只作为配色和层级的参考**。字体是浏览器里的系统字体，不支持 Dynamic Type；宠物照片是占位图；布局细节（例如“Manage availability”换行）不是规格。
- **色值以 §1 为准。** 截图里的薄荷已经按 sRGB `#81D0C2` 系渲染，和 §1.1 一致。
- 实现时用 SwiftUI 原生组件和 `DesignTokens`，**不要照搬 HTML 或 CSS**，也不要按像素对齐截图。

- **执行顺序：**

```
T-409 Token 基础 ──► T-410 原语 ──► T-411 Feature 调用点迁移 ──► T-413 Customer 页面 ─┐
                                                          └──► T-414 Groomer 页面 ──┼──► T-415 门禁 + 收尾
T-412 文案与日期格式（不依赖其他工作包，可以穿插进行）──────────────────────────────────┘
```

---

## 1. 已确认的设计决策（实施输入）

### 1.1 角色色（D1：保留浅色主色 + 同色系深色字）

所有值都是 **sRGB**。现在的薄荷用 Display P3 定义，P3 `#93CEC2` 实际显示等于 sRGB `#81D0C2`。为了**不改变现有观感**，Fill 使用等价的 `#81D0C2`，其余薄荷色都按这个实际显示值推导。对比度均已实测。

| 新 Token | Customer 薄荷 | Groomer 珊瑚 | 用途 |
|---|---|---|---|
| `Fill` | `#81D0C2`（等于现在的 P3 `#93CEC2`） | `#FF9A8B`（不变） | 主按钮、Hero、强调面 |
| `FillPressed` | `#73BEB1` | `#FF8A79` | 按下态 |
| `Ink` | `#0F3D35`（压在 Fill 上 6.75 / 压在 Pressed 上 5.59） | `#4A1C14`（压在 Fill 上 6.98 / 压在 Pressed 上 6.24） | Fill 上的文字和图标 |
| `Deep` | `#1E6E5F`（白底 6.09 / 背景 5.69 / Tint 上 5.39） | `#B23A2B`（白底 5.94 / 背景 5.56 / Tint 上 5.25） | 链接、文字按钮、Tab 选中态、进度条、小号强调文字、控件 tint |
| `Tint` | `#E3F5F2` | `#FFEDE9` | 选中底、图标底块、Tab 选中底（**实色，不用 opacity**） |
| Hero 辅助色（仅 Customer） | 渐变终点 `#A4DDD3`、气泡 `#BAE5DD`、爪印 `#6CB6A9` | — | 同色相，替代偏灰青的 `#B0D8D9`/`#B5DCD9` 和冷灰爪印 `#515555` |

### 1.2 中性色

| Token | 新值 | 旧值 | 说明 |
|---|---|---|---|
| appBackground | `#FAF7F2` | 不变 | |
| surface | `#FFFFFF` | 不变 | |
| textPrimary | `#2E2A26` | `#333333` | 暖黑，背景上 13.3 |
| textSecondary | `#625B53` | `#6F767E` | 暖灰，背景上 6.26（可以直接放在背景上） |
| textTertiary | `#756D65` | `#69717A` | 比 secondary 浅，修正原来的层级倒挂；背景上 4.76、白底 5.08 |
| border | `#E8E2D8` | 不变 | |
| borderSoft / divider | `#ECE6DC` | `#EFEAE1` | |
| placeholderFill | `#F1ECE4` | 新增 | 宠物、头像、照片的占位底色 |
| iconTileFill | `#F3EEE7` | 新增 | 列表行图标的中性底块 |

### 1.3 语义色（D2）

| 角色 | Text / Icon | Fill（浅底） | Border |
|---|---|---|---|
| success | `#276B2B` | `#E6F2E6` | `#CFE5CF` |
| warning | `#8A5A00` | `#FBF0D9` | `#F2DFB5` |
| error | `#B3203F` | `#FBE8EC` | `#F0C9D1` |
| info | `#2F5F8A` | `#E7EFF7` | `#CFDDEC` |
| neutral | textSecondary | `#F3EEE7` | border |

另有两个专用色：
- `ratingStar` = `#F2B84B`，只用于星级图标，不承载文字。
- `unreadDot` = error `#B3203F`。

**数量角标**统一用角色色：Customer 用 Tint + Deep，Groomer 用 Tint + Deep；需要更强调时用 Fill + Ink。**不再使用系统红 `#FF3B30`。**

### 1.4 配色硬规则

1. 角色色只表示“可点击 / 已选中 / 当前角色”，不用于状态 chip、错误提示和通知圆点。
2. Fill 上一律用同色系的 Ink：**不用白字**，也不用中性灰或旧的棕色 `#642620`。
3. 浅色 Fill 不能当文字、细线、进度条或控件 tint，这些地方一律用 Deep。
4. 禁止把 `accent.opacity(x)` 叠在背景上，浅底一律用预混好的实色 Tint。
5. Groomer 的 Deep `#B23A2B` 和 error 红亮度几乎一样（1.11:1）。所以 Deep 只用于可点击元素（带 › 或按钮形态）和选中态；错误提示永远是“error 色 + 感叹号图标 + 错误容器”。破坏性操作用白底 + error 文字和边框，**两个角色都不用角色色**。
6. success 永远搭配对勾图标；状态任何时候都不能只靠颜色表达。
7. 共享页面（Bookings、Chat）只有按钮和链接随角色换色；状态 chip、卡片、分组和排版完全一致。
8. 按钮不用渐变，也不用彩色光晕；只有 Customer Hero 可以保留同色相的轻渐变。
9. 整个 app 只用一档卡片阴影：`0 1px 2px` 6% 暖黑（`#2E2A26`），层次主要靠边框表达。
10. 占位图用中性底色加 SF Symbol，按物种只换图标，不换底色；列表行图标统一用 Ink 色或 textPrimary，放在中性底块上，不再用绿、黄、蓝多色。

### 1.5 状态映射表（D3）

新增唯一的状态展示来源，建议命名 `BeckonStatusPresentation`，放在 `SharedFeatures/Status/`。原因是它需要认识领域状态，而 DesignSystem 不能依赖业务。它为每个领域状态返回 `tone`、SF Symbol 和文案。`BeckonStatusChip.Tone` 删除 `.customer` 和 `.groomer`，只保留语义 tone。

| 领域状态 | Tone | 图标 |
|---|---|---|
| Request open / waiting | info | `clock` |
| Request hasOffers | warning | `tag` |
| Request booked | success | `checkmark.circle` |
| Request cancelled / expired | neutral | `xmark.circle` / `hourglass` |
| Offer pending | warning | `clock` |
| Offer acceptedByCustomer | success | `checkmark.circle` |
| Offer declined / withdrawn / expired | neutral | `xmark.circle` / `arrow.uturn.backward` / `hourglass` |
| Match new / open for offers | info | `sparkles` |
| Booking confirmed | info | `calendar.badge.checkmark` |
| Booking completed | success | `checkmark.circle` |
| Booking unfulfilled | neutral | `minus.circle` |
| Booking cancelledByCustomer / ByGroomer | neutral | `xmark.circle` |
| 操作失败（非领域状态） | error | `exclamationmark.triangle` |

**两个角色看到的同一状态必须完全一致**，包括颜色、图标和文案。需要替换的现有映射：
- `Features/Bookings/BookingsView.swift:1812` `chipTone(for:)`
- `Features/Customer/Requests/CustomerRequestDetailView.swift:986`、`:1295`、`:1325`
- `Features/Customer/Requests/CustomerRequestsDashboardView.swift:1354`
- `Features/Groomer/Offers/GroomerOffersView.swift:500`
- `Features/Groomer/Requests/GroomerRequestsView.swift:468`、`:1417`、`:1433`
- `Features/Chat/ChatView.swift:971`
- `Features/Auth/AuthenticatedAccountView.swift:283`（账户状态如果不是领域状态，就用 neutral 或 info）

---

## 2. 全局约束与验证

| 项目 | 要求 |
|---|---|
| 分层 | 视觉 token 和原语放 `DesignSystem/`；领域状态映射放 `SharedFeatures/`；Feature 只组合，不新增本地视觉样式 |
| 兼容 | T-409 保留旧 token 名作为过渡别名（见 T-409），T-411 迁移完调用点后删除；旧名字删除前，审计和测试都要通过 |
| TestOps | 不改、不删任何 `accessibilityIdentifier`；语义变化（例如 chip 文案）需要同步更新依赖它的选择器和测试 |
| 无障碍 | 每个视觉改动都遵守 `ACCESSIBILITY_RULES.md`：AX3 不截断、不重叠，触控区域 ≥44pt，有 VoiceOver 标签，状态不只靠颜色 |
| 文档 | 文档只描述已落地的实现；token 值和配对表的唯一来源是 Swift 和测试 |
| 验证命令 | `./scripts/ios-build.sh`、`./scripts/ios-test.sh`（完整回归）、`node scripts/ui-consistency-audit.mjs check`、`node scripts/ui-consistency-audit.mjs strict <迁移文件>`、`./scripts/preflight.sh`、`node scripts/context-hygiene-check.mjs`（改了文档时运行） |
| 视觉证据 | Simulator 截图，默认字号和 AX3 各一张，放在 ignored 的 `artifacts/evidence/<T-ID>/`。**很多页面要先有对应数据才会出现**：优先用 Preview fixture 或已有的 TestOps 截图；需要真实数据时，走 TestOps 种子账号和生命周期场景，远程写入要按规则单独授权 |
| 提交 | 每个工作包验收通过后，提交信息格式为 `T-###: <type>: <summary>`，只推送当前工作分支 |

---

## 3. 工作包

### T-409 Token 基础 + ADR + 核心文档（只改 DesignSystem 和文档）

**目标：** 落地 §1.1–§1.3 的 token。这一步**只换值、不改结构**，让全 app 立刻获得大部分配色改善，不碰任何 Feature 文件。

**改动：**
1. `DesignSystem/DesignTokens.swift`：
   - 新增原始色板 `Palette`：mint / coral 的 fill、pressed、ink、deep、tint、hero，warm neutral，以及 status 各色。全部 sRGB，删除 `DisplayP3Hex` 和 `Color(displayP3Hex:)`。
   - `Colors` 新增语义角色：`customerFill`、`customerFillPressed`、`customerInk`、`customerDeep`、`customerTint`、`customerHeroEnd`、`customerHeroBubble`、`customerHeroDecoration`，`groomer` 同名一套；`status{Success,Warning,Error,Info,Neutral}{Text,Fill,Border}`、`ratingStar`、`unreadDot`、`placeholderFill`、`iconTileFill`。
   - **旧名字改成指向新值的过渡别名，过渡期观感必须正确：**

     | 旧名 | 新指向 |
     |---|---|
     | `customerAccent` / `customerPrimary` | customerFill |
     | `customerAccentSoft` / `customerHeroBackgroundEnd` | customerHeroEnd |
     | `customerAccentSubtle` / `customerHeroBubble` | customerHeroBubble |
     | `customerAccentStrong` / `customerPrimaryDark` / `customerPrimaryPressed` | customerDeep |
     | `customerOnAccent` / `customerHeroText` | customerInk |
     | `customerHeroDecoration` | 新爪印色 |
     | `groomerOnAccent` | groomerInk |
     | `textPrimary` / `textSecondary` / `textTertiary` / `borderSoft` | §1.2 新值 |
     | `successText` / `warningText` / `errorText` | §1.3 Text 值 |

   - **以下旧名在 T-409 保持原值不动**（它们在 T-410/T-411 才会被替换，现在改会让过渡期变难看）：`groomerAccentDark`（按钮渐变终点）、`success`/`warning`/`error`（旧填充色，有图标和背景用途）、`notificationUnread`。
   - `Shadows`：`softCard` 改为 `0 1px 2px` 6% `#2E2A26`；`primaryAction` / `groomerAction` 暂时保留，T-410 删除。
2. `Assets.xcassets/AccentColor.colorset`：设为 customerDeep `#1E6E5F`。Customer 和 Groomer 的根外壳分别设置 `.tint(customerDeep / groomerDeep)`。这样可以消除系统蓝（例如 `Features/Bookings/BookingFulfillmentSection.swift:69` 的“Refresh Outcome”）。根外壳文件在 `Features/Customer/CustomerTabView.swift`、`Features/Groomer/GroomerTabView.swift`，这一行属于全局 tint，可以接受。
3. `BeckonTests/DesignTokenAccessibilityTests.swift`：把固定色值断言更新为新值；新增配对测试，至少覆盖：
   - Ink / Fill、Ink / FillPressed：≥4.5
   - Deep / surface、Deep / appBackground、Deep / Tint：≥4.5
   - 每个 status Text / surface 和 Text / Fill：≥4.5
   - text 三档在 surface 和 appBackground 上：≥4.5，且 tertiary 的亮度高于 secondary
   - 禁止的配对断言：白色 / customerFill <3，白色 / groomerFill <3
   - `DesignSystemContractTests.swift:101` 引用了 `customerPrimaryDark`，同步检查。
4. 文档：
   - `docs/07_decisions/DECISION_LOG.md` 新增 ADR，内容为 D1–D3。修订记录写明：“白字实色方案作废；`10-existing-visual-language-audit.md` 中‘珊瑚不应成为第二品牌’的结论，由 Fill/Ink/Deep/Tint 的用法约束来满足。”
   - `docs/01_product/DESIGN_SYSTEM.md`：Visual Direction 补充 Fill / Ink / Deep / Tint 四种用法和 §1.4 的硬规则。
   - `docs/01_product/ACCESSIBILITY_RULES.md`：允许配对表改成新值，禁止配对里加上“`accent.opacity()` 叠在背景上”。
   - `docs/08_design/GROOMER_UI_REDESIGN.md`：`groomerOnAccent #642620` 改为 Ink `#4A1C14`，文字和链接用 Deep；approved 截图里的白字珊瑚按钮标注为“已被取代”。
   - `docs/08_design/design_tokens.json`：冻结到 `docs/09_frozen/design_notes/`，原位置在路由文档里改指向 Swift。

**验收：**
- build 通过；`DesignTokenAccessibilityTests` 和 `DesignSystemContractTests` 通过；UI 审计 `check` 没有新增错误。
- context-hygiene 通过。
- Simulator 截 Customer Home 和 Groomer Home：薄荷观感与改前一致，文字变暖，链接和 Tab 选中态变成 Deep，没有出现系统蓝。

**Codex 提示词：**
```
按根目录 UI_COLOR_IMPLEMENTATION_HANDOFF.md 的 §1 和 T-409 执行。只改 DesignSystem、AccentColor 资源、两个根 TabView 的全局 tint、DesignToken 相关测试和列出的文档，不改其他 Feature 文件。先把本交接文档和 UI_UX_AUDIT_AND_OPTIMIZATION_PLAN.md 加进 .gitignore 和 .rgignore。旧 token 名按表格改为过渡别名；groomerAccentDark、success、warning、error、notificationUnread 本轮保持原值。验收：ios-build、相关单元测试、ui-consistency-audit check、context-hygiene-check，以及 Customer/Groomer Home 默认字号截图。完成后按 T-###: feat: 提交。
```

---

### T-410 DesignSystem 原语（按钮、Chip、反馈、占位、Tab 角标）

**目标：** 把 §1.4 的规则落实到共享组件里，并建立状态映射的唯一来源。

**改动：**

| 原语 | 改动 |
|---|---|
| `BeckonPrimaryButtonStyle`（`BeckonActionPrimitives.swift`） | 实色 `Fill` + `Ink` 文字；按下态用 `FillPressed`，删除反转渐变和 `scaleEffect` 以外的动效；**删除彩色阴影**；禁用态用 `iconTileFill` 底 + textTertiary 文字，不再整体 opacity 0.64。`accent` 参数保留 |
| `BeckonSecondaryButtonStyle` | 白底 + border + `Deep` 文字；选中态边框用 Deep，不再用 Fill |
| 新增 `BeckonTertiaryButtonStyle`（链接或文字按钮） | `Deep` 文字，最小触控 44pt，带角色参数 |
| 新增 `BeckonDestructiveButtonStyle` | 白底 + error Border + error Text；两个角色共用 |
| `BeckonStatusChip` | `Tone` 只保留 `neutral/success/warning/error/info`；颜色取自 §1.3 的 Text / Fill / Border 三件套 |
| 新增 `SharedFeatures/Status/BeckonStatusPresentation.swift` | 实现 §1.5 映射表，由 extension 接收各领域状态枚举；附单元测试，覆盖每个状态的 tone、图标和文案 |
| `BeckonEmptyState`、`BeckonLoadingView`、错误卡片（`BeckonFeedbackPrimitives.swift`） | 图标用 Deep 放在 Tint 底块上；错误类用 error Text + Fill，替换 `error.opacity(0.12/0.28)` 和 `groomerAccentDark` 前景；成功 toast 用 success Text 底 + 白色对勾（6.51） |
| `BeckonModuleImage` 及头像、宠物占位 | 占位底色统一为 `placeholderFill`，图标 textTertiary；删除按物种配底色的逻辑（保留按物种换图标） |
| 选择类原语（`BeckonSelectionPrimitives.swift`） | 选中底用 Tint、选中边框用 Deep、勾选图标用 Deep；替换所有 `accent.opacity(x)` |
| Tab 角标、通知圆点 | 数量角标统一 token（角色 Tint + Deep），超过 99 显示“99+”；未读圆点用 `unreadDot` |
| `Shadows` | 删除 `primaryAction` 和 `groomerAction`；`beckonShadow` 只保留卡片一档 |
| `BeckonComponentCatalog.swift` | 增加一页对照：两个角色的主、次、文字、破坏性按钮，加上全部状态 chip，默认字号和 AX3 两个 Preview |

完成后删除过渡期旧值：`groomerAccentDark`；把 `success`/`warning`/`error` 旧填充色的 DesignSystem 内部调用点改到新角色。Feature 里剩下的调用点留给 T-411。

**验收：**
- 完整回归 `./scripts/ios-test.sh` 通过；`ui-consistency-audit check` 没有新增错误。
- Catalog 截图（默认字号和 AX3）；Customer/Groomer Home、Request Wizard 底部按钮截图。

**Codex 提示词：**
```
按 UI_COLOR_IMPLEMENTATION_HANDOFF.md 的 T-410 执行，依赖 T-409 已完成。修改 DesignSystem 原语，新增 SharedFeatures/Status/BeckonStatusPresentation（附单元测试）和 Tertiary、Destructive 按钮样式；BeckonStatusChip 删除 .customer/.groomer tone。Feature 里传 .customer/.groomer tone 的调用点，只做让它编译通过的最小改动（临时映射到 info），完整迁移留给 T-411。删除彩色阴影和 groomerAccentDark。验收：完整 ios-test、审计 check，以及 Catalog 默认字号和 AX3 截图。
```

---

### T-411 Feature 调用点迁移（颜色）

**目标：** 清掉 Feature 里的配色违规，然后删除全部过渡别名。

**改动清单**（数字是 2026-10-17 的统计，Codex 开工前重新 grep 一次）：
1. **透明度叠加**：Feature 和 SharedFeatures 里共有 114 处 `opacity(`，其中 59 种“颜色 token + 透明度”组合。逐个替换：
   - 浅底改用 `Tint`、status `Fill` 或 `iconTileFill`；
   - 边框改用 border、Deep 或 status `Border`；
   - 遮罩、玻璃之类的白色透明保留，但要换成 DesignSystem 的命名 token。
2. **浅色填充色当文字或 tint**：
   - `SharedFeatures/Address/BeckonAddressEditor.swift:268`（customerAccent 文字）→ Tertiary 按钮样式；
   - `.tint(groomerAccent)` 9 处、`.tint(groomerAccentDark)` 4 处、`.tint(customerAccent)` 4 处 → Deep；
   - `error` 当正文（`CustomerRequestsView.swift:309`、`AuthenticatedAccountView.swift:224/230` 等）→ error Text。
3. **状态 tone**：§1.5 列出的 10 处映射全部改为调用 `BeckonStatusPresentation`，删除各 Feature 里的 `xxxTone` 扩展。
4. **系统蓝**：没设样式的裸 `Button` 和 `Link` 改用 Tertiary 样式。可以用 `grep -rn 'Button("' Features | grep -v buttonStyle` 粗筛，人工确认。
5. **多色图标**：Groomer Home 的“Needs attention”去掉绿、黄、蓝底块，改为 `iconTileFill` + textPrimary 图标；宠物卡和请求卡里按物种配的黄、粉底色改为 `placeholderFill`。
6. **emoji**：Customer Hero 的剪刀 emoji 换成 SF Symbol `scissors`，颜色 customerDeep；宠物占位的 emoji 换成 SF Symbol（`pawprint.fill`、`cat.fill`、`dog.fill` 等，按物种选）。
7. 删除全部过渡别名，以及旧的 `success`/`warning`/`error`/`notificationUnread`，编译通过即证明没有遗漏。

**验收：**
- `grep -rnE 'Colors\.[a-zA-Z]+\.opacity\(' Features SharedFeatures` 结果为 0。
- `grep -rnE '(foregroundStyle|foregroundColor|tint)\((DesignTokens\.Colors\.)?(customerFill|groomerFill|customerAccent|groomerAccent)' Features SharedFeatures` 结果为 0。
- 完整回归通过；审计 `check` 没有新增错误，并用 `baseline prune` 清掉迁移掉的旧债。
- Bookings、Offers、Requests 各截一张，确认两个角色的状态 chip 完全一致。

**Codex 提示词：**
```
按 UI_COLOR_IMPLEMENTATION_HANDOFF.md 的 T-411 执行，依赖 T-410。先重新 grep 统计 opacity 和 tint 的调用点，再按清单 1–7 迁移，最后删除过渡别名和旧状态填充色。只改颜色、tone、按钮样式和占位图；布局改动留给 T-413/T-414。不改 accessibilityIdentifier。验收：两条 grep 结果为 0、完整 ios-test、审计 check + baseline prune（写明 reason），以及双角色状态 chip 截图。
```

---

### T-412 文案与日期格式（不依赖其他工作包）

**改动：**
1. 新增 `Core/Formatting/BeckonDateTimeFormatter`（或者放在现有 Core 格式化位置）：
   - 区间合并显示，例如 `Sat, Oct 25 · 10:00–11:00 AM`；
   - 只在服务时区和设备时区不同时，追加时区缩写（例如 `PDT`）；完整时区 ID 只放进 VoiceOver 标签和详情页。
   - 需要替换的调用点：`Core/Models/CustomerRequest.swift:351-359`（`displayString`，7 处调用）、`GroomerRequestsView.swift:1029`、`CustomerRequestWizardView.swift:708`、`BookingsView.swift:264`。
   - 时区未确认时，显示“Time zone not confirmed”的提示行，不再把原始字符串和 `(service time zone unconfirmed)` 拼在一起。
   - 必须覆盖跨时区、DST 交界、跨午夜区间的单元测试。
2. 展示兜底文案：模型或 presentation 层提供 `displayTitle`、`displayServiceName`、`displayLocation`。UI 上不再出现“Service Details”“Location Details”“Customer ref …”这类占位文字，也不再出现“…”这种空标题；没有标题时显示“宠物名 · 服务名”。
3. 复数：`Core/Models/MatchingEvidence.swift:18` 以及同类字符串，改用 `String(localized:)` 的 inflection 或显式单复数分支，并补测试。
4. 大小写：标题、标签、说明文字统一用 sentence case（例如 “Welcome back”“Who needs grooming?”“I'm flexible with time”）；按钮可以保留 Title Case。把这条规则写进 `docs/01_product/UX_RULES.md` 的 Copy 小节，然后统一扫一遍字符串。如果 TestOps 依赖可见文案，同步更新。

**验收：** 格式化和复数的单元测试通过；build 通过；涉及选择器的 UI 测试通过；时间显示截图（Offers、Groomer Requests）。

**Codex 提示词：**
```
按 UI_COLOR_IMPLEMENTATION_HANDOFF.md 的 T-412 执行。新增统一的日期时间格式化器并替换列出的调用点；提供展示兜底文案；修复复数；按 sentence case 规则统一 UI 字符串并写进 UX_RULES。不改数据模型的存储字段，也不改后端。验收：新单元测试（含 DST 和跨时区）、ios-build、受影响的 UI 测试，以及 Offers 和 Groomer Requests 截图。
```

---

### T-413 Customer 页面（Home 优先）

**目标：** 按 `customer-home-tuned.png` 调整 Customer 主流程，重点是 Home。

**改动：**
1. **Hero**（`Features/Customer/Pets/CustomerPetsView.swift`）：渐变从 customerFill 到 customerHeroEnd，气泡用 customerHeroBubble，爪印用 customerHeroDecoration；标题和正文用 customerInk；白色胶囊按钮里的文字用 customerInk，图标用 customerDeep。
2. **宠物卡**：照片位用 `placeholderFill`，元信息合成一行（`4 years old · 9 lb · XS`），用 textTertiary。
3. **Active request 卡片**（`CustomerRequestActionCardSummary`，`CustomerRequestsDashboardView.swift:402`）按 `customer-home-tuned.png` 重做：
   - 第一行：宠物头像（圆形，Tint 底、Deep 首字母或照片），标题“服务 · 宠物名”，下面一行用 T-412 的格式化器显示时间。
   - **三段进度条**：open → 第 1 段完成；hasOffers → 第 1、2 段完成；booked 或 booking handoff → 3 段全部完成。已完成段用 customerDeep，未完成段用 borderSoft；下面三个标签 Posted / Offers / Booked，当前步骤用 textPrimary、已完成的用 textSecondary、未开始的用 textTertiary。cancelled 或 expired 时不显示进度条，只显示 neutral chip。整条进度条作为一个无障碍元素，例如“Step 2 of 3: offers received”。
   - **状态 chip**：来自 `BeckonStatusPresentation`。hasOffers 时文案为“N offers to review”。数量只能取 Store 里已加载的数据（`CustomerRequestsStore` 的 `offerReviewsByRequestID`），**不新增网络请求**；没加载到时显示“Offers ready to review”。
   - **右侧“Review ›”入口**：用 Tertiary 样式，目标和点卡片相同。卡片本身已经是可点击行，所以要遵守 T-399 的规则：一行里有多个控件时，用显式按钮样式避免误触；或者把整行改成单一点击目标，把“Review”作为视觉提示加进无障碍标签。二选一，在 PR 说明里写明理由。
4. **Request Wizard**：进度条、选中卡和底部按钮会随 T-410 原语自动更新。这里只检查“Step 1 of 5”的文字色是否为 Deep、时间选择器是否浮在表单上。浮层问题如果需要改交互，记为后续任务，不在本包处理。
5. **Offers / Request Detail**：确认状态 chip 和时间格式正确；删除重复的页面标题（导航标题加大号标题“Offers”只保留一个）。

**验收：** 迁移文件的 `ui-consistency-audit strict` 不新增错误；Home 截图（有请求和无请求两种状态，加 AX3）；VoiceOver 读进度条和 Review 入口。依赖数据的状态用 Preview fixture 覆盖，至少包括 open、hasOffers（有数量和无数量）、booked、cancelled。

**Codex 提示词：**
```
按 UI_COLOR_IMPLEMENTATION_HANDOFF.md 的 T-413 执行，依赖 T-410、T-411、T-412。参照 artifacts/evidence/UI-COLOR-HANDOFF/customer-home-tuned.png 调整 Customer Home 的 Hero、宠物卡和 Active request 卡片（三段进度、chip、Review 入口），不新增网络请求和导航。为卡片补齐各状态的 Preview fixture。验收：strict 审计、默认字号和 AX3 截图、VoiceOver 标签检查、相关 UI 测试。
```

---

### T-414 Groomer 页面

**改动：**
1. **Home**（`Features/Groomer/Home/GroomerHomeView.swift`，债务最集中的文件）：
   - 角色 chip 用 groomerTint + groomerDeep。
   - “View booking”用 Primary 样式（实色珊瑚 + Ink 字），删除光晕和渐变。
   - 下一个预约卡片里的图标用 textTertiary，不用珊瑚。
   - “Needs attention”行：中性图标底块，数量角标用统一 token。
   - 营业状态：success 圆点 + “Available”文字；“Manage availability”用 Tertiary 样式（Deep）。
2. **Requests / Offers**：
   - 证据行的珊瑚小字（例如“1000 related reviews…”）改为 textSecondary，或者改成带图标的 info 样式；
   - 行内“New · Fit evidence available”标签改为 info chip；
   - 顶部工具栏图标用 textPrimary，放在中性胶囊上。
   - 截图里标了 ⚠ 的问题（拍于 T-402 之前），先复验是否还存在。
3. **Account**：Sign Out 改用 Destructive 样式。
4. **Schedule / Messages**：只核对它们随原语自动更新后的结果，不做布局改动。

**验收：** 完整回归；Home、Requests、Account 三张截图（默认字号和 AX3），对照 `groomer_ui_redesign/approved/` 的布局，只允许颜色不同；VoiceOver 和 44pt 触控区域检查。

**Codex 提示词：**
```
按 UI_COLOR_IMPLEMENTATION_HANDOFF.md 的 T-414 执行，依赖 T-410、T-411。调整 Groomer Home、Requests/Offers 和 Account 的颜色与组件用法，配色参照 artifacts/evidence/UI-COLOR-HANDOFF/groomer-home-tuned.png，布局沿用 approved 截图，不加收入或统计类新信息。先复验审查报告里标 ⚠ 的条目。验收：完整 ios-test、三页默认字号和 AX3 截图、VoiceOver 与触控区域检查。
```

---

### T-415 治理门禁 + 收尾

**改动：**
1. 在 `scripts/ui-consistency-audit-core.mjs` 新增三条规则。**注意：UI009–UI011 已经被键盘规则占用**，新规则从 UI012 开始：
   - **UI012**（error）：Feature 里出现 `Colors.<token>.opacity(`。
   - **UI013**（error）：`foregroundStyle`、`foregroundColor` 或 `tint` 使用角色 Fill，或旧的状态填充色。
   - **UI014**（error）：Feature 里直接写 `BeckonStatusChip(… tone:`（必须经过 `BeckonStatusPresentation`）。
   - 三条规则都要在 `tests/ui-consistency-audit.test.mjs` 补正例和反例。T-411 之后这三条应该是零命中；如果有剩余，先修代码，**不要把它们加进 baseline**。
2. 更新 `docs/04_ios/UI_CODE_GOVERNANCE.md` 的规则表，以及 `docs/04_ios/UI_CONSISTENCY_DEBT.md` 的当前统计。
3. 最终验收：`./scripts/preflight.sh`、完整 `./scripts/ios-test.sh`、`node scripts/context-hygiene-check.mjs --full`。
4. 把本交接文档和审查报告归档到 `docs/09_frozen/external_agent_reports/`（文件名加日期后缀）。

**Codex 提示词：**
```
按 UI_COLOR_IMPLEMENTATION_HANDOFF.md 的 T-415 执行。新增审计规则 UI012–UI014（UI009–UI011 已被占用），附正反例测试，要求零命中且不进 baseline；更新治理文档和债务统计；运行 preflight、完整 ios-test 和 context-hygiene --full；最后归档两份外部草稿。
```

---

## 4. 已知风险与处理

| 风险 | 处理 |
|---|---|
| P3 改成 sRGB 后薄荷观感变化 | 已用等价值 `#81D0C2`；T-409 截图对比改前改后 |
| Groomer Deep 和 error 红相近 | 遵守 §1.4 第 5 条；T-414 截图时重点检查“Deep 链接”和“错误提示”同时出现的页面 |
| chip 文案统一后 TestOps 选择器失效 | 选择器以 identifier 为准；依赖可见文案的测试同步更新，并在提交说明里列出 |
| T-411 改动面大 | 只改颜色、tone 和样式，不动布局；按 Feature 目录分批编译，最后跑一次完整回归 |
| 依赖数据的页面难以截图 | 用 Preview fixture 状态矩阵；需要真实数据时走 TestOps 场景，远程写入要单独授权 |
| 审计 baseline | 只用 `prune` / `relocate` 并写明 reason，不手改 JSON；新规则不进 baseline |

## 5. 完成定义（整体）

- §1 的全部 token 在 Swift 中落地，有测试保护；旧 token 和过渡别名全部删除。
- 两个角色看到的同一状态，颜色、图标和文案完全一致。
- Feature 里没有透明度叠色、浅色填充当文字或 tint、系统蓝、彩色光晕、渐变按钮、多色图标或 emoji 占位。
- 时间显示里没有时区 ID 长串；没有占位文字外露；复数和大小写一致。
- Customer 和 Groomer Home 与 `customer-home-tuned.png` / `groomer-home-tuned.png` 在配色和层级上一致；Active request 卡片按 T-413 规格实现。
- preflight、完整回归、审计、hygiene 全部通过；默认字号和 AX3 截图证据齐全。
