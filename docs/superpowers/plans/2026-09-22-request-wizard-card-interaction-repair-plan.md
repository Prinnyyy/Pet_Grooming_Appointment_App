# 创建需求与美容师卡牌交互修复计划

> **For agentic workers:** 使用 `superpowers:executing-plans`，当前执行者连续完成各包；项目禁用subagents。复选框代表实施验收，不是逐项暂停或提交的边界。用户已采用本计划，由T-401实施。

<!-- task-artifact
task: T-401
status: completed
type: plan
-->

**Goal:** 消除宠物选中前后的文字位移，固定创建流程顶部进度模块，将平移分页改成可反复浏览的倾斜卡牌组，并修复尾卡重复弹窗及跳变。

**Architecture:** 保留Wizard、DiscoveryStore、FavoritesStore、DistributionStore和PublicationCoordinator的原职责。只调整视图布局及本地浏览位置/动画状态；卡牌组件不拥有交易、候选分页或收藏业务。顶部进度模块提取到Requests feature；卡牌交互留在Discovery feature，不扩建全局DesignSystem。

**Tech Stack:** 既有Swift 6、SwiftUI、iOS 18+、DesignTokens、Swift Testing/XCTest及Simulator。无需第三方依赖、数据库迁移或新后端接口。

**Spec:** 本文第1至3节承接2026-09-22用户实测反馈，并细化[原发现与邀请设计](../specs/2026-09-21-request-discovery-invitations-design.md#22-推荐轮播)。采用后，仅替换原“原生分页轮播”的视觉/交互实现；原定显式发送、滑动不pass、不弹尾页模态的规则不变。

**状态:** T-400编写计划，T-401于2026-09-22完成实施及本地验收。实现基线 `a519c396`；实际证据见第6节，不将T-399的业务测试通过当成本次布局或动画通过。

## 1. 范围与问题定位

| 用户反馈 | 当前源码依据 | 修复边界 |
|---|---|---|
| 长字段选中后文字位移 | `CustomerRequestWizardView.swift` 的 `CustomerRequestPetChoiceCard` 把品种和重量拼成一个subtitle；`if isSelected`才插入42pt勾选控件，改变文字可用宽度 | 品种与重量分行，同时永久预留选择指示位置；不能只拆字符串而保留挤压源 |
| 顶部进度随页面滑动 | 同文件把 `CustomerRequestWizardHeader` 放在 `ScrollView/LazyVStack` 内，且滚动回顶锚点绑在Header | Header移到滚动区域外，建立固定顶栏与内容分隔；回顶锚点移回内容内部 |
| 看起来是左右分页，不是卡牌 | `CustomerGroomerDiscoveryView.carousel` 使用 `.page` TabView和固定510pt区域；内容缺少完整卡面与层叠/倾斜反馈 | 用有边界的实体卡面与可逆卡组替代TabView，保留资料、发送和收藏组件 |
| 尾卡重复提示、反向滑动跳变 | 尾页按钮和selected ID变nil均触发 `confirmsFullList`；尾页使用 `Optional<UUID>.none`，`showAll()`又把nil重设为最后一位 | 明确建模尾卡，移除自动confirmationDialog，不在滑动中导航或重设ID |

前三项及重复弹窗可由源码确认；尾页卡顿的具体主线程/绘制耗时尚未测量，不能把所有卡顿都归因为TabView。实施时用开启动画的短序列复现并测量。

原设计2.2已经要求“尾页不再次弹模态确认”；当前弹窗是实现偏差，不是新增业务需求。既有UI测试使用 `Show All Groomers.firstMatch`，无法区分尾卡按钮与弹窗按钮，还缺少拖动中间帧/选中前后几何检查，本次须补上这些遗漏。

另已确认 `TestOpsUIFlowDriver.launchSignedOut` 默认加入 `--beckon-testops-disable-animations`。既有通过证据不能证明真实动画顺畅；本计划必须显式开启正常动画，且记录该启动参数确实未出现。

### 不改变的内容

- **Saved Groomers按钮保持当前页面、当前相对位置**，Account收藏入口也不移动；不新增首页收藏模块。
- 推荐仍为 `min(8, 可展示候选数)`；不足不凑数。左右滑只浏览，不能pass、收藏、发邀请、加入池或改评分/偏好。
- 填完需求进入私有预览不等于已发布；只有Send Request的明确确认或Publish to Request Pool才发布。卡牌浏览不修改这条边界。
- 需求池默认关闭、接收人数上限、权限、排序、分页、发布幂等、报价及Booking规则均不改。
- 保留真实头像及现有缺图占位，不引入虚构作品/评分，不为卡面另建素材接口。
- 本轮仅本地客户端修复和Simulator验收；不操作远程数据、安装库、改签名或把测试计划执行成真实订单。

## 2. 交互设定

### 2.1 宠物选择卡

正常字号布局：左侧既有头像；中部从上到下是**名字、品种、体重**；右侧选择指示槽。

- 品种为空沿用species回退；重量缺失时不伪造数值或显示空单位。姓名和品种允许按可用宽度自然折行。
- 右侧42pt指示槽始终参与布局，未选中仅隐藏图形/背景，不删除槽位；隐藏图形不单独进入辅助功能树。
- 选中只改变勾选、背景、边框颜色，不改变头像尺寸、字体粗细、padding、文字宽度或卡片高度；不对选中状态施加整体布局动画。
- 大辅助字号改为头像在上、文本在下，指示槽预留在头像一行；不同字号可改变结构，但同一字号下选中前后结构不变。
- 不采用选中后才缩小字体、强制单行或截断品种来掩盖问题。卡片可因数据长短增高，但不能因是否选中增高。

### 2.2 固定进度模块

```text
Sheet安全区
  固定顶栏：Grooming Request + 进度轨道 + Step x of n
  一条分隔线
  可滚动：当前步骤标题/说明 + 表单内容 + 错误提示
  既有底部Back/Continue操作区
```

- 使用外层 `VStack(spacing: 0)`：独立 `CustomerRequestWizardHeader` + Divider + 原内容ScrollView。顶栏为全宽实色带，不做悬浮卡片或透明遮盖。
- 顶栏高度由内容/系统字号决定，不写死高度；“固定”指不参与内容滚动，不是把大字号文字裁进固定高度。
- 步骤变化只更新进度/步骤文字，并将**下方内容**滚到内部顶部锚点；不再滚动Header，不重建整个NavigationStack。
- 复用现有 `beckonKeyboardAvoidance`、`beckonStationaryPageAction`及底部高度补偿，补偿只作用于内容一次；不顺带重写全App键盘逻辑。
- 键盘、错误提示、地址候选、前进/返回和打开/关闭Discovery后，顶栏均保持在当前容器安全区顶部。允许系统Sheet本身移动，不以抵消整个Sheet位移的方式“固定”。

### 2.3 真正的可逆卡牌组

**外观：** 正面卡有完整surface背景、既有card圆角（当前24pt）、细边线、轻阴影；下一张卡的边缘从底部露出，最多渲染当前/相邻/底层三个卡面。页面本身不加大外框，不做卡片套卡片。

- 卡片沿用安全资料、距离、参考价、匹配证据、详情与发送/收藏按钮；复用 `GroomerCandidateSummaryView`、`GroomerCandidateActionsView`，不复刻列表/详情业务。
- 卡面宽度由当前容器约束，左右保留旋转留白；默认高度目标约500pt，紧凑屏/大字号可调，**同一窗口内切换卡牌不得因字段长短或图片加载改变外框尺寸**。
- 详细文字溢出时在卡面内容区纵向滚动；动作区留在卡面底部，内容为其预留空间，大字号按钮纵向排列。整页原有池状态、进展和Saved Groomers仍可到达。
- 保留固定图片占位。图片晚到只替换同尺寸区域，不改变文字和按钮位置；不可为了拖动效果反复解码/请求头像。

**动作：** 左滑到下一位，右滑到上一位；当前卡跟手平移并绕下部轻微旋转，相邻卡自然接替。反向浏览不是撤销业务操作，推荐数组不删除、不重排。

| 参数 | 首版实现值/约束 |
|---|---|
| 手势意图 | 12pt以上开始判定；水平位移明显大于竖直（1.25倍）才锁定横向，方向锁定后到结束不反复切换 |
| 转角 | 与水平位移成比例，限制在正负8度；左右对称，无随机角度 |
| 换卡 | 实际横移达到卡宽22%，或在已有明确横移的前提下预测落点达到35%；不足则回弹 |
| 背景卡 | 约0.96/0.92缩放、8/16pt垂直错位；仅视觉，不参与焦点/点击 |
| 动画 | 约0.30秒有阻尼回弹/接替；使用完成回调与transition token，不用任意asyncAfter计时推进索引 |
| 边界 | 第一张向右、尾卡向左最多约24pt阻尼位移并回弹，不循环、不导航 |

这些值是可测的实现起点；可依据同机手感微调，但不得删除倾斜、往返、单步推进或边界规则。

**手势冲突：** 不能只在onChanged中忽略竖向数值，却让横向recognizer抢走ScrollView。先用原生SwiftUI组合验证方向锁定：纵滑必须交给当前卡内容/页面，横滑仅在锁定期间抑制相关滚动；按钮轻点不触发拖动。卡内竖滚到边界后页面仍可继续滚动，不锁死Saved Groomers。若原生组合在当前iOS版本确实失败，限定为本组件的UIKit方向识别桥接，不升级成全局手势框架或引入第三方库。

**状态与取消：** 卡牌稳定位置由DiscoveryStore按ID拥有；View仅持有拖动offset、方向和进行中transition。一次手势最多换一张；动画中不重复提交索引，也不触发被移出卡的Send。退后台/退出页面/换scope/硬资格失效时取消手势，旧动画回调不能写回新页面。软刷新保留仍存在的当前ID；当前ID消失时取消动画并在新结果稳定后选第一张，不能把旧索引套在新数据上。

**无障碍：** 提供上一张/下一张SF Symbol按钮（至少44pt点击区、可访问标签）和VoiceOver命名动作。读取当前卡及页码，不读取背后卡。Reduce Motion下不旋转、不弹性甩出，以短淡入/小位移换卡；导航和发送规则完全相同。

### 2.4 尾卡与完整列表

- 序列固定为 `美容师1...美容师N -> more`；`more`是独立稳定身份，不再拿nil同时表示“未选中”和“尾页”。零候选沿用空/检查中/错误状态，不造尾卡。
- 最后一张左滑，像普通换卡一样进入同尺寸尾卡。尾卡只保留一个 `Show All Groomers` 按钮；**到达尾卡不弹气泡、不弹对话框、不自动打开列表**。
- 尾卡右滑回最后一位，最后一位右滑回倒数第二位；整个序列连续，不通过程序选页制造跳转。尾卡继续左滑只回弹。
- 点击尾卡按钮即是明确确认，直接打开既有完整列表；原顶栏列表图标作为快捷入口保留，无任何二次确认。
- 进入列表不重取已加载的前25项、不丢游标，不重建DiscoveryStore。返回恢复入口位置：从普通卡进入恢复该ID，从尾卡进入恢复尾卡；尾卡再右滑仍是原最后一位。这一细化取代旧测试“从尾卡返回强制选最后一位”的行为。

## 3. 路线与参考

| 路线 | 判断 |
|---|---|
| 仅给TabView页面加背景/rotationEffect | 变更少，但分页和空ID尾页仍牵制跟手/可逆状态，难根治当前交互问题，不采用 |
| 直接引入第三方刷卡库 | 演示接入快，但本项目需可往返、不消费候选、硬刷新取消和共享业务状态；为这些适配引入依赖不划算，不采用 |
| **原生Feature级可逆卡组** | 推荐；保留现有Store/资料/动作，仅实现有界位置、方向判定及卡面变换，不做通用卡组SDK |

参考已查阅的项目：[dadalar/SwiftUI-CardStackView](https://github.com/dadalar/SwiftUI-CardStackView)提供层叠/方向判定示例，也明确指出内部索引遇到数据重排的限制；[HanlunWang/CardStack](https://github.com/HanlunWang/CardStack)展示绑定索引、缩放、旋转和手势配置。这里只借鉴交互组合，不照搬“刷掉一张”的数据模型，不直接安装或复制其实现。必要API依据为Apple的[DragGesture](https://developer.apple.com/documentation/swiftui/draggesture)与[Reduce Motion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion)。

## 4. 实施包与职责

以下 `Features/` 相对 `ios/Beckon/Beckon/`，`BeckonTests/`、`BeckonUITests/` 相对 `ios/Beckon/`。新增名字是待实施文件，不表示当前已存在。

### UI-01 稳定选择布局与固定顶栏

**修改：** `Features/Customer/Requests/CustomerRequestWizardView.swift`、`BeckonTests/CustomerRequestFeatureTests+WizardPresentation.swift`。

**新增：** 同Requests目录 `CustomerRequestWizardHeader.swift`；`CustomerRequestWizardLayoutTests.swift`放在BeckonTests内，使用已有Fake/原生UIHostingController验证几何，不另建snapshot框架。

**接口：** Header仅消费 `currentStep: CustomerRequestWizardStep`，不读取Repository；原flow.currentStep和前进/返回逻辑不改。

- [x] 先记录同一长字段卡选中前后文字/外框几何及进度滚动位置的失败证据。测试数据：长名 `Sir Bartholomew Wellington the Third`、长品种 `Australian Shepherd / Standard Poodle Mix`、重量72.5，以及无breed/无weight、同species的另一只宠物。
- [x] 分开breed和weight，稳定选择槽及文字宽度；大字号布局独立于isSelected。给需要比较的元素稳定ID，不用species单独识别多只同种宠物；保留现有driver依赖的入口或同步改定位。
- [x] 抽取现有Header并移出ScrollView；为内容设置专用顶部锚点。保留底部动作补偿与键盘逻辑，检查focus滚动不把内容藏到顶栏/底栏后。
- [x] 验收R01-R05；针对性运行WizardPresentation/布局测试后继续UI-02，不在此处跑整套后端或另写长报告。

布局核心示意（不是本轮产品代码）：

```swift
VStack(spacing: 0) {
    CustomerRequestWizardHeader(currentStep: flow.currentStep)
    Divider()
    // 原ScrollViewReader、内部顶部锚点与表单ScrollView放在这里。
}
// 指示槽始终存在；opacity仅作用于槽内图形，不移除槽。
```

### UI-02 可逆卡组及单一尾卡入口

**修改：** `Features/Customer/Discovery/CustomerGroomerDiscoveryView.swift`、`CustomerGroomerDiscoveryStore.swift`、`CustomerGroomerListView.swift`（仅必要位置恢复接线）、`BeckonTests/CustomerGroomerDiscoveryTests.swift`。

**新增：** 同Discovery目录 `GroomerDiscoveryCardDeck.swift`（卡面/手势/动画）与 `GroomerDiscoveryDeckState.swift`（位置/边界/纯决策）；`BeckonTests/GroomerDiscoveryDeckTests.swift`。

**复用：** MarketplaceGroomerSummary、GroomerCandidateSummaryView、GroomerCandidateActionsView、CustomerMarketplaceSession头像缓存、所有发送/收藏闭包。卡组消费recommended，不持有第二份业务数组，不改Repository协议。

明确新增接口，按此写测试后实现：

```swift
enum GroomerDiscoveryDeckSelection: Equatable, Hashable {
    case groomer(UUID)
    case more
}
enum GroomerDiscoveryDeckDirection { case previous, next }
enum GroomerDiscoveryDeckPolicy {
    static func destination(from: GroomerDiscoveryDeckSelection,
        direction: GroomerDiscoveryDeckDirection,
        groomerIDs: [UUID]) -> GroomerDiscoveryDeckSelection
    static func committedDirection(translation: CGSize,
        predictedEnd: CGSize, cardWidth: CGFloat) -> GroomerDiscoveryDeckDirection?
}
// Store.deckSelection: GroomerDiscoveryDeckSelection?；nil仅表示无候选。
// Deck输入稳定selection binding、当前候选及原动作；不可自行调用业务仓储。
```

- [x] 先测0/1/3/8候选、取消/快滑、前后边界、more往返、刷新移除当前ID及旧动画回调，确保没有网络/发送副作用。
- [x] 用deckSelection替换当前selectedGroomerID的空值复用，更新所有本地调用和测试；删除TabView、confirmsFullList及尾页confirmationDialog，禁止保留两套活跃位置状态。
- [x] 完成实体卡面、相邻层、倾斜跟手/回弹/接替，绑定手势到卡面而非整页；按钮和竖滚通过第2.3节规则仲裁。
- [x] showAll/showRecommendations只管理导航，不重置deckSelection；普通卡和尾卡进入列表后均有确定返回位置。首次发送后的preview别名继续保留同一位置。
- [x] 验收R06-R15，开启真实动画。动画正确且状态稳定后才微调阴影/角度，不以关闭动画“解决卡顿”。

示例断言：

```swift
let ids = [UUID(), UUID(), UUID()]
#expect(GroomerDiscoveryDeckPolicy.destination(from: .groomer(ids[2]),
    direction: .next, groomerIDs: ids) == .more)
#expect(GroomerDiscoveryDeckPolicy.destination(from: .more,
    direction: .previous, groomerIDs: ids) == .groomer(ids[2]))
#expect(GroomerDiscoveryDeckPolicy.destination(from: .more,
    direction: .next, groomerIDs: ids) == .more)
#expect(GroomerDiscoveryDeckPolicy.committedDirection(
    translation: CGSize(width: 8, height: 100),
    predictedEnd: CGSize(width: 12, height: 150), cardWidth: 320) == nil)
```

### UI-03 集成、动效验收与收尾

**修改：** `BeckonUITests/TestOpsRequestDiscoveryTests.swift` 的浏览/尾页断言，`TestOpsUIFlowDriver.swift` 的动画开关及必要稳定定位；受影响的Design System条目、本计划及Current State。

驱动仅增加一个向后兼容参数：`launchSignedOut(disablesAnimations: Bool = true, additionalArguments: [String] = [])`。现有业务测试保留原默认，本次动效测试明确传false；不得全局删除既有快速测试选项，也不能仅追加相反flag却留下原disable参数。

- [x] 复用本地Fake与UIHostingController覆盖长字段、缺图、0/1/8候选，不为边界造远程账号。Simulator关键交互沿用现有TestOps驱动；若必须准备真实预览夹具，仅限经授权的最小测试账号业务数据并精确恢复，不重新播种26账号/1200评价。未授权远程写时不暗中调用prepare RPC（它也会写私有预览）。
- [x] 旧 `firstMatch` 文案选择改为尾卡稳定ID `discovery.more`；明确断言无alert/confirmationDialog。测尾卡反向拖回，不以“成功进入列表”代替尾页交互通过。
- [x] 实现上述单参数，确认动效测试的app.launchArguments不含disable-animations，普通动效组系统Reduce Motion关闭；降动效组另测，不把两组证据混用。
- [x] 在紧凑17e和较大Pro Max上串行运行：默认字号、最大辅助字号、Reduce Motion、键盘开关及VoiceOver标签/动作。无须真机或上架条件。
- [x] 只保留宠物选中前/后、固定Header滚动前/后、卡组静止/中间倾角及尾卡的关键截图；另录一段正常动画连续往返短视频。XCTest语义/手势控制，不以每步截图驱动。
- [x] 同一模拟器、同字号/图片状态下测首轮与预热后各20次连续往返；不允许重复业务写、索引跳过、拖动中返回其他卡或单次手势结束后超过0.5秒仍不稳定。目标完成落位约0.30秒；如有可见停顿或达不到门槛，使用一次范围限定的Animation Hitches/Time Profiler定位，不新建性能平台，也不将低采样录像冒充60/120fps证明。
- [x] 最终集成节点串行运行 `./scripts/ios-build.sh`、`./scripts/ios-test.sh`、`./scripts/preflight.sh`；一次完整回归即可。此次不改后端规则，不重复未变的权限/成交/26人性能压测。
- [x] 执行hygiene/diff检查，记录修复、实际UI证据及限制；全部验收后按已有Git授权一次完成提交/推送当前工作分支。保留历史脏文档、签名和Light设置，不创建PR/合并。

## 5. 验收矩阵

| ID | 必须成立的结果 | 证据/归属 |
|---|---|---|
| R01 | 长名/长品种/正常与缺失重量；选择另一只再选回，体重位于品种下方 | 原生布局+UI，01 |
| R02 | 同一viewport/字号/数据下，选中前后name/breed/weight文字框及卡外框位置/尺寸差不超过1pt；无新增折行 | 几何比较，不只截图，01 |
| R03 | 默认/最大辅助字号下选择不会挤压指示槽，名称可读，VoiceOver能说明选中状态 | 原生布局+UI，01 |
| R04 | 每一步竖滚后Header屏幕Y不变（1pt容差），表单内容Y确实变化；分隔线之下无遮挡 | XCTest/布局，01 |
| R05 | 前进/返回回到内容顶端；地址/备注键盘、错误提示、底栏、Discovery返回正常 | 既有Wizard测试+UI，01 |
| R06 | 有完整卡面、可见下一卡边缘；拖动中角度非零且不超过8度，回位无尺寸跳动 | 开启动画视频/关键帧，02 |
| R07 | 0/1/3/8人完整往返；每手势至多一位，不删除/重排候选，第一张不循环 | Unit+UI，02 |
| R08 | 微拖回弹、快滑换卡、竖滑不翻卡、按钮轻点不拖卡；卡内/页面纵滚都可用 | Unit+真实手势，02 |
| R09 | 到尾卡无弹窗/导航，尾卡只有一个查看列表按钮；同尺寸、不突跳 | UI，02 |
| R10 | 最后一位左滑到more，more右滑回原ID；越界只回弹；连续20次无跳号/冻结 | Unit+动画测量，02/03 |
| R11 | 列表保留缓存/完整候选；返回普通卡或more入口位置，收藏/邀请覆盖状态不丢 | Store+UI，02 |
| R12 | 发布前后浏览位置不重置；未点击确认不发布、不收藏、不加入池、不改偏好 | Fake调用计数+既有业务回归，02 |
| R13 | 动画中刷新/硬失效/退出/换号/后台取消，晚回调不恢复旧ID或旧头像 | Unit+必要UI，02 |
| R14 | 长资料/缺图/晚到图片不改变卡外框；紧凑屏最大字号下资料/发送/收藏/Saved Groomers均可达 | 布局+UI，02/03 |
| R15 | Reduce Motion无旋转/弹性；上一/下一按钮与VoiceOver可完成同一序列；只有前卡可点击 | Unit+UI，02/03 |
| R16 | 启动参数确认动画开启，初次/预热各20次无可见卡死；不在drag changed中执行RPC、全池重排或图片解码 | 启动配置+短测量+代码复核，03 |
| R17 | 收藏入口位置不改，Send/Cancel及pool-only功能保留，无布局重构引起的重复操作 | UI+相关Store回归，03 |
| R18 | build/full tests/preflight通过；跳过项另列；远程夹具若使用则精确恢复；仅目标文件提交 | 集成与收尾，03 |

## 6. 计划自检与执行记录

计划自检已将四项反馈映射到UI-01/UI-02和R01-R17；宠物勾选挤压、滚动锚点迁移、尾卡nil身份、纵横手势冲突、异步动画遇到刷新五类风险均有明确验收。Saved Groomers按用户最终决定保持原位。没有新增后端需求或将高规模测试变成本次前置。

### T-401验收记录（2026-09-22）

- RED/GREEN：原生布局测试先复现长字段选中高度变化（紧凑默认约47pt、最大字号约319pt）及Header随滚动移动；修复后通过。尾卡身份及纯规则测试同样先失败后通过。Store增加刷新保留/移除当前ID、空结果、失效会话及旧transition回调覆盖。
- 使用测试target内的`CustomerDiscoveryInteractionTests`、UIHostingController和既有Fake运行真实生产视图；没有App测试路由、远程夹具或新依赖。语义定位/拖动为主，截图只用于几何和动效关键帧。
- iPhone 17e：默认和最大辅助字号的name/breed/weight及卡外框选中前后差值不超过1pt；重量在品种下方。长内容和大字号动作可滚动到达。iPhone 17 Pro Max：五个步骤滚动时Header位置不变，备注软件键盘开启前后Header的Y=94pt、高度88pt不变，关闭键盘后底栏恢复。
- 两种尺寸各完成首轮20次和预热20次往返，覆盖尾卡/反向返回/首张边界/微拖回弹。实测发现15pt短拖会误开详情，已用横向意图期间禁用卡内按钮修复；后续40次及独立微拖检查通过。
- 最大字号：收藏切换、Send后Cancel、前后按钮、尾卡唯一按钮、列表返回more再返回第8位、Saved Groomers入口均通过实际交互。辅助功能命名动作Next/Previous实际完成第8位与more往返；背卡不暴露可点击元素。系统Reduce Motion实际开启后验证前后切换及无旋转淡出，并恢复原设置。
- 最终独立计时段：40次完整往返，最长触摸结束至动画完成/身份落位为**0.3415秒**，全部低于0.5秒；发布调用0、旧create调用0、pool关闭。`/tmp/t401-interaction-timed.log`及对应xcresult通过。录像用于观察倾角/跳变，不充当60/120fps测量或真机证据。
- 验证过程限制如实保留：首次大屏宿主因切换设置后未及时结束而超时；后一次混合场景把辅助功能动作前的闲置时间误计为19.89秒。最终夹具仅对显式`measureMotion`段计时，且不丢弃慢样本，重新40次通过。临时语义脚本的List标识及固定800pt可见边界曾误报；列表返回与实际可见的收藏入口均补做语义交互确认。
- 本地证据保留在忽略目录`artifacts/testops/T401-ui/`：两尺寸deck序列JSON、宠物前后几何JSON/关键截图、`compact-reversible.mp4`、`reduce-motion.mp4`、`wizard-keyboard.png`、`motion-metrics-final.json`及验收日志。不提交录像或临时驱动，也不把Fake验收描述成远程真实订单通过。

集成收尾：`ios-build.sh`、`ios-test.sh`、`preflight.sh`通过。最终xcresult汇总763通过、0失败、43跳过（参数展开设备记录892次通过）；跳过项为40个专用TestOps UI场景、密码恢复邮件投递、独立进程接受恢复及本次opt-in交互宿主。交互宿主已单独通过；其余远程/专用场景本轮未重跑，不宣称新增远程验证。结果包为`Test-Beckon-2026.09.22_12-33-06--0700.xcresult`，脚本摘要为`/tmp/t401-build-final.log`、`/tmp/t401-tests-final.log`。preflight共218项通过；全量hygiene检查84份文档、0错误/警告。无远程数据修改，无真机/上架要求；已保留原有文档、签名和Light设置改动。按既有授权仅做一次目标文件完成提交与当前分支推送，不创建PR或合并。
