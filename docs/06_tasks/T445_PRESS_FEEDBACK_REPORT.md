# T-445 · Handoff 5 接入记录

独立工作包；设计源为本地 `CLAUDE_sandbox/CLAUDE_CODEX_HANDOFF_5.md` 第 0–5、7 节及其 PressFeedback 模块。未修改交接源、原型、签名或用户已有治理文件。

## 移植范围

生产路径均相对 `ios/Beckon/Beckon/`。

| 生产文件 | 原型对应与处理 |
|---|---|
| `DesignSystem/BeckonPressMachine.swift` | `PrototypeBeckonPressMachine.swift`：纯事件/效果状态机；补齐重叠点击和前次脉冲期间开始长按的边界。 |
| `DesignSystem/BeckonPress.swift` | `PrototypeBeckonPress.swift`：计时、尺寸分类、引擎、点击计数、表面及普通控件外观。剔除强制级别、慢动作、trace、实验室和 Gallery。 |
| `DesignSystem/BeckonLedge.swift` | 原型 PressLedgeStyle 的 amount 驱动外观，保留现有类型名、初始器、深度、虚实边框和 surface morph。 |
| `DesignSystem/BeckonActionPrimitives.swift` | 原型 PressFace、CountingBody 和基础动作参考：四个基础样式改为 PrimitiveButtonStyle，保留 Accent、宽度、字体、视觉可用性与原有尺寸；不添加滚动拦截。现有 GuardedButtonBody 保留生产滚动/位置保护后再计数。 |
| `DesignSystem/BeckonMotion.swift` | 删除旧 SettledPress；其他动画和可见性机制保持原有实现。 |
| `DesignSystem/BeckonModuleImage.swift`、`BeckonExpressiveIllustration.swift` | 在共享照片与吉祥物上标记保色范围，让卡片染色避开图像，无需逐页复制图片或吉祥物。 |

## 调用点

仅处理交接 §5 A–C 及其中允许的分组行。下列行号为本次修改后的样式调用位置。

| 分类 | 文件与入口 | 处理 |
|---|---|---|
| A | `SharedFeatures/Notifications/BeckonSystemNotifications.swift:82`、`:210`：铃铛、通知行 | 系统 plain 改为 GuardedPlain，自动区分图标和表面。 |
| A | `Features/Groomer/Profile/GroomerPortfolioEditorView.swift:512`、`:534`：fit-tag、旧保存栏删除 | 系统 plain 改为 GuardedPlain。 |
| B | `DesignSystem/BeckonLayoutPrimitives.swift:442`：SettingsNavigationRow | 显式 `.row`。 |
| B | `Features/Auth/AuthenticatedAccountView.swift:129`：Help 链接；`DesignSystem/DesignKit.swift:520`：ManageRow | 显式 `.row`，相邻行不缩放。 |
| B | `Features/Groomer/Home/GroomerHomeView.swift:607`、`:551`：Coming up 行及 Schedule 页脚 | 同一白色分组卡的完整行使用 `.row`。 |
| C | `Features/Groomer/Profile/GroomerAvailabilityEditorView.swift:169`：新增休假；同目录 `GroomerPortfolioEditorView.swift:272`、`:405`：当前照片删除、Retry；`Features/Groomer/Schedule/GroomerScheduleView.swift:102`：日历 | 增加 GuardedPlain；保留原有静态 ledge 和布局。 |
| C | `Features/Bookings/AppointmentReminderDestinationView.swift:44`、`Features/Customer/CustomerNavigation.swift:174`：Retry | 增加 GuardedPlain。 |
| 保留 | 报价页 Refresh、通知页 Mark All Read | 两者实际位于工具栏，保留系统反馈。菜单及原有手势入口未改。 |

## §6 决定

| 项目 | 用户答复与落实 |
|---|---|
| 1 · 震动 | 明确选择交接方案：ledge 与 Primary 在完整按压/有效脉冲时各一次 medium，其余类型安静。 |
| 2 · 力度 | 明确选择原型力度：40% 初触，卡片 10pt／2–6%，图标 0.88，链接变淡 45%，脉冲保持 70ms。 |
| 3 · 照片染色 | 明确选择“卡片染色，照片保留原色”。共享图片与吉祥物保色；染色与圆角不越出卡片。 |
| 4 · 初触 | 与力度问题一起确认保留 40%。它包含原型的小幅移动/收缩，滚动取消时淡退；不宣称初触完全没有移动。 |
| 5 · 基础动作协议 | 保留初始器和 Accent；基础动作使用不带滚动拦截的计数包装。现有 PhotosPicker/Menu 所需的 ButtonStyle-only ledge 外观继续存在。没有发现基础动作被当作泛型 ButtonStyle 使用的生产调用。 |

## 保留与技术裁定

- 生产的 `BeckonTapGuard`、`BeckonObservesMotionModifier`、嵌套滚动与冷却窗口继续生效；表单动作不套用它们。导航、保存、退出等动作仍即时调用，没有增加等待 70ms 的业务延迟。
- 原型把“已在上一脉冲按下”当作当前触摸已经完整反馈，连续输入会漏反馈或重复脉冲。两个边界均先在生产纯状态机上复现失败，再以事件用例修正；不改变确认过的时间与力度。
- automatic 的链接分类按文档要求使用实际高度 ≤48pt，避免把窄而高的控件误判为链接。
- 共享 tint 避开照片/吉祥物；静止时不创建染色几何或遮罩，按压期间才绘制。图像不会被解码/绘制两份来实现保色。
- automatic 测量前后使用同一内容修饰链，避免尺寸分类改变内部页面身份；卡片染色与内容一起缩放，防止留下未缩放的染色边框。
- 吉祥物保持 T-444 的固定外观。原型文件、Gallery、强制级别和 trace 不进入正式运行路径。

