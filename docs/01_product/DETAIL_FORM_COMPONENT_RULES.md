# 详情页与表单组件复用规范

日期：2026-11-04。对象：当前 Groomer Request 沙盒完整详情页、C3-A 报价表单、Pet profile 内页。

本规范整理用户已认可的沙盒设计，数值来自 SwiftUI 实现，不是截图像素测量。它是后续同类沙盒的复用基线；T-466 已将下文确定的 Grooming／Request／Booking 规则采用到正式代码（见末节），不自动覆盖全 App 的独立模块。Account 页面及其他报价候选方案不在本规范范围。最新 Add message 收起修正仍由用户交互验收，不将编译通过等同于交互通过。

沙盒复用入口集中在 `GroomingSandboxDetailRows.swift`：`SandboxDetailRowLayout` 管理栏目参数；`SandboxRequestFactRow` 管理普通只读栏目；`SandboxDisclosureRow` 管理可展开栏目；`SandboxDetailRowGroup` 管理相邻栏目的间距与横线。可展开组件提供 `belowSummary`（表头下方滚轮）和 `inlineText`（正文列内编辑）两种现有排列。展开状态、字段值、键盘焦点及模拟业务操作仍由原页面持有。

下次同类设计先选现有栏目组件和编辑器，复用原模拟数据、导航与隔离会话，只补缺少的字段。不要按截图逐页重新搭建，也不要把独立模块强行改成普通栏目。完整体验入口：`GroomingSandboxRequestReview.swift` → `#Preview("Groomer · Full request, C3-A")`。本文件维护唯一参数表；旧证据目录只保留入口链接。

## 1. 测量口径

- 单位统一为逻辑点 pt，不使用截图像素。以下数值是默认字号基准；语义字体与 `ScaledMetric` 会随 Dynamic Type 放大。
- **卡片宽 W** 指卡片正面宽度。描边是覆盖绘制，不再从正文宽度重复扣除。底部厚边单独计算。
- **正文区** 指标题、正文及补充说明共同使用的内容列；不包括左侧图标列，也不包括右侧操作列。
- **输入框外框** 与 **输入文字区域** 是两个边界。外框对齐正文区，不代表内部文字与普通正文的起点相同。
- **行最小高度、图标直径、点击范围** 是三个不同数据。普通信息栏与可展开栏的最小行高统一为 56pt，图标圆底仍为 34pt。
- **组件外部间距、标签内部留白、字体自身行框** 分开记录。相同外部间距不等于不同字号之间的字形距离相同。

## 2. 页面与卡片：已实现的公共数据

| 项目 | 当前值 | 归属 |
|---|---:|---|
| 页面左右边距 | 20 | `DesignPage` / `Spacing.screenHorizontal` |
| 页面滚动内容顶部留白 | 16 | 当前 `DesignPage` 实际使用 `Spacing.lg` |
| 不同模块之间的间距 | 24 | `Layout.sectionSpacing` |
| 模块标题与卡片之间 | 12 | `Layout.sectionContentSpacing` |
| 卡片内容四边留白 | 16 | `designCardBody` / 当前概览与 C3-A |
| 普通卡片圆角 | 24 | `CornerRadius.card` |
| 普通卡片描边 | 2 | `Ledge.edgeWidth` |
| 普通卡片底部厚边 | 5 | `Ledge.card`；在内容外占位 |
| 相邻普通 / 可展开栏目之间 | 上 8 + 1pt 横线 + 下 8，共 **17** | Request 概览的事实组、The request、Your offer、Pet profile 与 C3-A 共用 `SandboxDetailRowGroup`；隐藏栏目不留多余横线 |
| 独立内容组之间 | 16 | 身份头、进度条、金额展示、事实组或独立动作之间；不叠加到栏间分隔线上 |
| 基础交互最小点击尺寸 | 44 × 44 | `Metrics.minimumTouchTarget`；不能用 24pt 箭头宽替代 |

24pt 模块间距由布局容器计算；卡片自带的 5pt 厚边已经是卡片布局的一部分，不应再手工补一遍。

## 3. 栏目类型与正文区

### A. 普通信息栏目

组件：`SandboxRequestFactRow`。用于只读事实，不预留箭头空位。

| 数据 | 当前值 / 行为 |
|---|---|
| 左图标圆底 | 34 × 34 |
| 图标列到正文列 | 12 |
| 正文相对卡片左边界 | 16 + 34 + 12 = **62** |
| 正文到卡片右边界 | **16** |
| 正文宽度 | **W − 78** |
| 标题 → 正文 → 补充说明间距 | 各 **4** |
| 最小行高 | **56**，与可展开栏目共用 `minimumHeight` 并随 `.subheadline` 缩放；长文本按内容增高 |
| 图标 Y 对齐 | 对齐整个栏目内容的水平中线 |
| 正文换行 | 允许向下增高，不为对齐而截掉必要信息 |

### B. 带箭头的可展开栏目

当前实现：`SandboxDisclosureRow` 的 `belowSummary` 排列；Start 与 Service duration 共用，内部正文继续复用 `SandboxRequestFactRow`。

| 数据 | 当前值 / 行为 |
|---|---|
| 左图标、图标与正文间距 | 34；12，与 A 相同 |
| 正文相对卡片左边界 | **62**，与 A 相同 |
| 正文 → 箭头区间距 | **12** |
| 箭头区宽 | **24**；这不是箭头字形宽度，也不是独立点击范围 |
| 箭头区 → 卡片右边界 | **16** |
| 正文到卡片右边界 | 16 + 24 + 12 = **52** |
| 正文宽度 | **W − 114**，比普通栏目少 36 |
| 标题 → 正文 → 补充说明间距 | 各 **4** |
| 收起时最小行高 | **56**，随 `.subheadline` 缩放；长文本仍可增高 |
| 图标与箭头对齐 | 两者中心在同一条水平线上，随当前行高度居中 |
| 点击范围 | 整个栏目表头；箭头只是操作提示 |
| 展开标识 | 同一箭头旋转 180°，不替换另一种图标 |

横向布局关系：

```text
普通信息：16 | 图标34 | 间隔12 | 正文                    | 16
可展开项：16 | 图标34 | 间隔12 | 正文 | 间隔12 | 箭头24 | 16
```

例：卡片正面宽 350pt 时，普通正文宽 272pt，可展开栏目的正文宽 236pt。这个例子只解释公式，不锁定设备宽度。

### C. 可展开留言栏目

当前使用 `SandboxDisclosureRow` 的 `inlineText` 排列，横向沿用 B，保留原留言编辑的间距与固定表头锚点。原 `inlineMessage` 只负责提供文字、状态、焦点和原输入框，不再自行计算列宽。

| 数据 | 当前值 / 行为 |
|---|---|
| 图标列、正文列、右箭头列 | 与 B 相同 |
| 收起时最小行高 | 56；多行留言允许增高 |
| 收起时标题与正文 / Optional 间距 | **4**，与普通可展开栏目一致 |
| 展开时标题与输入框间距 | **8**，由编辑区域单独管理 |
| 表头顶部留白 | **8**，随字号缩放 |
| 收起时表头底部留白 | **8**，随字号缩放；展开时取消这段底部留白 |
| 空留言收起状态 | `Add message` + 斜体 `Optional` |
| 展开状态 | 输入框无占位文字；标题不因编辑内容即时改名 |
| 有留言收起状态 | `Messages` + 已输入正文，正文使用普通 supporting 字体；摘要最多 3 行，展开查看 / 编辑全文 |
| 收起时图标与箭头 | 按整个摘要行居中 |
| 展开时图标与箭头 | 停在初始表头的同一条水平中线，默认中心距行顶 28；不随输入框增高下移 |
| 展开后的收起动作 | 图标、标题和箭头归于同一个整行按钮，点击表头即可收起；按钮最小高 56，覆盖可见箭头。输入框在独立前景层接收编辑手势，标题与输入框仍相隔 8；不能把 56pt 箭头挂在只有一行文字高度的按钮外面 |
| 输入框外框宽度 | **W − 114**，左边界 62、右边界距卡片 52 |
| 输入框内部左右留白 | 各 **16**；实际输入文字起点距卡片左边界 **78** |
| 输入框内部上下留白 | 各 **12** |
| 输入框圆角 / 正常描边 | **16 / 1** |
| 输入框最小高度 | 通用外框下限 52；本例另外保留 **3～6 行**文字空间，实际高度不能写死为 52 |
| 输入框底部额外留白 | **4** |
| 输入文字可用宽度 | **W − 146** |

