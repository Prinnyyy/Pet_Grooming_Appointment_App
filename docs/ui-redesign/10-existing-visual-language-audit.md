# Beckon Existing Visual Language Audit

## 审计方法

本审计结合生产 SwiftUI、`DesignTokens.swift`、Asset Catalog 和 iPhone 17 Pro Max Simulator（iOS 26.5）真实运行截图。Preview 仅用于定位代码，不作为视觉事实。目标不是复制固定尺寸，而是从现有最佳客户侧 UI 建立 **Beckon Warm Utility System**。

## Canonical Screens

| Surface | 页面 | SwiftUI 类型与路径 | 主要组件 | 选择原因 | 保留 | 规范化 | 禁止进入系统 |
|---|---|---|---|---|---|---|---|
| Brand | Auth Landing | `AuthenticationView` — `ios/Beckon/Beckon/Features/Auth/AuthenticationView.swift` | 品牌 hero、emoji、装饰圆、渐变主按钮 | 实机首屏最完整体现 Beckon 品牌 | 暖白、薄荷、圆形宠物焦点、克制装饰、友好文案 | 字体改为可缩放品牌层级；按钮统一 API | 46pt/62pt 固定字号、固定 offset、`minimumScaleFactor` 兜底 |
| Customer | Home | `CustomerPetsView` — `Features/Customer/Pets/CustomerPetsView.swift` | greeting、hero、宠物卡、request card、floating tab | 品牌识别最强且覆盖卡片/照片/CTA/状态 | 暖白、薄荷渐变、大圆角、照片、对象级卡片 | 页面/卡片间距、标题层级、长名称、底部安全区 | 172×252 固定卡、装饰 offset、每处独立字号 |
| Customer | Grooming Request | `CustomerRequestWizardView` — `Features/Customer/Requests/CustomerRequestWizardView.swift` | 多步进度、选择卡、底部 action area | 代表核心高价值表单与 Sheet | 清晰步骤、薄荷选中态、实体表面、底部操作 | 步骤在大字号下重排、选择卡自适应、统一 action area | 五个固定宽度文字标签、固定高度承载内容 |
| Customer | Bookings | `BookingsView(role: .customer)` — `Features/Bookings/BookingsView.swift` | scope control、booking row、status badge、tab | 中等密度、快速扫描最成熟 | 暖白、紧凑对象卡、状态小面积表达 | 宠物/服务信息优先级、长 groomer 名、row 自增长 | 固定单行 + scale factor 作为无障碍策略 |
| Groomer | Home | `GroomerHomeView` — `Features/Groomer/Home/GroomerHomeView.swift` | header、attention rows、availability | Groomer 当前最完整运营 dashboard | 同源暖白/白 surface/圆角、attention 分组 | 降低装饰、稳定时间/状态/快捷操作层级 | 与 Customer 完全不同的产品语言、硬编码 badge offset |
| Groomer | Schedule | `BookingsView(role: .groomer)` — `Features/Bookings/BookingsView.swift` | day strip、summary、timeline、empty state | 运营信息密度和日期扫描的代表 | 日期优先、紧凑日条、同源 surface | 大字号时横向日条替代布局、64×78 固定日卡适配 | 24pt 固定日期字号、`minimumScaleFactor` 保布局 |

实机截图路径为本次临时验证产物，不提交仓库：Auth landing、Customer Home、Request Wizard、Customer Bookings、Groomer Home、Groomer Schedule 均由运行中的 `com.hellobeckon.beckon` 捕获。

## Color

来源：`DesignTokens.ColorHex`。Asset Catalog 的 `AccentColor` 未定义实际颜色，不作为来源。

| 语义 | 当前值 | 审计结论 |
|---|---:|---|
| App Background | `#FAF7F2` | 品牌核心，保留为暖白 background |
| Surface | `#FFFFFF` | 保留；用于完整业务对象和表单面板 |
| Border / Soft | `#E8E2D8` / `#EFEAE1` | 合并为 default/subtle 层级 |
| Text Primary | `#232323` | 保留高可读暖黑 |
| Text Secondary / Tertiary | `#6F767E` / `#69717A` | 数值过近，规范为两个有明确用途的层级 |
| Customer Primary | `#7ECFC0` | Beckon 主品牌薄荷，保留 |
| Customer Primary Dark | `#5FBFAE` | 用于交互/强调；需验证文字对比 |
| Groomer Accent | `#FF9A8B` / `#F58575` | 可作为辅助运营 accent，不应形成第二套产品品牌 |
| Success / Warning / Error | `#6CBF84` / `#F2B84B` / `#E56B6F` | 保留语义；必须配文字/图标 |

Figma Phase 1 的深青 primary 是早期通用探索，与 canonical Customer UI 不一致，需在批准后将 primitive/semantic alias 校准为薄荷体系；SwiftUI 仍应映射系统语义背景/文字而非机械输出 Hex。

## Typography

| 角色 | 当前用法 | 问题 | 规范建议 |
|---|---|---|---|
| Screen Title | `.largeTitle/.title` bold；局部 42/46pt rounded | 同角色多尺度，Brand 固定字号过大 | Brand 可有独立 display；Customer/Groomer 使用语义 Large Title/Title 1 |
| Section Title | `.title2/.title3/.headline` 多种 bold/semibold | 同级不一致 | 统一 Section Title 与 Compact Section Title |
| Card Title | `.title3`, `.headline`, `.body.bold` | 对象卡层级漂移 | Customer Card Title / Operations Row Title 共用 scale、不同密度 |
| Body/Supporting | `.body/.subheadline/.footnote` | 基本可复用 | 明确 primary/supporting/caption 用途 |
| Button | `.body.semibold/.headline` | 多套 style | 统一 Button Label |
| Badge | `.caption/.caption2` bold/semibold | 小字号与单行风险 | Badge Label 允许内容驱动，不依赖缩放 |

