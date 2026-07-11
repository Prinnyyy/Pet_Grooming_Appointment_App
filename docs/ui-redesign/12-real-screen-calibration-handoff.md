# Phase 3 Visual Calibration V2 — Real Screen Fragments

## 1. 九个校准 Frame

目标文件：[Pet Grooming App — UI Redesign](https://www.figma.com/design/XhOqumKm670mJTHUc72qga)，Page `00 Design System`，Section `46 Real Screen Calibration`（`21:2`）。所有画板为 393×852 pt，仅用于校准，不是完整产品页面。

| 页面组 | Existing Reference | Normalized Default | Normalized Accessibility XL |
|---|---|---|---|
| Customer Home | `23:5` | `23:31` | `23:59` |
| Grooming Request — Pet Selection | `25:10` | `25:40` | `25:70` |
| Groomer Schedule / Agenda | `26:19` | `26:74` | `26:136` |

组容器：Customer Home `23:2`；Pet Selection `25:7`；Groomer Schedule `26:16`。每组均附 Keep / Normalize / Accessibility / SwiftUI 影响说明。

## 2. Existing 与 Normalized 的差异

### Customer Home

- 保留暖白、薄荷 Hero、宠物图像、24pt 对象卡和中等密度。
- 统一标题、Section、卡片 padding 和状态表达；宠物卡改为内容驱动高度。
- Scroll content 与 Bottom Tab Bar 分成明确的内容区和安全区控制层。
- XL 将 Header 改为纵向，长客户名与宠物名换行，宠物卡自然增高。

### Grooming Request — Pet Selection

- 保留薄荷选中态、宠物图像、Add New Pet 和明确的 Continue。
- 五个固定宽度步骤标签改为语义进度；选中态使用文字、勾选和边框共同表达。
- Bottom Action Area 独立于 Scroll content；XL 下 Back / Continue 纵排。
- 宠物卡在 XL 下由横排改纵排，长品种和护理信息完整换行。

### Groomer Schedule / Agenda

- 保留暖白、薄荷、圆角、日期切换和 grouped surface。
- 时间成为首要扫描锚点；宠物名和服务高于客户、地址；状态为小面积 Badge + 文字。
- Confirmed / Completed / Cancelled 来自现有 `Booking` 状态；Message、Complete、Cancel 来自现有 booking 操作。
- 10:30–11:00 travel buffer 只表达日程空档，不引入新业务动作。
- XL 将时间、业务信息、状态和快捷操作纵排，核心操作仍可见。

## 3. Customer Surface 最终规则

- 中等信息密度；每屏允许一个主要情感化 Hero。
- 宠物照片、暖白背景、薄荷强调和大圆角是品牌资产。
- 业务对象使用完整卡片；普通表单行和设置项不逐项卡片化。
- 页面标题可较大，但长用户名称必须换行或切换布局。
- Bottom Tab Bar 属于控制层；滚动内容必须保留可滚动到底的安全区。

## 4. Groomer Operations Surface 最终规则

- 与 Customer 共用 Color、Typography、Radius、Status、Icon 和 Core Components。
- 通过较紧 Section rhythm、成组 row、少装饰和明确快捷操作提高密度。
- 时间是日程首要锚点；宠物和服务是主要任务信息；客户与地址为次级上下文。
- 状态不得整卡染色；使用文字、图标或 Badge 与小面积颜色。
- 不建立独立后台风格，也不复制第二套 design system。

## 5. Accessibility XL 布局规则

1. 主要文字换行，不使用 `minimumScaleFactor` 作为主要方案。
2. 横向 Header、卡片和按钮组可切换纵向。
3. Card 使用内容驱动高度；主要业务信息不得截断。
4. Status Badge 可移至新行，但必须保留状态文字。
5. 非必要装饰可隐藏；宠物、服务、时间和主要操作不可隐藏。
6. 所有按钮保持至少 44×44 pt 触控目标。
7. 标准字号与 Accessibility XL 使用相同业务内容压力测试。

## 6. Bottom Tab 与 Bottom Action Area

- 使用原生 safe-area inset 语义，不用固定 offset 模拟。
- Scroll content 必须有与控制层高度对应的可滚动尾部空间。
- Bottom Action Area 在标准字号可横排，Accessibility XL 改纵排。
- 主要操作保持最后且最明确；次要操作不压过主要操作。
- Tab / Action Area 不得覆盖最后一张卡片或错误提示。

## 7. 多步骤流程规则

- 进度以当前步骤、总步骤和语义名称表达，不依赖五个等宽文字标签。
- Back、Continue、Publish 顺序和现有导航结果保持一致。
- 选择状态不只通过颜色表达。
- `selectedPetID`、验证状态、提交禁用和 safe-area bottom bar 必须保留。

## 8. 当前四个组件最终结论

| 组件 | Component Set ID | 结论 | 真实片段验证 |
|---|---|---|---|
| Icon Button | `13:7` | **Approved** | Home 通知、Wizard Back；44pt，Instance Swap 保留 |
| Primary Button | `14:8` | **Approved** | Hero CTA、Continue、Complete；XL 可纵排并填充宽度 |
| Secondary Button | `15:8` | **Approved** | Wizard Back、Groomer Message；不与主操作竞争 |
| Destructive Button | `15:15` | **Approved** | Groomer Cancel；文字标签 + error stroke，不只依赖红色 |

四个原 Component IDs 均保留；未删除、重建或归档。实例属性已记录正确 Label 值；Figma screenshot 服务对部分 nested Label override 仍显示 default label，列为人工核验项。

## 9. 剩余 12 个组件的明确约束

- 必须从本轮真实片段的构图和密度需求出发，不从孤立组件板扩展。
- Status Badge：文字/图标 + 小面积状态色，支持新行布局。
- Pet Avatar / Customer Row / Service Row：共享组件，以 density property 控制 composition。
- Section Header：Customer 常规与 Operations compact 是同一组件属性。
- Search / Form / Date-Time：内容驱动高度，label/help/error 语义完整。
- Appointment Card：时间→宠物→服务→状态；客户/地址按任务需要；XL 纵排。
- Empty / Error / Loading：Customer 可保留适度情感元素，Operations 更紧凑但共享状态系统。
- 正式创建前仍需人工批准本轮校准。

## 10. Figma Full Capability Rules

1. 正式组件必须使用 Variables、Auto Layout、Component Properties 和 Nested Instances，不得只创建静态 Frame。
2. 所有正式页面必须检查 Light Mode、Dark Mode、Customer 或 Groomer density、长文本和 Accessibility Dynamic Type。
3. Customer 与 Groomer 共享同一设计系统，通过 Density、Composition 和内容优先级区分，不复制两套系统。
4. 关键业务流程必须建立可点击 Prototype，不只交付静态页面。
5. 复杂交互可先用 Figma Make 探索，但批准方案必须回写到 Figma Design 的 Variables、Components 和 Frames。
6. Tokens 稳定后导出 DTCG JSON，并生成对应 SwiftUI Token 实现。
7. 每个正式 Frame 必须记录 SwiftUI View、ViewModel、原生容器映射、业务约束和 Accessibility 规则。
8. Professional 计划暂不使用 Code Connect；继续维护 Figma node ID 与 SwiftUI 类型的显式映射。
9. 不使用 Figma Sites、Web 代码或 Make 代码作为 SwiftUI 生产实现的直接来源。
10. MCP 同时用于结构、Token、Component 审计，Screenshot QA，Prototype 流程核验和 Figma → SwiftUI 上下文提取。

## 11. 验证结果

- 九个 Frame metadata：393×852；均含 Auto Layout Scroll content 与独立底部控制层。
- Text Style：所有校准文字使用现有 SF Pro semantic styles；未发现无 Style 文本。
- Variable binding：容器、文字、边框和状态色使用现有 Semantic Variables；组件实例保留组件绑定。
- 四个现有 Component Set 均在真实页面片段中复用。
- 三组局部 screenshot 均完成；首轮发现的 text overflow、Pet Card 塌缩和快捷操作裁切已修复并复验。
- 长客户名、宠物名、服务和地址触发换行或纵向 composition；主要信息未使用缩放兜底。
- Scroll content 与 Tab Bar / Bottom Action Area / Groomer Navigation 分离；XL Action Area 纵排。
- 本轮校准样本只验证 Light；任何正式页面批准前必须按 Full Capability Rules 补 Dark Mode。

## 12. 待人工确认

1. 是否批准三组 Normalized Default / Accessibility XL 作为剩余 12 个组件的构图基线。
2. Groomer 日程的 Cancel 是否应只在详情页展示；本轮仅验证现有可取消能力与 Destructive Button。
3. 是否接受 Customer Home 在 Accessibility XL 下把通知按钮移至标题下方。
4. 在 Figma 编辑器中人工确认 nested Label override 的视觉同步。

当前状态：`phase-3-real-screen-calibration-pending-approval`。未创建剩余 12 个组件，未创建完整业务页面，未修改生产 SwiftUI。