上述“收起 4pt、展开输入框 8pt”是用户于 2026-11-04 明确确认的复用规则，适用于可展开且包含文本框的栏目。表头的上下 8pt 留白、字体行框和文本换行仍参与真实高度，因此“同为最小 56pt”不等于三个栏目的实测高度在所有状态下绝对相等。

普通信息栏和可展开栏的相邻项统一交给 `SandboxDetailRowGroup` 排列：上下各 8pt 留白，中间复用 `DesignRowDivider` 的 1pt 横线。展开的滚轮 / 输入框属于当前栏目，横线放在该栏目全部内容之后；不在标题与编辑器之间加线。价格区现采用栏目式布局，也使用同款底部分隔线；宠物身份头、进度条等独立模块不套用栏目分隔线。

C3-A 可展开组使用 `fillsCard: true`：把原有左右 16pt、组首尾 16pt、相邻横线上下各 8pt 的留白归入对应栏目内部，保持内容坐标与总间距不变，同时让整块栏目留白也可点击。56pt 仍是正文表头的最小高度，完整点击区域还包含这些留白。分隔线不加入点击区域。该设置只定义栏目布局与点击范围，不意味着点击时给整栏染色。

三行创建时均显式传入 `SandboxDetailRowLayout.cardRowInsets`：Start 使用首行，Duration 使用中间行，Message 使用末行；不在 `Group(subviews:)` 已解析子视图之后通过环境变量补发边距，避免某条渲染分支读取零值。图标左边界距卡片 16pt，正文起点 62pt，右箭头区域距卡片右边界 16pt，三行一致。

留言的标题、摘要、图标、箭头及编辑器只使用一份可见布局；透明按钮在其后方提供同范围的点击。不要使用“隐藏摘要占位＋背景按钮再排一份摘要”，也不让点击区域的尺寸反过来决定正文位置。栏目留白只由这份内容布局应用一次。

## 4. 每个实际栏目对应哪套设置

| 页面 / 模块 | 栏目 | 采用的设置 |
|---|---|---|
| Request 概览 | 宠物头像、名字、服务、Pet profile 按钮 | 独立身份摘要头，见第 5 节 |
| Request 概览 | Matched → Offer sent → Booked 与气泡 | 复用 `BeckonJourney` 的节点、连线和共享沙盒气泡。历史报价按该份报价的结果显示。未曾报价的请求结束时只显示匹配和结束两步。 |
| The request、Appointment | Service location、From the customer | A 普通信息栏目；服务地点置于地址正上方，留言置于模块底部 |
| Request 概览 | Needs action 原因条 | Groomer 列表及详情概览共用白底、珊瑚边框和底边，仅列表底部使用 `BeckonFootNote`。详情事实行图标使用深珊瑚图形和浅珊瑚圆底 |
| The request | Preferred time：From / Until | 独立时间区间布局，外部沿用 A 的图标与正文列 |
| The request | Address | A 普通信息栏目 |
| Make an offer | Price estimate、$、金额、键盘按钮 | 栏目式价格编辑区（独立金额字号） |
| Make an offer | Start、Service duration / Ends | B 可展开栏目 |
| Make an offer | Add message / Messages | C 留言栏目 |
| Your offer | 已发送报价金额 | 共享栏目式价格的只读展示 |
| Your offer | 金额、Your proposed time、报价回复期限、Your message | Request、Offers 和独立美容师原型复用 `SandboxRequestOfferRecord`。每份报价都显示原时段和期限，等待回复时标为 The offer ends，已接受、拒绝、过期或撤回时标为 Original offer deadline。留言按该报价实际填写的内容显示。当前预约安排通过 View booking 查看 |
| Pet profile | 头像、名字、Dog/Cat 与品种、毛发标签 | 独立宠物身份头 |
| Pet profile / Size and age | Weight、Size、Age | A 普通信息栏目 |
| Pet profile / Care notes | Temperament、Coat matting、Medical notes、Grooming notes | A 普通信息栏目 |
| Pet profile / Photos | 附加照片缩略图 | 独立横向照片组 |
| 页面底部 | Send offer、Dismiss、Withdraw、View booking | 固定操作栏。已预约时 View booking 独占整栏，按报价关联打开预约。预约尚未同步时此处可刷新 |

普通栏目并没有每个字段分别写一套布局；表中标记 A 的所有栏目实际共用同一个组件。

## 5. 独立模块的设计数据

| 模块 | 已实现的独立参数 | 复用边界 |
|---|---|---|
| Request 身份摘要头 | 头像 56，头像到名字 12；名字与服务间 4；右侧 Pet profile 按钮按内容宽，按钮面最小高 44、水平内边距 16、圆角 20、厚边 4；按按钮正面中心对齐名字与服务组 | 不套用 34pt 事实图标规则；这里的头像 56 与栏目行高 56 是不同含义 |
| 原版进度条 | 三节点直径 42，连接轨道高 9，节点与标签间 8，顶部气泡预留 48；气泡主体最小高 32、水平留白 12、尾部 16 × 8 | 复用完整组件及状态驱动的气泡，不能拆成普通行或按外观独立移动气泡 |
| Needs action 条 | 左右内边距 12，上下 8，图标与文字间 8；普通字号一行、无障碍字号允许换行 | 状态条使用语义状态色，不借用正文列或可展开箭头列 |
| Preferred time | 标题与区间内容间 **4**，直接共用普通栏目的 `SandboxDetailRowLayout.labelSpacing`；From/Until 网格行列间距 8；时间线标记宽 7、线宽 1.5；同日 Until 不重复日期，跨日显示日期，跨年保留年份；放不下时改纵向端点，端点组间 12 | 外层遵守普通栏目最小高度和图标居中；区间内部独立排版，不预留不存在的箭头区。无障碍字号隐藏左侧装饰钟表 |
| 价格编辑区 | 复用 `SandboxOfferPriceHeader`：白底，左侧 34pt tag 图标；标题与正文列对齐，标题至金额 4pt；金额 40pt / bold / rounded、textPrimary，美元符号不单独占列，和数字零额外间距；左右和顶部 16pt，底部 8pt，接 1pt 分隔线，下一栏目顶部 8pt | 键盘按钮保留原有 44pt 点击区、34pt 圆底和动画，居中置于右侧 24pt 操作列，与下方箭头共用竖向中心线；金额字体随 largeTitle 缩放，原生输入与静态显示同字重、字号、颜色；大字号保留纵向操作布局 |
| Start / Duration 滚轮 | 高 122；时长含小时与分钟两列，列间距 8；表头与展开编辑器在外层栈中的间距 16 | 当前滚轮在卡片内区布局，没有像留言输入框一样扣除左图标列和右箭头列；这是现状，不能声称所有编辑器已共用正文约束 |
| 已发送报价金额 | Your offer、Appointment 与 Make an offer 共用 `SandboxOfferPriceHeader`，统一白底、图标列、标题位置、40pt 粗体圆体金额与底部分隔线 | 只读显示保存的报价或预约金额，不提供键盘按钮；历史状态附属标签仍按实际情况保留。后续事实栏目顶部 8pt，避免分隔处额外留白 |
| Pet profile 身份头 | 卡片内边距 16；头像 80、白色描边 3；头像与文字间 16；名字、物种/品种、标签三层外部间距各 8；头像无点击放大 | 仅复用横幅样式，没有直接复用 Account 身份组件。大字号改为上下排列 |
| 毛发标签 | 标签内水平留白 9、垂直留白 5；标签内图标与文字间 5；胶囊形 | 外部间距 8 与内部留白 5 分开；不能用标签文字基线推算外部间距 |
| 附加照片组 | 缩略图 64 × 64、圆角 18、图间距 8；照片可点击查看 | 与头部不交互的圆头像分开；图片查看 sheet 沿用原入口。沙盒 Offer sent → Pepper 提供一张头像和一张可点开的附图 |
| 底部操作栏 | 左右 20、上下 12；并排按钮间 12，大字号纵排间 8；按钮正面最小高 58、水平内边距 16；额外厚边占位由按钮样式负责 | Request、Offer、Booking 双按钮扣除间隔后按 36% / 64% 分配：左副按钮只显示居中的动作文字，不放图标或预留图标空间；外观参照 Offers 白色胶囊：两端全圆、暖灰粗字、暖灰细边及同色底部厚边，右主按钮用默认珊瑚按钮，图标在文字右侧。辅助大字号改为全宽纵排，副在前、主在后；单独 Withdraw 占满宽度；按钮高度不能与栏目 56 混用 |

