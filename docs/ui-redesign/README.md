# UI Redesign Inventory

本目录是 Beckon SwiftUI 当前生产 UI 的只读盘点与 Figma 重设计输入。它描述现有功能事实，不是视觉方案，也不授权修改业务逻辑。

## 文档用途与推荐阅读顺序

1. `00-inventory-scope.md`：项目架构、入口、盘点边界和排除项。
2. `01-screen-inventory.md`：38 个正式页面/surface 的完整清单与代码证据。
3. `02-navigation-and-user-flows.md`：顶层导航、页面关系、15 条流程与 Mermaid 图。
4. `03-screen-functional-specs.md`：逐页信息、控件、操作、表单、状态和生命周期。
5. `04-screen-data-and-state-map.md`：状态对象、Model、Repository、写入目标和不可破坏的业务边界。
6. `05-existing-component-inventory.md`：现有组件、重复实现、Token 事实和未来语义组件建议。
7. `06-inventory-audit.md`：反向搜索覆盖、纠错、计数口径和人工确认项。
8. `07-ui-redesign-brief.md`：交给 Figma 任务的最终功能输入包；优先阅读，再按需回查 01—06。

## 下一阶段交给 Figma 的方式

- 以 `07-ui-redesign-brief.md` 作为主 brief，保持 38 个正式 surface、角色边界、页面优先级、状态矩阵和业务约束。
- 用 `02` 建立原型连接，至少完整支持其中 15 条核心流程；不得用静态画面替代成功、取消、校验和失败分支。
- 用 `03` 核对每个主要操作的业务结果，用 `04` 核对权限、保存、异步和数据状态，用 `05` 建立语义组件及 Variant。
- 第 9 节的 7 个事项必须作为待产品决策问题保留；得到决定前不得自行补造功能。
- 不把 `#Preview`、Mock、Demo、TestOps、Debug Console 或 Embedded Component 当成正式页面。
- 设计评审时用 `07` 第 10 节回查 SwiftUI、Store、Model、Repository 和测试；若设计要求改变这些边界，应先拆出产品/工程决策任务。

## 计数口径

- 38 个正式页面/surface：包含 Root/Auth 条件 surface、角色页面、4 个唯一 Sheet 和删除账户确认 surface。
- 共享 `BookingsView`、`ChatConversationsView` 等按角色的数据、权限和操作边界分别记录。
- 6 个 `.sheet` 调用点映射为 4 个唯一 Sheet；Alert/Confirmation Dialog 不重复计为 Push 页面。
- 15 条核心流程；65 个现有可复用组件表条目。

最新不确定信息以 `06-inventory-audit.md` 和 `07-ui-redesign-brief.md` 的明确“待确认/待决策”标记为准。
