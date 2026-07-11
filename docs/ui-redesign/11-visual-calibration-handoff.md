# Beckon Visual Calibration Handoff

## 1. Beckon 视觉语言总结

正式方向为 **Beckon Warm Utility System**：暖白背景、薄荷品牌色、白色实体 surface、24pt 对象卡、宠物照片与柔和情感元素构成品牌 DNA；原生 iOS 结构负责导航、表单、Sheet、Toolbar 与无障碍，但视觉不退化为系统默认后台。

证据来自 iPhone 17 Pro Max 真机模拟运行的 Auth Landing、Customer Home、Request Wizard、Customer Bookings、Groomer Home、Groomer Schedule，以及 `DesignTokens.swift` 和相关生产 View。详细审计见 `10-existing-visual-language-audit.md`。

## 2. 保留的现有特征

- `#FAF7F2` 暖白背景、白色 surface、`#232323` 暖黑文字。
- `#7ECFC0/#5FBFAE` 薄荷品牌主色。
- 24pt card、18pt button、16pt input、capsule badge。
- 宠物照片/Avatar、单一情感 hero、克制 paw/emoji/装饰圆。
- Customer 中等密度、对象级卡片、底部操作区与小面积状态表达。
- Groomer 的日期/状态优先信息结构。

## 3. 被规范化的特征

- 标题、section、card、body、support、caption、button、badge 使用统一语义尺度。
- 页面边距 20、对象卡 padding 16、Customer section 24、Operations 8–16 紧凑节奏。
- Customer 与 Groomer 共用 token/组件，通过密度和装饰量区分。
- Card/Row 内容驱动高度；长姓名、服务和 Dynamic Type 可换行/纵排。
- 状态色只用于 badge、图标、节点、边框并配文字。
- Bottom Action Area 使用 safe-area inset，内容滚动避让。

## 4. 被淘汰的特征

- 172×252 宠物卡、116pt 空状态、64×78 日卡等承载文字的固定高度。
- 以 `minimumScaleFactor` 作为主要无障碍策略。
- 用固定 offset 对齐 Avatar、badge 和装饰。
- 每个模块自建不同 title/card/badge/button 规则。
- 大面积高饱和状态背景或 Groomer 独立后台品牌。

## 5. Surface Profiles

| Profile | 密度 | 标题 | 卡片/装饰 | 典型页面 |
|---|---|---|---|---|
| Brand | 低 | 最大但可缩放 | 单一 hero、emoji/插图、渐变 CTA | Launch/Auth/Onboarding/Success/Empty |
| Customer | 中 | Large Title/Title 1 | 较多对象卡、宠物照片、有限 hero | Home/Pet/Requests/Booking/Wizard/Messages |
| Groomer Operations | 中高 | Title 2/3 或紧凑 header | row/group 优先，少装饰，多快捷操作 | Dashboard/Schedule/Offers/Appointments/Business ops |

三者共享 Color、Typography、Radius、Status、SF Symbols 与核心组件。

## 6. Token 修订建议

- Figma primitive 已校准为 canonical：background `#FAF7F2`、mint `#7ECFC0/#5FBFAE`、coral `#FF9A8B`、success/warning/error 与代码一致。
- Semantic aliases 和 variable IDs 保留；新增 `Radius/Card = 24`。
- `Accent/Primary`、`Accent/Secondary`、`Status/Error` scope 已扩展至 fill/text/stroke。
- 后续增加 `Surface/Selected`、`Status/*/Subtle` 时仍 alias primitive；不复制组件模拟主题。
- Figma 仍为 Light 单 mode；SwiftUI 必须使用系统语义 background/text 并支持 Dark Mode。

## 7. Accessibility Layout Rules

采用 `10-existing-visual-language-audit.md` 的 14 条规则：内容卡无固定高度、主要文字换行、44×44 最小触控、状态不只靠颜色、scroll 避开系统控制、Dynamic Type 横转纵、复杂布局使用 `ViewThatFits/Layout/AnyLayout`、至少测试一个 Accessibility 字号、破坏性操作保留文字与确认。