## 6. 字体与交互数据

实际复用应引用语义字体角色。下面字号仅为默认字号参考，不应把语义字体替换为固定尺寸。

| 用途 | 当前角色 | 默认参考 / 字重 |
|---|---|---|
| 模块标题 | `Expressive.section` | title2 / 22 / black / rounded |
| Pet profile 名字 | `Expressive.title` | title3 / 20 / black / rounded |
| Request 名字、主操作按钮 | `Expressive.headline` | headline / 17 / black / rounded |
| 普通正文、时间、地址、输入后的留言 | `Expressive.supporting` | subheadline / 15 / semibold / rounded |
| 服务名、Pet profile 按钮、普通图标字形 | `Expressive.emphasis` | subheadline / 15 / black / rounded |
| 栏目标题、日期说明、Ends、箭头 | `Expressive.chip` | caption / 12 / bold / rounded |
| 空留言 Optional | 本地系统斜体 | subheadline / 15 / semibold / italic；不使用 rounded |
| 价格编辑、已发送报价金额 | 共享价格栏的 `ScaledMetric` | 40 / bold / rounded、textPrimary，基于 largeTitle 缩放 |

- 普通标题用 `textTertiary`，正文用 `textPrimary`，补充说明用 `textSecondary`；角色色与状态色沿用现有组件和 `DesignTokens`，本表不另复制一套色值。
- 多行正文没有额外写死的行距或行高，使用语义字体行框自然排版；4/8/16 指组件之间的布局间距，不是文字行高。
- 可展开表头使用 `SandboxDisclosureButtonStyle` 上报按压状态，由箭头复用 `BeckonPressEngine` 呈现颜色反馈；不绘制整栏按压色块，保留原生 Button 的滚动取消。有效点击立即展开/收起，不等待箭头动画，也不受卡片位置移动后 350ms 防误触计时阻挡。
- C3-A 折叠使用 `Motion.swap`：spring response 0.45、dampingFraction 0.7；减少动态效果时用 easeOut 0.15。原生键盘拥有自身转场，不再叠加另一套键盘位移动画。
- Groomer 沙盒 Request、Offer、Booking 的气泡统一在 `FlowSandbox/Design/SandboxJourneyCallout.swift` 维护。状态映射决定文案、符号和语义类型；`SandboxStatusStyle.swift` 内的 `SandboxStatusTone.colors` 集中决定气泡、说明框和列表底条的图标、文字、底色、边框。详情页负责传入状态与对应节点，尖角始终指向节点中心。动态三点使用图标色；读屏沿用对应文案。

| 语义 | 场景 | 图标 / 文字 / 底色 |
|---|---|---|
| ready | 可报价、服务进行中 | 珊瑚红 / 深棕 / 浅珊瑚 |
| checking | 系统核验请求或报价 | 深蓝 / 暖黑 / 浅蓝 |
| action | 需要美容师处理 | 深琥珀 / 暖黑 / 淡金 |
| waiting | 等待另一方回复或评价 | 对方角色的深主题图标 / 深文字 / 浅主题底色；见下表 |
| success | 报价已接受、已收到评价 | 深绿 / 暖黑 / 浅绿 |
| declined | 顾客明确拒绝报价 | 暖灰图标 / 深色文字 / 浅暖灰底（与 quiet 共色） |
| quiet | 日期、取消、过期、撤回、不可用 | 暖灰 / 暖黑 / 浅暖灰 |

### 状态组件的统一接入（2026-11-05）

- Groomer 的 Request、Offer、Booking 详情与 Grooming 列表共用 `SandboxStatusTone`。气泡使用 `SandboxJourneyCallout`，说明使用 `SandboxNeedsActionPanel` / `SandboxStatusInfoPanel`，列表使用 `SandboxStatusFootNote`；不在各页面自行选择同一状态的颜色。
- Needs action 的列表原因条、详情行动面板及行动气泡均为淡金。直接邀请使用 `Reply to invitation`；一般匹配可报价仍使用珊瑚 `Make an offer`。系统核验与无法报价分别使用浅蓝及暖灰。
- Accepted 报价的 `Now in Bookings` 用成功绿；顾客明确拒绝报价用暖灰，以 `Customer declined` 和叉号区分关闭原因；保留独立 declined 语义，不使用错误红；取消、撤回、过期和未知状态仍用暖灰。所有说明框内图标、标题与正文按同一语义色读取。
- Booking 顶部统一使用 `SandboxBookingJourney`，终止分支不再退回小型状态 chip。顾客 / 美容师取消均显示 Booked → Cancelled，并在末节点连接 `Customer cancelled` / `Cancelled by you` 气泡。其他旧终止记录保留中性 Closed，不伪装成 Finished。
- 已完成待评价显示 Finished 节点及等待气泡；已评价在 Reviewed 节点保留 `Review received` 气泡。常规服务时段的连接线仍沿用已有推进量；改变气泡和面板配色不修改预约数据或服务状态。
- 此处为现有沙盒显示接入；PDF 的自动开始 / 单方完成流程不因配色任务而自动成为正式业务规则。Customer 原型已采用双向等待规则，其余页面的整体重设计不属于本次范围。

### 等待对方：角色配色规则（2026-11-05 已确认）

气泡框、`SandboxStatusInfoPanel` 和列表底部标签共用 **回应方** 的角色色，不取当前浏览者的主题色。页面、宠物信息和操作按钮保留自身角色主题；仅等待状态区域切换。

| 当前端 → 回应方 | 底色 | 图标 / 动态三点 | 标题与正文 | 气泡轮廓 |
|---|---|---|---|---|
| Groomer → Customer | `#E3F5F2` 浅薄荷 | `#1E6E5F` | `#0F3D35` | `#81D0C2` |
| Customer → Groomer | `#FFEDE9` 浅珊瑚 | `#B23A2B` | `#4A1C14` | `#FF9A8B` |

- 三个载体复用 `SandboxWaitingPalette(responder:)`。必须显式传入回应方；这里直接读取 `DesignTokens.Palette` 固定品牌色，不能读取会随页面角色变化的 `Colors.customer…` 动态色。
- 文案说明等待谁，例如 `Waiting for customer` / `Waiting for groomer`；列表简写 `Awaiting customer reply` / `Awaiting groomer reply`。等待顾客评价仍属等待，不升级为美容师的必做行动。
- 系统核验仍用核验色；本人需要决定仍用行动色；成功、拒绝、取消、过期继续各自状态色。不能因为页面属于顾客而把所有浅珊瑚理解为等待，必须同时看文案与三点。
- 等待者仅依据明确业务状态：有效待回复报价、本人发起且仍 pending 的改期、已完成但未评价。校验/恢复操作不是“等待对方”；已关闭请求/预约不沿用 pending 改期颜色。
- Accepted Request 不继承关联 Booking 的待处理或等待状态。改期仍保持原预约有效，气泡颜色变化不推进阶段，也不更改进度条线段颜色、节点位置或行为。
- 底部标签只在列表显示，详情卡不重复；说明面板默认在进度条下。该规则替代此前白底珊瑚三点、雾紫和青瓷蓝绿的等待色方案。
- 当前仅用于 Flow Sandbox。正常 App、后端及原有生命周期校验未改。

- 概览与 The request 的加载占位复用实际布局。进度条骨架直接绘制同一个静态进度条，节点底边、气泡留位和动态字号都随正式内容布局。

### Groomer 沙盒独立按钮配色

同一页面状态最多使用一个实心珊瑚主操作。底栏按钮宽度和颜色均由主次位置决定；弹窗内部的风险语义另按下表处理。以下规则适用于 Request 和 Offer 详情、Pet profile 以及相关确认窗。

Groomer 沙盒中的卡片和胶囊按钮按下时保持静止时的面色，使用原有下沉、回弹或缩放反馈。切换标签成功后由选中状态决定颜色。

Request 底栏凸起按钮复用相同的底边深度，静止时按钮面与底影的相对亮度对比约为 2:1。主按钮珊瑚色底影用 #BB6558；不可用时沿用原样式整体 50% 透明度，不使用独立暖灰或核验灰色底影。