风险证据：Auth 46/42pt、Customer hero 38/30pt、Schedule day 24pt；多个页面使用 `lineLimit(1)` + `minimumScaleFactor(0.72...0.86)`。新系统以 SwiftUI semantic Font 为实现真值，Figma point size 仅为默认字号样本。

## Layout

- 页面左右边距：主流 20pt；部分 24pt。规范为 Customer 20、宽屏/Operations 可 20–24，但使用同一 spacing token。
- Section 间距：现有 16/24 混用；规范为 24 常规、16 紧凑。
- Card 内边距：主流 16；保留。
- Card 间距：12/16；Customer 16、Operations row group 可 8–12。
- 图片/Avatar：32/44/56/58/64/112/116 多套。规范为 Avatar 32/44/64，业务照片允许内容尺寸而非身份 Avatar token。
- Bottom Action Area：Request Wizard 的双按钮是 canonical；需 safe-area inset、内容滚动避让、Dynamic Type 时纵排。
- Tab Bar：当前视觉为悬浮式系统控制层；内容必须增加安全区而非固定底部 padding 猜测。
- 明确风险：Pet card `172×252`、placeholder `116`、日条 `64×78`、hero 及 badge 多处固定 offset。

## Shape and Effects

- Card Radius 24 是核心品牌特征；hero 可用 32，不能把 32 扩散为所有卡片。
- Button Radius 18；input 16；sheet 28；chip capsule。层级合理，需统一调用。
- Border 1pt，selected 1.5pt；保留 default/selected 两级。
- Shadow：soft card `black 5%, r22, y8`，small card `r16,y6`；CTA mint/coral shadow 较强。保留柔和 card shadow，CTA glow 仅 Brand/Customer primary action。
- Disabled：当前 opacity 0.64 + soft fill；需同时降低 emphasis、保留可读标签。

## Brand Elements

- 全局可用：暖白、薄荷 accent、宠物照片/头像、适度大圆角、柔和实体 surface、小面积 paw/宠物语义图标。
- Brand Surface 优先：emoji hero、漂浮装饰圆、较明显渐变、品牌 display 字体、情感化成功/空状态插图。
- Customer 可有限使用：hero 渐变、paw 装饰、宠物照片；每屏只保留一个主情感焦点。
- Groomer 限制使用：照片仅用于身份/预约对象；减少 emoji、装饰圆和大面积渐变。
- 不全局化：固定 emoji 尺寸、随机装饰 offset、每张业务卡的渐变或强 shadow。

## Surface Profiles

### Brand Surface

Launch、Onboarding、Authentication、关键 Success/Empty。低密度、可有单一插图焦点、较大标题与薄荷渐变 CTA；装饰必须 accessibility-hidden，并对 Reduce Motion/Transparency 降级。

### Customer Surface

Home、Pet、Requests、Booking、Wizard、Messages。中等密度；宠物/服务/状态形成对象卡扫描顺序；允许照片、hero 和较多卡片，但设置行/表单行不逐行卡片化。

### Groomer Operations Surface

Dashboard、Calendar、Appointments、Offers、Customer/Pet 管理。中高密度；同一暖白/薄荷/圆角体系，减少装饰和大标题，增加紧凑 row、时间/状态/快捷操作。珊瑚仅为辅助运营强调，不形成独立品牌。

三个 Surface 共享 color、type、radius、status、SF Symbols、核心组件；差异只在密度、标题尺度、卡片频率、装饰量、row 高度与快捷操作数量。

## Accessibility Layout Rules

1. 承载用户文字的 Card 不使用固定高度。
2. 主要文本默认允许换行。
3. 次要文本仅在业务允许时截断。
4. Button 触控区域不低于 44×44pt。
5. 状态同时使用文字/图标，不只依赖颜色。
6. Scroll content 避开 Tab Bar 与 Bottom Action Area。
7. Dynamic Type 放大时横向布局可切换纵向。
8. 多步骤流程不依赖五个固定宽度文字标签。
9. Avatar、图标、文字不以固定 offset 保持对齐。
10. 复杂组件使用 `ViewThatFits`、`Layout`、`AnyLayout` 或 size class。
11. 验证标准字号与至少一个 Accessibility 字号。
12. `minimumScaleFactor` 不作为主要无障碍方案。
13. Button/Card 内容在文字放大时不得遮挡。
14. 破坏性操作必须有文字标签与确认流程。

## 当前四个 Figma 组件初审

| 组件 | 结论 | 原因 |
|---|---|---|
| Icon Button | Revise | 44pt 与 instance swap 可保留；视觉需改为 Beckon surface/薄荷状态 |
| Primary Button | Revise | API/状态可保留；深青实体按钮不符合现有薄荷渐变与 18pt radius |
| Secondary Button | Revise | 结构接近 canonical；需改薄荷 foreground、暖 border、18pt radius |
| Destructive Button | Revise | 状态/API保留；建议白 surface + error 文本/边框，避免大面积红色 |

当前不删除、不归档；最终判断以 Figma `45 Visual Calibration` screenshot 为准。