## 8. 当前四个组件结论

| 组件 | 结论 | Component Set ID | 修订结果 |
|---|---|---|---|
| Icon Button | Revise | `13:7` | 保留 44×44、圆形、instance swap；改为 warm surface + mint icon 语义 |
| Primary Button | Revise | `14:8` | 保留 Default/Disabled/Loading 与 Label；改 18 radius、52 高、mint fill |
| Secondary Button | Revise | `15:8` | 保留状态/API；改 18 radius、warm surface/border |
| Destructive Button | Revise | `15:15` | 保留状态/API；由整面红改为白 surface + error text/stroke |

四者 metadata 和局部 screenshot 均通过；未删除、未归档。正式复用仍等待人工批准本轮校准。

## 9. 剩余 12 个组件方向

- Status Badge：mint/neutral/status subtle，文字+可选图标，内容驱动宽度。
- Pet Avatar：32/44/64；真实照片、placeholder、loading/error，不固定 offset。
- Section Header：Customer 与 compact Operations density，不分裂视觉品牌。
- Search/Form/DateTime：实体 surface、16 radius、label/help/error 语义，Dynamic Type 纵向。
- Service/Customer Row：Customer 可 64 avatar；Operations 44 avatar、紧凑 metadata/quick action。
- Appointment Card：时间→宠物→服务→状态稳定顺序，5 状态复用 badge，不整卡染色。
- Empty/Error/Loading：Brand 可有插图；Operations 更紧凑，均支持明确恢复操作。

## 10. Customer 与 Groomer 的统一和差异

统一：暖白、薄荷、白 surface、24 card、18 controls、SF Pro/SF Symbols、status 和核心组件。Customer 保留照片、hero 和更宽松 section；Groomer 减少大标题/装饰、缩短 row 间距、优先时间/状态/快捷动作。珊瑚只作辅助运营 accent。

## 11. Figma Node IDs

- 文件：`XhOqumKm670mJTHUc72qga`
- `45 Visual Calibration`：`18:2`
- A Existing Visual DNA：`18:7`
- B Normalized Customer Surface：`18:35`
- C Normalized Groomer Operations Surface：`18:63`
- Icon / Primary / Secondary / Destructive：`13:7` / `14:8` / `15:8` / `15:15`
- 新增 Card radius variable：`VariableID:17:2`

## 12. Screenshot 验证

- Visual Calibration `18:2`：通过；三 profile 无重叠/截断，长宠物名样本可见，Groomer 密度明显更紧凑但品牌一致。
- 四个 Button Component Sets：metadata 与 screenshot 均通过。
- Simulator canonical screenshots：Auth、Customer Home/Wizard/Bookings、Groomer Home/Schedule 均来自运行 App，不是 Preview。
- 延期：Figma Dark Mode、Accessibility size visual variants、剩余 12 个组件，等待人工批准。

## 停止点

状态为 `phase-3-visual-calibration-pending-approval`。不继续组件、不创建完整业务页面、不进入 Figma→SwiftUI。

## Figma Full Capability Rules

后续正式设计必须遵守 `12-real-screen-calibration-handoff.md` 第 10 节：正式组件使用 Variables、Auto Layout、Component Properties 与 Nested Instances；正式页面同时验证 Light/Dark、Surface density、长文本和 Accessibility Dynamic Type；Customer/Groomer 共用系统；关键流程建立 Prototype；Tokens 稳定后导出 DTCG JSON 并生成 SwiftUI 映射；每个 Frame 维护 SwiftUI/ViewModel/原生容器/业务/Accessibility 追溯。Professional 计划当前不使用 Code Connect，不以 Sites、Web 或 Make 代码直接生成 SwiftUI 生产实现。