| 点击结果 | 外观 | 当前按钮 |
|---|---|---|
| 推进主要流程 | 珊瑚底、深棕字 | Send offer、Make a new offer、View waiting offers、预约已就绪的 View booking |
| 浏览辅助内容 | 白底、深珊瑚字、暖灰边 | Pet profile |
| 打开撤回或忽略确认窗 | 独占底栏时使用珊瑚主按钮；与主操作并排时使用白底无图标大胶囊副按钮 | Dismiss、Withdraw |
| 恢复或编辑 | 深珊瑚文字或图标；局部键盘按钮用白色圆底 | Refresh booking、Retry、金额键盘 |
| 忽略匹配、撤回未接受报价 | 执行动作作为上方珊瑚主按钮；保留原状作为下方暖灰文字副按钮；均无图标，不使用警示红 | Dismiss match / Keep match、Withdraw offer / Keep offer |
| 取消已成立预约等高风险操作 | 上方珊瑚主按钮保留安全选项；下方危险操作使用警示红文字；均无图标 | Keep booking / Cancel booking |
| 退出编辑确认或返回上一级 | 中性灰文字或图标 | Keep editing、关闭、返回 |

### 6.1 详情流程动效复用契约

`GroomingSandboxDetailInteraction.swift` 引用 Groomer 已有 Motion token、按压引擎，并提供局部输入动作和框外收键盘适配；不修改正式 DesignSystem，不新建按压或导航引擎。

| 层级 / 元素 | 当前规则与复用方式 |
|---|---|
| Groomer 沙盒 · 卡片或胶囊按钮进入详情页（已验收） | 所有此类入口统一复用 `SandboxNavigationButton`，包括 Grooming 列表卡片和详情内的 Pet profile。保留卡面或胶囊原色，按下即连续下沉（ease-out，90ms）。有效轻点由下沉动画完成回调触发导航，120ms 回弹与原生 NavigationStack 推入同时开始。已按到底时松手立即推入。各入口直接传入导航动作，时序由组件统一管理。 |
| 导航手势与辅助功能 | 触碰转为滚动时取消导航。开启减少动态效果或 VoiceOver 时，有效激活直接推入。详情页沿用 `beckonAllowsInteractiveBack` 支持交互式右滑返回。 |
| 详情与 Pet profile 的模块入场 | 共用 `DesignPage` / `BeckonCascade` 的 detail 节奏：85ms 间隔、最多延后 4 拍、30pt 上移；普通模块初始 scale 0.94、首模块 0.88。只在首次出现时播放，普通返回与刷新不重播。沙盒覆盖原比较入口的 `beckonRevealsInPlace = true`，让交互预览能看到真实动效 |
| 普通信息栏目、静态宠物头卡 | 跟随所属模块入场；不额外逐行跳动，不增加点击缩放，也不把不可点击内容伪装成按钮 |
| Start、Duration、留言栏目 | 整个表头及其留白仍可点击；移除胶囊、矩形及整栏染色，标题、正文、图标和编辑器不播放按压动画。只让右侧箭头由 Groomer Deep 短暂提亮为较亮珊瑚色，再恢复：叠加 Groomer Fill，最大混合 50%，保留箭头可辨识度。复用 `BeckonPressEngine` 的触碰与有效点击确认，快速点击或辅助技术激活也有反馈。颜色变化与同一箭头的 180° 展开旋转独立，不改变尺寸、位置或栏目布局；滚轮/输入框仍独立操作 |
| 展开滚轮、留言输入框 | 共用 `Motion.swap`：response 0.45、dampingFraction 0.7；内容以 8pt 纵向偏移配合透明度进入/退出，卡片布局随展开变化。状态变更只有原表单一个动画 owner，公共栏目不再叠加第二套隐式弹簧 |
| 留言展开与收起 | 开关动作同时决定展开状态与焦点，不在输入框 `onAppear` 再次抢焦点。点标题/箭头收起时清除焦点、保留草稿；失焦时收起仍打开的留言，不影响已切换的其他编辑器。标题/正文间距 4，标题/输入框间距 8；摘要淡入、标题 interpolate，图标/箭头保持固定编辑态锚点。输入文字不逐字弹跳 |
| Pet profile 按钮 | 沿用 Secondary 的原色下压与回弹，不另加缩放或震动 |
| 价格键盘按钮 | 不使用粉色光圈、背景染色或缩放；只保留键盘 / 收键盘图标以 **1.5 倍速** replace 切换。复用 `BeckonPressCountingBody`，点击立即触发，不等待动画完成；44pt 点击区、右侧 24pt 对齐列保持。Reduce Motion 时图标直接切换 |
| Send offer | 沙盒确认窗的浅珊瑚色摘要卡左列使用深色标签，右列统一右对齐。Service 行上方显示服务名，下方显示地点。When 行上方显示开始日期，下方显示带 AM / PM 的起止时段，跨午夜亦同。两行均采用详情页主文字在上、辅助小字在下的层级。分隔线下的末行显示报价。读屏提供完整起止日期。确认窗与提交使用同一份草稿，`Keep editing` 返回编辑。确认后由底部按钮显示发送状态，失败保留输入。C3-A 在确认前及实际发送前检查开始时间。需要重选时，滚到 Start 行，在该行的时间下显示原因。 |
| 按钮图标位置 | 底部操作栏主按钮统一先文字、后图标；加载圈与核验图标同样在文字右侧。双按钮布局的副按钮仅显示文字。底栏以外的普通动作按钮沿用前置图标。前往详情的方向箭头在文字后，可展开栏目的箭头在尾列。 |
| 底部发送类主按钮（2026-11-05） | Send offer、Propose time 及以后发送请求/提议的同类底栏主按钮统一使用 `paperplane.fill`，文字在左、纸飞机在右，复用 `SandboxFooterLabelStyle`。不得以 arrow.forward / chevron 代替发送语义；导航按钮仍可使用方向箭头。发送中右侧纸飞机替换为加载圈，核验中使用时钟；Modal 内按钮继续遵守无图标规则。 |
| 未就绪 / 无变化的禁用态（2026-11-05 已认可） | 复用 `SandboxRequestFooterActionStyle` 默认禁用态：`.disabled(true)`，整体透明度 0.5，按钮的形状、尺寸、字体、底边阴影几何和位置不变；不响应点击及有效点击反馈。适用于未修改、改回原值、输入无效或必要数据缺失。条件满足后恢复原色。不能仅改颜色但仍执行动作，提交入口仍须校验。此类禁用不设置 retainsDisabledColor；Checking… 同样使用珊瑚主按钮的 50% 透明度禁用态，保留 Checking… 文案和核验图标。只有实际 Sending… 保留原色及加载圈。 |

| Dismiss / Withdraw | 与主按钮保持既定正面高度和厚边反馈；破坏性操作不新增触感，确认框沿用 `DesignAlertDialog` 的入场/退出动画 |
| 资格核验中 | 底栏保留原位置，复用珊瑚主按钮整体 50% 透明度的禁用样式及短文案 `Checking…`，不再使用独立中性灰配色，读屏朗读 Checking availability。核验通过且表单就绪时显示可发送的珊瑚按钮。实际提交中沿用珊瑚底、`Sending…` 及右侧加载圈，锁定重复发送。 |
| 附加照片 | 保留既有按钮按压样式与照片颜色；打开后的图片 sheet 使用原生呈现与下滑关闭，不叠加详情页的模块入场 |
| 键盘 | 点击输入区外清除焦点；输入区和会改变焦点的按钮自行处理点击，页面手势不吞掉控件动作；继续支持滚动收键盘。键盘及底部操作栏保留原生/现有键盘联动时序，不套用展开弹簧 |
| Reduce Motion | 展开偏移取消，过渡降级为 0.15s 淡入淡出；按压位移/缩放、装饰循环由已有引擎关闭，颜色与文字状态仍保留 |

常规按钮和可展开箭头继续复用 `BeckonPressEngine`：触碰以 40% 反馈、0.07s 确认；按住 80ms 达到完整反馈，快速有效点击保留 70ms 完整反馈再恢复；转为滚动时 0.12s 淡退，不触发动作或震动。可展开栏目仅把这段反馈用于箭头颜色，没有整栏色块、位移或缩放；价格键盘按钮仍使用自身快速输入参数。原生 Button 负责手势取消，正式 App 的参数保持不变。

价格、留言及其展开/收起按钮通过 `sandboxKeyboardInputRegion` 登记点击边界；页面用同时识别的原生轻点手势收起区域外键盘，不添加覆盖输入框的透明按钮。**按下时**即排除原生文本框及登记的输入区域，不在抬手时用键盘弹起、自动滚动后的新位置重算同一次点击；未编辑时开始的点击也不能变成收键盘动作。