## 验收

功能实现与定向检查通过；完整回归保留一项基线同样失败的路由调度检查，详见下文。交互手感交由用户确认。

- 纯状态机：交接的快点两种顺序、长按、滚动取消、无触摸激活、连续点击、reset、迟到的 settled；另加重叠脉冲与下一次长按，共 11 个事件场景。
- 静态渲染：角色 pressedFace、ledge 高度、照片/吉祥物逐像素保色、圆角、基础动作禁用面；Reduce Motion 使用真实模拟器设置验证，不伪造只读环境值。
- `node scripts/ui-consistency-audit.mjs check`：通过，未调整基线。
- `node --test tests/ios/customer-prototype-boundary.test.mjs`：3/3；基础颜色源码契约 4/4。
- `./scripts/preflight.sh`：通过。默认 `ios-build.sh` 遇到 Xcode 后台构建数据库锁；独立 DerivedData 的实际 Debug/test build 通过，未争锁重试。
- 完整回归只运行一次：`/tmp/Beckon-T445-integrated.xcresult`。Swift Testing 883 项通过；单元 XCTest 90 项中 7 项跳过、1 项失败；UI XCTest 48 项中 40 项按配置跳过、0 失败。跳过包含远程/交互验收的显式 opt-in 项。所有页面/大字号渲染矩阵、角色、几何、滚动保护与业务用例通过。
- 唯一全量失败是已有 `testCustomerRouteHandoffsKeepTheMainActorResponsive`（Debug 模拟器主线程调度间隔，非实际帧率）：初次 max 0.713s，门槛 0.5s。隔离构建 HEAD `c48fe70f`、相同模拟器及客户端配置，基线也失败（max 0.551s、p95 0.271s；`/tmp/Beckon-T445-baseline-route.xcresult`）。本次最终代码为 max 0.558s、p95 0.283s（`/tmp/Beckon-T445-final.xcresult`），仍未达标；不能据此宣称无性能回归或全套全绿。没有修改阈值。原生 `sample` 的采样热点是 Swift 协议一致性解析和 SwiftUI 初始构建；它不证明生产帧率，本包不扩展为导航重构。
- 为上述失败做了有限范围修正：静止时不绘制染色遮罩、安静控件不安装触感反馈修饰器、自动分类不重建内容。最终定向状态机/渲染检查通过；只有系统开关关闭时的 Reduce Motion 专项按要求跳过，随后单独启用真实系统开关检查。功能无关的全量矩阵未重复运行。
- 修改前录像：`artifacts/evidence/T-445/before.mov`。使用生产 Groomer UI 的现有本地验收 host，依次快点／按住 300ms／从 Pending offers ledge 卡拖动，以及 Coming up plain 行的同类操作；点击打开正确页面，拖动保持在 Home。
- 修改后录像：`artifacts/evidence/T-445/after.mov`，本地宿主正常完成（`/tmp/Beckon-T445-after-recording.xcresult`）。同一 Pending offers 卡和 Coming up plain 分组行的快点、300ms 长按均打开正确页面。这里的 plain 示例是 grouped row，surface 照片/圆角另外由渲染检查覆盖。
- 录制限制：修改前原生语义定位可用并完成了真实拖动；修改后该接口只返回空树，改用桌面模拟器操作完成点击/长按。拖动/滚轮没有实际滚动页面，不能把它算作修改后滚动验收通过；从卡片起手滚动、拖出取消和滚动惯性中触摸，仍需用户手动确认。自动的既有 scroll/layout guard 检查通过，未修改保护规则。
- 首次修改后录制宿主被我的工具重新启动操作中断（`/tmp/Beckon-T445-after.xcresult`），未算通过；重开现有宿主后正常录制并结束。没有为此添加新测试框架。
- Reduce Motion：真实系统设置启用后，通过真实 UIWindow 的普通控件渲染检查（`/tmp/Beckon-T445-reduce-motion-hosted.xcresult`）。首次离屏 ImageRenderer 检查缺少窗口系统环境，已改正测试宿主；未改生产分支或伪造只读环境值。验收后恢复 Reduce Motion 原来关闭的状态，并恢复系统联动改变的消息自动播放设置。
- 最终构建：`/tmp/Beckon-T445-motion-build.log` 成功。最后一次变化仅为测试渲染宿主；生产源码沿用 `/tmp/Beckon-T445-final.xcresult` 的有效证据。最终 preflight、7 项 Node 检查及完整 context hygiene（100 文档）均通过，未改变审计基线。

## 仍由用户判断

模拟器和状态机可以验证事件、次数、画面及导航；不能证明物理震动的感觉或用户是否喜欢当前力度。交接 §7 中的全部控件种类、手指移出取消和滚动触摸的最终体验尚未由用户签收，不能将本报告当作完整人工体验验收。无真人账号/后端写入、真机、签名或商店要求。VoiceOver 的无触摸激活由纯事件用例覆盖，不宣称完成了人工 VoiceOver 手势巡检。
