# Beckon Figma Design System — Phase 3 Handoff

## Figma 文件

- 文件：[Pet Grooming App — UI Redesign](https://www.figma.com/design/XhOqumKm670mJTHUc72qga)
- fileKey：`XhOqumKm670mJTHUc72qga`
- 方向：`Beckon Warm Utility System`
- 当前状态：Phase 3 components complete；完整业务页面尚未开始。

## Foundations

- 6 Variable Collections，61 Variables；当前实现和视觉验证为 Light。
- 17 Semantic Colors 均通过 alias 使用 Primitives。
- 13 个 SF Pro Text Styles，3 个 Effect Styles。
- 正式页面批准前仍需在现有 Collections 中增加 Dark mode；不得复制组件模拟主题。

## 16 个正式组件

| 组件 | Node ID | Variant / Property 摘要 | Nested Instances | SwiftUI 建议名称 |
|---|---|---|---|---|
| Icon Button | `13:7` | State；Icon Swap；Icon Visible | icon helper | `BeckonIconButton` |
| Primary Button | `14:8` | State；Label；Icon Swap；Icon Visible | icon helper | `BeckonPrimaryButtonStyle` |
| Secondary Button | `15:8` | State；Label；Icon Swap；Icon Visible | icon helper | `BeckonSecondaryButtonStyle` |
| Destructive Button | `15:15` | State；Label；Icon Swap；Icon Visible | icon helper | `BeckonDestructiveButtonStyle` |
| Status Badge | `32:148` | Status 5；Label | — | `BeckonStatusChip` |
| Pet Avatar | `32:191` | Size 32/44/64；Photo/Placeholder；Fallback | — | `BeckonPetAvatar` |
| Section Header | `32:236` | Customer/Operations density；Title；Action Visible | Icon Button | `BeckonSectionHeader` |
| Search Field | `32:291` | Default/Focused/Disabled；Query；Clear Visible | Icon Button | `.searchable` / `BeckonSearchField` |
| Form Field | `32:342` | Default/Focused/Error/Disabled；Label/Value/Helper | — | `BeckonFormField` |
| Date and Time Row | `32:391` | Customer/Operations density；Label/Value | Icon Button | `BeckonDateTimeRow` |
| Service Row | `32:440` | Customer/Operations density；Title/Metadata | Icon Button | `BeckonServiceRow` |
| Customer Row | `32:483` | Customer/Operations density；Name/Metadata | Pet Avatar | `BeckonCustomerRow` |
| Appointment Card | `32:642` | Density × 5 Status = 10；业务文字；Action Visible | Status Badge、Pet Avatar | `BeckonAppointmentCard` |
| Empty State | `32:693` | Customer/Operations surface；Title/Message/Action | Primary Button | `BeckonEmptyState` |
| Error State | `32:744` | Customer/Operations surface；Title/Message | Secondary Button | `BeckonErrorState` |
| Loading State | `32:783` | Customer/Operations surface；Title/Message | — | `BeckonLoadingView` |

Appointment Card 只使用 `Density × Status` 的必要矩阵；宠物、状态、文字和操作通过 Nested Instances、Text、Boolean 与 Instance properties 表达，不为字段组合增加 Variant。

## 5 个 Layout Patterns

| Pattern | Node ID | SwiftUI / 原生映射 |
|---|---|---|
| Page Header | `32:815` | `NavigationStack` + `ToolbarItem(placement: .topBarTrailing)` |
| Wizard Progress Header | `32:852` | adaptive stack + semantic step text |
| Pet Selection Card | `32:920` | adaptive H/V layout + `selectedPetID` Binding |
| Bottom Action Area | `32:980` | `safeAreaInset(edge: .bottom)` |
| Scroll Content + Bottom Inset | `32:1014` | `ScrollView` + action height + safe area + 24pt |

Bottom Tab Bar 继续使用原生 SwiftUI `TabView` 规范，不建立复杂自定义 Tab Bar Component。

## Surface 使用差异

- Customer：中等密度、照片与单一情感 Hero、较宽松 Section rhythm。
- Groomer Operations：同一 Token/Component API，使用 compact density、时间优先、状态优先、较少装饰与任务所需字段。
- 不复制两套组件库；差异来自 Density、Composition、字段可见性和内容优先级。

## Accessibility 与 QA

- `86 Component Accessibility QA`：`35:177`；12 个新组件均有 Default + 长文本/Operations 压力实例。
- 四个 Button property tests：Section `31:264`；不同 Label 已证明属性面板与画布同步。
- 主要文本允许换行；Row/Card 内容驱动高度；44pt 最小操作目标。
- Status 同时使用文字和颜色；选中状态使用文字/勾选/边框。
- Layout Patterns screenshot、Data Display、Forms、Feedback、Accessibility QA 和 Button Tests 均完成局部验证。

## 业务边界

- Schedule 卡片整体导航 `BookingDetailView`；不长期显示 Cancel/Delete。
- Cancel 仅位于详情或 More，文案为 Cancel Appointment，并经过 confirmation dialog。
- Complete 继续由 `booking.canComplete(for: .groomer)` 控制。
- Wizard 保留 `selectedPetID`、验证、提交禁用和安全区 Bottom Action Area。
- Customer Home 通知映射 `ToolbarItem(placement: .topBarTrailing)`，accessibility label 为 `Notifications`。

## 延期事项

- Dark Mode Variable mode 与全部正式页面 Dark QA。
- 关键流程 clickable Prototype。
- Token 稳定后的 DTCG JSON 和 SwiftUI Token 输出。
- 完整业务页面设计与 Figma → SwiftUI 重建。
- Professional 计划当前不使用 Code Connect；继续维护 node ID ↔ SwiftUI 显式映射。

未修改生产 SwiftUI。