### 6.2 输入范围与显示边界

2026-11-04：仅约束本沙盒的 Request 详情报价输入；不修改正式 App 或已有顾客档案内容。

| 输入 | 限制 / 编辑行为 | 显示规则 |
|---|---|---|
| Price estimate | 普通金额输入，`99` 就是 99 元；0～9999.99，最多 4 位整数、2 位小数。编辑时显示原生闪烁光标，固定在末尾，仅允许末尾输入 / 删除，无选区或编辑菜单；复用系统小数键盘，超范围输入不接受 | 默认整数不带 `.00`，不自动补小数；主动输入 `99.5` / `99.50` 按输入保留。首次有效编辑前清空，空输入用淡色 `0` 占位；只是点开未输入就退出时恢复原金额，下次仍可从空开始。完成过编辑后再次聚焦保留金额；删空或仅剩小数点后退出也恢复本次编辑前金额。无千位分隔符，金额维持单行 |
| Add message / Messages | 最多 **200 个可见字符**，含空格、换行；组合 emoji 计一个字符。到达上限后不再增加，仍允许删除及选中替换；粘贴只接受剩余额度，保留未选中的原文字 | 收起最多 3 行；展开仍为正文列宽，输入框高 3～6 行，超出时内部滚动。无计数、无上限标签、无新增提示或震动 |
| Start / Service duration | 原生日期、时间、时长滚轮，不新增文本输入上限 | 沿用现有时间格式与滚轮尺寸 |
| Pet profile / The request / Your offer | 当前均为只读资料与报价记录，不截改源数据 | 保留普通栏目换行规则，不用输入限制代替显示布局 |

200 字符用于简短报价补充；字符上限不能独自保证不同语言和字号下的高度，因此同时限制编辑框可见行数及收起摘要行数。完整留言仍可展开读取。键盘输入的未提交组词不被截断，待提交后再执行字符限制。

上面的价格规则替代此前“固定两位小数”的方案，也不采用从分开始移位输入。原金额在首次清空时仍保留在报价草稿中；只有有效输入才同步新金额，因此直接点击 Send offer 不会因失焦回调时序而发送空值。价格保留 SwiftUI 的行框与基线，原生 `UITextField` 使用相同字号、字重和圆体显示文字与光标；通过零长度的 [selectedTextRange](https://developer.apple.com/documentation/uikit/uitextinput/selectedtextrange) 将光标限制在末尾。留言仍使用正常光标和选区，不受价格规则影响。

焦点归属：本沙盒的价格和留言使用 UIKit 控件，详情入口与报价编辑内页用普通 `@State` / `Binding` 保存目标，由原生编辑开始 / 结束回调同步。不要用没有对应 `.focused` 注册的 `FocusState` 驱动原生响应者；SwiftUI 原生字段仍按自身的 `.focused` 契约使用 `FocusState`。保留原生光标、框外收键盘、金额恢复和 1.5 倍键盘图标切换。

原生焦点切换必须离开 `updateUIView` 当前的 SwiftUI 更新事务：进入和退出编辑都排入主队列，合并重复请求，执行时读取最新焦点意图，防止过期请求重新弹出键盘。留言曾在 `updateUIView` 同步调用 `resignFirstResponder`，运行时采样确认重入视图图谱并卡住主线程；不能只扩大箭头点击区来处理这种卡死。展开后的箭头与表头执行同一个收起动作，同时清除焦点并保留留言草稿；框外点击沿用失焦收起。

复用已有 `BeckonTextInputLimit` 的替换限额逻辑；多行输入在沙盒内使用原生 `UITextView`，沿用现有输入框外观与正文约束。参考 Apple 的 [文本替换委托](https://developer.apple.com/documentation/uikit/uitextviewdelegate/textview(_:shouldchangetextin:replacementtext:)) 与 [markedTextRange](https://developer.apple.com/documentation/uikit/uitextinput/markedtextrange)，无新增依赖。

## 7. 复用边界与独立规则

### Groomer 沙盒 · 确认弹窗操作区

- 发送报价、撤回、忽略、取消预约、服务操作和改期等确认弹窗均使用带叉号的 Modal，不再按是否具有破坏性分成两套外观。旧确认工厂仅复用操作定义，不再展示无叉号 Alert。Booking 旧入口复用已有原型字段和回调，通过 `sandboxGroomingFulfillmentModal` / `sandboxGroomingRescheduleModal` 接入。
- 叉号仅退出，不提交决定；不清空所属表单草稿。操作确认窗禁止点击背景关闭，信息展示窗可显式开启 `allowsBackgroundDismissal`。Accept / Keep original 等业务动作与关闭严格区分。

- Send offer、改期、撤回、忽略等同款弹窗复用已有 `PrototypeDesignDialog` 展示，统一通过 `sandboxDesignModal` 展示 Modal，保留原有操作数据和回调；正式 App 不变。
- Send offer 确认窗标题为 `Send this offer?`，主按钮为 `Confirm`（无图标），副按钮为 `Keep editing`（无图标），不重复使用 Send offer 作为确认按钮文本。
- Groomer 弹窗必须同时传递 prototypeRole 与原组件的 beckonRole 到弹窗控制器；原按钮保持珊瑚底、深珊瑚文字与原阴影，不能回落到默认顾客薄荷色。
- 按钮放在统一操作区，不将 Keep editing / Cancel 混入摘要内容。上方为主按钮，下方为副按钮；两者均只显示居中文字，不放图标、不预留图标位置。高风险操作保留安全主操作；普通忽略匹配和撤回未接受报价不再标记为危险操作，执行动作放在主按钮。具体行为由操作定义决定，不由按钮排序推测。
- 关闭叉号保持 44pt 点击区，反馈圆直径 32pt，限于点击区内，距卡片边缘 8pt；120ms 淡入淡出，不放大到卡片边缘外。
- 主按钮原样复用 `BeckonLedgeButtonStyle(.pill)`；标签沿用原 `DesignActionLabel` 的字体、字号、颜色、内边距、最小高度和无障碍规则，仅移除图标，使文字自然居中。弹窗按钮采用纯文字是独立规则，不改变页面底部操作栏和胶囊按钮的图标规则。不得趁调整顺序更换外形、字体、阴影或按压样式。禁用条件、关闭后回调和确认后仅底部按钮显示发送状态的规则保持。

### 弹窗按钮 · 字体与风险语义（2026-11-05）

- 主、副按钮共用 `DesignTokens.Typography.Expressive.headline`：默认 17pt / black / rounded，随 Dynamic Type 缩放；居中文字且无图标。副按钮不再单独使用 15pt emphasis，保持原来的轻量文字按钮外观与最小 44pt 点击区。
- 主按钮维持 `BeckonLedgeButtonStyle(.pill)` 的珊瑚底、深棕字、圆角、阴影、高度和按压反馈。普通副按钮使用 `textSecondary` 暖灰字；高风险动作使用 `statusErrorText` 警示红字。颜色差异表达风险，主次差异通过实心与文字按钮表达，不靠随意换字号。
- 红色保留给会破坏已成立约定、造成实质损失或不可逆删除的动作，以及真实错误；不是“有后果就用红”。Dismiss 仅移除自己的匹配，Withdraw 仅撤回尚未接受的报价，不与取消已成立预约同级。
- 先确定风险和每个动作的结果，再选择主次；不要根据 `Dismiss`、`Cancel`、`Withdraw` 等单词机械套用危险样式。正常确认尊重当前操作意图，高风险确认突出保留原状。叉号始终只退出。

| 场景 | 上方主按钮（珊瑚底） | 下方副按钮 | 副按钮字色 |
|---|---|---|---|
| 发送报价 | Confirm | Keep editing | 暖灰 |
| 忽略匹配 | Dismiss match | Keep match | 暖灰 |
| 撤回未接受报价 | Withdraw offer | Keep offer | 暖灰 |
| 取消已成立预约 | Keep booking | Cancel booking / Cancel appointment | 警示红 |
| 接受改期 | Accept time | Cancel | 暖灰 |
| 拒绝改期并保留原时间 | Keep original | Cancel | 暖灰 |
| 正常服务操作确认 | 当前明确动作名称 | Cancel | 暖灰 |

这组规则只统一 Groomer 沙盒弹窗按钮，不改变页面底部操作栏、摘要信息层级、顾客端或正式 App。发送后的加载仍归页面底部按钮。

### 服务信息变更确认弹窗（已验收）

今后确认变更预约时间、服务项目、地点等服务信息时，沿用 Booking 的 `Accept time` / `Keep original` 弹窗格式：

- **标题和正文**：标题直接写本次决定。正文用一至两句说明确认后会发生什么，以及影响生效的必要条件。
- **生效信息**：正文下方单独展示确认后采用的值。接受变更显示提议值，保留原安排显示当前值。Groomer 沙盒复用 `DesignModal` 和 `SandboxServiceChangeSummary`：浅珊瑚底、标签在上、具体值在下。
- **日期和时间**：按服务地点时区展示，日期独占一行，时段另起一行；跨午夜时将起止两端分别按各自日期和时间排版。
- **操作**：主按钮命名对应具体决定，另设 `Cancel` 退出确认。以拒绝改期为例，`Keep original` 提交拒绝，`Cancel` 仅关闭弹窗。

### Groomer 沙盒 · Needs action 详情组件

Request、Offer、Booking 共用顶部卡的默认顺序：宠物身份、美容项目与档案按钮 → 进度条与气泡 → 行动或状态说明面板。时段之后依次排列 Service、Service location、Address，顾客留言在 The request 中列在最后；在 Appointment 中紧接 Address、位于 Your customer 上方。自动开始流程以 Booked time 为准。没有对应提示时省去面板及其间距。

列表与详情表达同一状态，但不强制同时出现标签与说明框。列表小卡底部的 `Needs action` 原因条仍对应详情的 `SandboxNeedsActionPanel`；普通状态标签可独立存在，只有详情需要补充原因、影响或必要指引时才显示 `SandboxStatusInfoPanel`。说明框和列表底条统一读取与对应气泡相同的 `SandboxStatusTone`；等待使用回应方角色色，其余按七类语义色表。面板用一句话说明发生了什么及其影响，标题可区别于列表短文案（例如 Time slot booked → Request still open）。统一使用 `SandboxCardStatus` 提供标签与说明，并以 `showsExplanation` 单独控制详情信息框，不影响列表标签、气泡和进度条。两种面板互斥，行动优先，详情卡底部不再重复任何标签。报价缺少时间资料时提示先撤回，再确认服务时间并重发；条款失效时提示先撤回，再核对当前请求并按新条款重发。

**信息框显示条件（2026-11-05）**

气泡与进度条负责当前阶段；信息框只补充它们无法表达的原因、影响或必要操作指引。不因“存在标签”自动增加信息框。

| 情况 | 详情展示 |
| --- | --- |
| Booking 已预约、几天后/明天/当天开始、服务中 | 不显示信息框；保留气泡、进度条与 Appointment |
| Booking 已完成待评价、已评价 | 不显示信息框；保留气泡、进度条与适用的评价入口 |
| 对方请求改期，需要本人决定 | 保留行动提示框与新旧时间、回复期限 |
| 本人已提出改期、等待对方 | 保留信息框，解释原时间仍有效；新旧时间与回复期限放在顶部信息框中，仅展示一次 |
| 取消、关闭、报价因预约冲突自动撤销等例外 | 保留信息框，解释原因及影响 |
| Request 的普通报价待回复 | 不显示重复的等待说明；保留气泡与 Your offer 中的报价信息 |
| Request 报价已接受 / Now in Bookings | 保留信息框，解释管理入口已经转到 Booking |
| 状态核验或无法确认 | 仅当阻碍当前操作且需要解释时显示；后台刷新不额外增加信息框 |

行动提示优先于普通信息框，两者不叠加。没有面板时移除对应间距，不保留占位。本规则取代此前“所有状态底条与详情信息框必须成对出现”的要求，仅作用于沙盒展示，不改变服务状态与操作流程。

**说明框与行动提示框排版（2026-11-05 已验收）**

`SandboxStatusInfoPanel` 与 `SandboxNeedsActionPanel` 共用 `SandboxExplanationPanel`，所有调用点复用以下参数，不在页面各自补缩进：

- 左图标列 20pt，图标列与文字列间距 8pt，四边内距 16pt；图标中心对齐标题第一行的水平中线（标题行参考高度 18pt，随 subheadline 缩放），不随整块正文高度居中。
- 每个面板只有一个主标题，由外层面板负责，并使用完整文字列宽度。嵌入的结构化组件不再重复主标题；例如改期只显示 `Time change request`，随后直接展示 Proposed time。`SandboxBookingTimeChange` 嵌入面板时设 `showsTitle: false`，独立展示时仍保留自己的标题。
- 右侧标题与全部正文共用左边界；标题至正文 6pt。标题沿用 Expressive.emphasis（15pt black rounded），普通正文沿用 Expressive.supporting（15pt semibold rounded），保留现有状态语义配色和圆角。
- 正文按可用宽度自然换行，高度自适应，不硬编码换行、不截断、不固定面板高度。标题例外：必须单行，采用下述短标题规则。
- **标题最多一行**：统一复用 `SandboxExplanationTitle`，优先用 2–4 个词表达状态或动作，不把完整说明句作为标题；人物、原因、后果留给正文或字段标签。保持 15pt black rounded，`lineLimit(1)`；仅窄宽度/大字号适配允许最低 85% 的缩放，不能以缩字或省略号代替文案精简，读屏保留完整传入标题。
- 已统一长标题：`Customer requested a time change` → `Time change request`；`You proposed a new time` → `Time change sent`；`Awaiting customer reply` → `Awaiting reply`；`Waiting for your customer` → `Awaiting review`；`Booked with another groomer` → `Booked elsewhere`；`Confirm accepted species` → `Confirm pet types`；`Timing details missing` → `Missing timing`；`Review service outcome` → `Review outcome`。服务状态的长描述不直接作为面板标题，使用 `Appointment booked`、`In service` 等短状态。
- 简单说明优先一至两句交代结果与下一步，例如 `Offer accepted. Tap View booking to manage the appointment.`；不在正文重复完整标题。
- 改期等结构化内容整体放进同一正文列，保留 Proposed time、Current appointment、截止时间等内部层级与分组间距，不把这些内容压成普通段落。
- 此规则仅应用于沙盒说明与行动面板，不改变普通信息栏目、列表底部状态条或正式 App。

**待处理改期时间对比（已验收）**

复用 `SandboxBookingTimeChange(booking:proposal:)`，传入同一预约及其待处理改期提议。顾客提出改期时，时间对比属于顶部进度条下的行动说明；美容师自己提出、等待顾客回复时，也将时段细节置于顶部状态信息框，不再放在 Appointment 底部。

- 需要本人回复的改期对比区使用淡金行动底；本人提出、等待对方的说明使用回应方角色色。标题说明发起人，`Proposed time` 突出提议日期和新时段，`Current appointment` 显示仍然有效的原时段，分隔线下说明谁需要在何时回复。
- 按服务地点时区排版。Proposed time 与 Current appointment 各自固定为“标签 → 开始日期 → 起止时间”三行；即使同日也各自显示开始日期。跨午夜不在时段中插入结束日期，起止两端都保留 AM/PM，读屏保留完整日期区间。
- 组件只负责展示。页面决定待处理状态、行动原因条与底栏按钮，接受、保留原时间和撤回继续走原操作流程。

### 可直接沿用的边界

1. 普通信息与可展开操作分为两种栏目。左侧图标与正文起点一致；只有后者扣除 36pt 的右侧操作空间。
2. 34pt 图标、56pt 栏目最小行高、44pt 最小点击目标分别命名；普通与可展开栏目共用行高，不共用不同含义的数据。
3. 箭头与图标共享水平中线；多行普通栏目随整行居中。留言编辑态保留固定表头锚点，不能泛化成所有模块都按整个展开区域居中。
4. 正文允许向下增长；最小高度不是固定高度。正文不得进入图标或箭头列，不能用缩字代替合理换行。
5. 价格、时间区间、身份头、进度条、照片组与操作栏都是登记的独立类型，不能任意照搬其中的字号、列宽或行高给普通栏目。
6. 外框对齐与内部文字对齐分别约束。输入框内部 16pt 留白要在设计稿中明确体现。

### 保留的区别，不作为新增待办

| 现状 | 对后续复用的影响 |
|---|---|
| 沙盒普通事实行与可展开行均已有可复用组件，参数归于 `SandboxDetailRowLayout` | Request detail 与 Pet profile 已统一接入；后续沙盒页面应选用这两类组件。正式 App 采用需单独授权，不直接移动为生产组件 |
| 留言收起时的标题/正文间距已与 Start/Duration 统一为 4；展开的标题/输入框仍为 8，表头上下留白仍为 8 | 收起正文与展开编辑器分开约束；不能把 8pt 编辑器间距套到收起摘要，也不能保证三行任意内容下等高 |
| 滚轮使用卡片内区，留言输入框使用正文列 | 必须记录为不同编辑器类型；若未来要求编辑器也统一正文边界，需另作明确调整 |
| 56pt 行高统一命名为 `minimumHeight`；`separatorInset` 为横线上下各 8pt，24pt 箭头列为 `accessoryWidth` | 普通与可展开栏目共用最小高度和栏间分隔，普通行仍不保留箭头空间；以后不能以点击尺寸代替图标或列宽 |
| 当前页顶部实际为 16，而 `Layout.pageTopInset` 定义为 24 但未被 `DesignPage` 使用 | 本表按当前 16 记录；不能直接从未使用的 token 推断当前视觉布局 |
| 40pt 价格和 Optional 系统斜体仍是沙盒特例 | 正式采用时应在既有设计规范登记其用途；本次不把它们扩大为全 App 字体规则 |

独立 Groomer 原型的请求列表、通知和场景预览共用同一个新版 Request 详情入口及当前预览会话。评审页的 Original 按钮单独保留原版对照。

这些是现有设计的适用边界，不增加实施任务或验收流程。修改同类栏目优先改共享组件；新增独立类型必须有实际布局或交互差异，不为每个字段另起一套数值。

## 8. 代码依据

- [普通事实行、Your offer](../../ios/Beckon/Beckon/FlowSandbox/Design/GroomingSandboxDetailRows.swift)
- [Request 概览、The request、时间区间、底部操作栏](../../ios/Beckon/Beckon/FlowSandbox/Design/GroomingSandboxRequestParts.swift)
- [C3-A 价格、展开行、留言](../../ios/Beckon/Beckon/FlowSandbox/Design/GroomingSandboxQuickOffers.swift)
- [填写和只读共用的价格栏](../../ios/Beckon/Beckon/FlowSandbox/Design/GroomingSandboxOfferPriceHeader.swift)
- [原生输入框与滚轮](../../ios/Beckon/Beckon/FlowSandbox/Design/GroomingSandboxRequestOfferForm.swift)
- [Pet profile](../../ios/Beckon/Beckon/FlowSandbox/Design/GroomingSandboxRequestCare.swift)
- [共享尺寸与字体](../../ios/Beckon/Beckon/DesignSystem/DesignTokens.swift)
- [共享页面、栏目卡片、图标与分隔线](../../ios/Beckon/Beckon/DesignSystem/DesignKit.swift)
- [共享输入框外观](../../ios/Beckon/Beckon/DesignSystem/BeckonFormPrimitives.swift)
- [沙盒动效策略与输入区外收键盘](../../ios/Beckon/Beckon/FlowSandbox/Design/GroomingSandboxDetailInteraction.swift)
- [沙盒价格格式与留言输入限制](../../ios/Beckon/Beckon/FlowSandbox/Design/GroomingSandboxOfferInput.swift)


### 预约前沟通 · 邀请与报价（2026-11-05）

**已采用的产品方向**：由一方先表达服务意向，另一方获得开启聊天的权限。Customer 发出有效定向邀请，受邀 Groomer 可主动联系；Groomer 发出有效 Offer，收到报价的 Customer 可主动联系。公共池匹配本身不授权聊天，发送报价也不自动授权美容师先联系顾客。首条消息发送成功后，双方正常交流，不设置首条消息配额、强制等回复或额外确认步骤。

**入口**：Groomer Request 的 The request 内，在 From the customer 下方显示 Your customer、顾客姓名与右侧 Message，复用普通信息栏目和现有胶囊导航按钮。Customer 的报价详情在美容师信息区提供相应的姓名与 Message 入口。姓名采用档案名称，不能用账号编号代替。

**有效性与退出**：邀请撤回、拒绝、关闭或过期，报价撤回、拒绝或过期，或请求关闭后，不得再凭失效记录开启新会话。尚无成功发送的消息时隐藏整个联系人栏目及其间距，不留下禁用 Message。只打开聊天窗口不算已经开始聊天。已有对话继续保留；发送时再次判断资格。若仍有另一项独立有效的授权，按该授权决定入口。Booking 成立后进入预约聊天规则，不能把接受报价误认为失去预约聊天资格。

**会话与信息边界**：同一请求、同一对参与者复用会话；重复邀请、重复打开不制造新会话。建立 Booking 后应继续已有对话，不另造历史。聊天授权不开放完整住址、联系方式或其他私密档案；地址仍遵守预约成立前后的显示规则。

**本次沙盒实现**：复用 PrototypeChatThreadView、ChatStore、普通栏目和导航按钮。SandboxRequestContact / SandboxRequestChat 只在进程内保存演示会话和消息，无网络、真实账号缓存或远程写入；首次发送决定会话是否已建立。两端预约前入口已接入原型。模拟器退出会丢弃演示消息。

**正式落地边界（T-466 已采用）**：正式代码复用会话仓库与参与者权限，服务器核验邀请/报价和失效状态；预约前与 Booking 复用同一双方会话。隐藏栏目仅是 UI 表现，不能替代服务端授权。独立沙盒继续使用模拟会话，不修改正式数据。


### Offer 独立记录与 Booking 单内变更（2026-11-05）

- 每次 Send offer 创建独立 Offer ID，价格、时间、有效期及状态归该 Offer；多份 Offer 仅共同关联原 Request，不设前后版本关系、不覆盖旧报价、不提供 View latest offer 或自动跳到另一份报价。打开哪个 Offer 就展示哪个 Offer。
- Offer 不支持编辑价格/时间。需要调整时先撤回，再从仍有效的原 Request 发送一份新 Offer。不得新建 Request 来改报价。同一美容师对同一 Request 最多一份有效待接受报价。
- 主动撤回的 Offer 从 Offers（含 Closed）排除，不显示撤回历史卡片。撤回成功后回到 Matches；Request 仍有效且可报价时可重新发出 Offer。Closed 留给被拒绝、过期等非主动撤回的结束报价；不按 Request 合并或只保留最新报价，避免把独立记录误当版本。
- Booking 仅开放开始时间变更；时长、宠物、服务项目、地点及参与者不变，沿用同一个 Booking ID，不新建预约。改期提议须经对方接受后生效，拒绝或撤回时保留原安排；取消、完成后不能改期。
- **价格是参考报价，不是应用内结算金额**。Beckon 不处理金额交易；实际费用由双方线下沟通和结算。Booking 保留接受 Offer 时的参考价格，只读展示为 `Price estimate`；不提供改价、价格确认、价格提议、价格变更记录或金额覆盖缓存。
- 此决定取代此前 Booking 改价设计。沙盒已删除改价入口、双方预览及本地提议模型，恢复复用原 Manage booking 与改期流程；Offer 的独立记录、撤回后重新发送及撤回不进 Closed 的规则不变。


### 改期输入与提交保护（2026-11-05）

改期窗口默认展示原定开始时间，不预先替用户加一小时。按选择器的分钟精度比较实际时间点（含日期及服务时区解析），未改变或改回原时间时禁用 Propose time，点击提交亦校验；沙盒仓库再次拒绝同时间申请，不生成提议或通知。无效时间继续沿用现有检测。

美容师提交后，顶部状态说明框标题为 Time change sent，复用 SandboxBookingTimeChange 的 Proposed time、Current appointment、简短回复期限，使用顾客等待配色。Appointment 只展示当前生效时间，不重复提议内容。顾客提出改期仍使用顶部行动提示框，两者共享结构化内容和单行标题规则。


改期不得选择过去日期或当天已过去的时间：以服务地点时区解析后的实际开始时刻与提交时的当前时间比较。原生滚轮通过 DatePicker 的 `in: minimumStart...` 设置下限，下限取当前时刻后的下一个整分钟，过去时间不可选并由系统处理边界回位；不弹过去时间 Toast。冲突按完整服务区间判断，不只比较开始时刻；排除本 Booking 和取消/已完成预约，仅检查同一 Groomer 的有效预约，前一单结束恰好等于后一单开始不算重叠，不添加缓冲时间。提交冲突时使用统一底部 Toast：`This time overlaps another booking. Please choose a different time.`；保留改期窗口和草稿。沙盒仓库在提议和接受时再次用完整本地预约集校验，防止仅靠页面分页缓存漏判。窗口仅在提交成功并读到对应待回复提议后关闭。此为沙盒规则实现，不声称已部署正式后端校验。


改期信息框精简版（2026-11-05）：已发送与待处理均复用示例的三组信息——Proposed time（日期、时段）、Current appointment（日期、当前时段）、Reply by（截止时间）。已发送状态移除重复的整句解释与 Customer reply due 长标签，等待语义由标题、气泡和顾客主题色表达；原时间在接受前仍有效的说明保留在发起改期窗口。新旧两组始终各自显示开始日期和时段，不因同日省略日期；时段只写 `11:00 PM – 1:00 AM` 这类带两端 AM/PM 的内容，不拼接结束日期。保留新时间强调、当前时间次要的字体层级及既定间距。此规则仅适用于改期信息框，不改变 The request 的 Preferred time 时间线或其他弹窗；数据与校验仍使用完整起止日期。


改期窗口 Current appointment（2026-11-05）：改用 SandboxRequestFactRow，置于与 Proposed start、Service duration 相同的 SandboxDetailRowGroup；恢复普通白底、34pt 日历图标、12pt 图文距、56pt 最小行高、图标对齐栏目水平中线、4pt 文本间距及统一横线。此栏目正文是独立排版例外：日期沿用 Expressive.emphasis，下一行时段沿用 Expressive.headline，使用可覆盖的 valueFont / detailFont / detailColor，不改变其他普通栏目的默认样式。始终展示开始日期 + 带两端 AM/PM 的起止时间，不拼接结束日期；读屏保留完整区间。移除该位置原有粉色 SandboxServiceChangeSummary，确认弹窗内的摘要组件不受影响。


改期滚轮交互补充（2026-11-05）：Proposed start 整个栏目注册为输入区域，页面复用 sandboxDismissKeyboardOnOutsideTap；点击栏目外（含静态栏目和空白）按既有展开动画收起，栏目内滚动不收起，箭头仍可切换。选择器绑定实际 Date 并设置服务地点时区，复用系统日期/DST 处理，不再用 UTC 伪墙钟或额外重复时段选择器。最小日期在展开、回到前台、窗口停留期间及提交时更新；若提交前时间已过，先校正并保留窗口供用户确认，不静默发送新值。预约重叠只在点击 Propose time 时检查并显示统一 Toast；滚动时不检查冲突、不弹 Toast。其他提交失败用窗口内错误说明，不混用冲突提示。参考 Apple [DatePicker](https://developer.apple.com/documentation/swiftui/datepicker) 的范围限制与 [UIDatePicker.minimumDate](https://developer.apple.com/documentation/uikit/uidatepicker/minimumdate)。


Appointment 的 Booked time（2026-11-05）：复用 SandboxRequestFactRow 普通栏目，不再使用 From/Until 时间线。正文固定为两组文本：开始日期、起止时间（两端 AM/PM），跨午夜不拼接结束日期；两行沿用 Time change 信息框 Current appointment 的 Expressive.supporting 与 textPrimary。图标、标题、正文列和间距遵守普通栏目规则，完整日期区间保留在数据及读屏描述中。Request 的 Preferred time 随后也采用同一两行时间栏目。

共享预约时间栏目：`SandboxBookedTimeRow` 统一供 Booking 详情 Appointment、Booking 生命周期预览和 Propose new time 的 Current appointment 使用，内部复用普通信息栏目及 `SandboxRequestTimeLabels`。日期与时间默认均为 supporting；改期窗口保留已确认的 emphasis/headline 特例。信息框继续使用同一日期格式化来源，Request 详情的 Preferred time 同样复用此组件，保留自己的标题和骨架状态；列表、聊天卡片的紧凑摘要不套用此栏目布局。

改期发送反馈：确认提交成功且读到对应待回复提议后，关闭改期窗口，在 Booking 详情统一底部 Toast 显示 `Time change request sent`；取消或失败不显示成功反馈。美容师主动提议改期的 Booking 列表标签复用 Offer 的等待格式：`Awaiting reply · Expires {deadline}`，使用提议的实际 expiresAt 和服务地点时区，等待色沿用顾客主题色。

Grooming 主标签切换：手动切换 Matches / Offers / Bookings 时，同一次状态更新中将目标子标签恢复为 All / Waiting / Active。再次点击当前主标签或从详情返回不重置子标签；刷新不自动切到 Accepted，避免覆盖用户选择。复用原 Store、缓存及列表，不因重置筛选重建数据。

底部操作栏颜色统一（2026-11-05）：主按钮一律使用 Send offer 同款珊瑚底、深棕字和珊瑚底边阴影；单独出现的 Withdraw、Dismiss、Withdraw change、Cancel appointment 也遵守此规则，管理操作不因此新增触感。双按钮中的副按钮仍为白底大胶囊、无图标。未就绪和 Checking… 复用 50% 透明度禁用态，不替换文案；实际发送中为保色加载态。此规则覆盖早期暖灰管理按钮和独立灰色 Checking 按钮方案，不改变说明框、气泡和列表标签的状态色。

撤回改期确认窗：复用服务信息变更 Modal 与 SandboxServiceChangeSummary。标题 `Withdraw time change?`，正文 `Your proposed time will be withdrawn. The appointment below stays booked.`，仅展示 Current appointment 的当前预约日期和时段，不重复列出旧/新两组时间或流程解释。上方珊瑚主按钮 `Withdraw`，下方文字副按钮 `Cancel`，均无图标；叉号和 Cancel 只关闭窗口。

Booking Activity（2026-11-05）：沙盒只展示 Booked、改期申请及处理结果、Finished、Reviewed、Cancelled。首行为操作名及必要的 You/Customer，下一行为操作发生时间；仅改期申请记录展示 Current/Proposed 新旧服务时间；接受、拒绝、撤回仅显示操作名称、操作者和操作时间，过期仅显示名称和时间，不重复时间摘要或解释。按线性操作记录阅读结果，原申请摘要始终保留。不展示自动 Service started、重复结束记录、内部状态和长说明。保留按发生顺序、折叠展开及展开后滚动展示；仅一条 Booked 也可查看。改期成功操作在现有沙盒内存仓库逐次记录，不以最新提议覆盖历史，不写正式数据。Manage booking 移除中断、未到场、未完成、结果确认等旧流程入口，仅保留可用的改期和取消；完成和评价保留在底部操作栏。

沙盒组件维护（2026-11-05）：当前 C3-A 使用 SandboxCurrentOfferForm，正式沙盒流程直接调用；历史方案比较中的 C3-A 也调用同一组件。旧 A–F/C1–C4/C3-B 仅留在比较入口，复用输入控件、草稿及基础栏目，不反向控制当前流程。Booking 的需操作提示仅保留当前支持的改期处理，不再产生 Start service / Close out service / Review service outcome 或 Service report。跨午夜确认弹窗仍保留原特殊排版，本次不作视觉更改。


## T-466 正式采用边界（联调中）

本次用户已授权将 Groomer Grooming、Request / Offer 详情及内页、Booking 详情采用到正式客户端。沙盒继续独立编辑；正式代码不引用 `FlowSandbox`、测试账号或假成功结果。外观以本文已确认规则为准，不因后端适配重新设计。

- 正式所有者：`Features/Groomer/Grooming/`；通用行布局、气泡外形、按钮外观和列表按压样式在 `DesignSystem/GroomerVisit/`。`Sandbox…` 的对应正式组件使用 `GroomerVisit…` 前缀，数据读取和业务提交复用现有 Store / Repository。
- Home、Schedule、通知仍通过现有详情入口进入同一套正式页面；Grooming 使用角色壳层的导航栈。Request 联系人按钮只提出打开会话请求，导航目的地由壳层注册，不放在懒加载栏目内部。
- 顾客端只同步必需的服务完成／评价权限和报价联系入口；不采用 Groomer 的页面配色或布局。共享样式通过明确的 Groomer 环境开关启用，原有顾客默认值保留。
- 列表以服务端过滤后分页，保留已显示的数据再刷新；图片复用已有缓存，仅补当前新增页的图片。已读标记按账号保存，退出账号时清理。
- 验收进度见 T-466 计划。后端已获授权部署；技术验收证据记录于计划，用户视觉验收单独保留。
