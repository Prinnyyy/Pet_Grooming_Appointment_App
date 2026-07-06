<!--
来源 / Provenance: 用户于 2026-06-20 直接提供的项目构建 plan 快照。
权威详版 / Canonical detailed version: docs/06_tasks/T-002_INCREMENTAL_BUILD_ROADMAP.md
本文件为按需读取的参考快照，不作为权威来源；如与权威文档冲突，以编号权威文档为准。
-->

# T-002：分阶段搭建路线图重建

## Summary

本任务仅重建文档计划，不修改 Swift、Xcode 工程或 Supabase。以 `Fresh_Pet_Groomer_Marketplace_Engineering_Brief.md` 为产品主来源，T-001 为已完成基线。

创建 `docs/06_tasks/T-002_INCREMENTAL_BUILD_ROADMAP.md` 作为唯一主路线图；后续任务文件在任务启动时按需创建。

## Implementation Changes

- 记录当前冲突：
  - 产品、架构、后端分册仍含占位内容和旧术语。
  - `CURRENT_STATE.md` 引用了已归档的轻量策略文件。
  - 运行时 Local Demo 约束与 Fresh Brief 的 Preview/Test fixtures 原则不一致。
- 路线图为每个后续任务定义：目标、依赖、范围边界、验收条件、建议验证和停止点。
- 更新：
  - `TASK_LEDGER.md`：T-002 完成，T-003 至 T-022 登记为 planned。
  - `CURRENT_STATE.md`：修正工作流引用，登记路线图和下一任务。
  - `WORKLOG.md`：追加 T-002 简短记录。
- 不更新 `FEATURE_INDEX.md` 或 `DECISION_LOG.md`，因为本任务不改变功能或架构实现。

## Incremental Roadmap

| ID | Mode | 独立任务及验收重点 |
|---|---|---|
| T-003 | Quick | 收敛产品、角色、导航、架构和后端占位文档；移除旧术语和运行时 demo 假设。 |
| T-004 | Deep | 建立 Supabase 基础、profiles/customer_profiles/groomer_profiles 与基础 RLS。 |
| T-005 | Deep | 接入 iOS Supabase SDK、环境配置和 session 边界；不得包含密钥。 |
| T-006 | Deep | 实现邮箱密码注册、登录、登出和 session 恢复。 |
| T-007 | Deep | 实现角色 onboarding、profile 创建和真实角色入口路由。 |
| T-008 | Deep | 建立 pets、pet_photos、Storage 和对应 RLS 契约。 |
| T-009 | Standard | 实现客户宠物资料 CRUD、照片上传及加载/错误状态。 |
| T-010 | Deep | 建立 groomer profile、services、portfolio Storage 与 RLS。 |
| T-011 | Standard | 实现美容师资料、服务设置和作品集界面。 |
| T-012 | Deep | 建立 grooming_requests、request_matches、创建/匹配/忽略 RPC 与 RLS。 |
| T-013 | Standard | 实现客户 request wizard 和发布结果界面。 |
| T-014 | Standard | 实现美容师 matched request feed、详情和 dismiss。 |
| T-015 | Deep | 建立 groomer_offers、提交 RPC、数量限制和权限规则。 |
| T-016 | Standard | 实现美容师报价表单和报价状态。 |
| T-017 | Standard | 实现客户报价列表、详情和比较界面。 |
| T-018 | Deep | 实现原子 accept-offer RPC、唯一 booking、时间冲突保护、关闭其他报价及创建 conversation。 |
| T-019 | Standard | 实现客户和美容师 booking 列表、详情及一致状态。 |
| T-020 | Deep | 实现仅 booking 参与者可访问的基础聊天。 |
| T-021 | Deep | 实现 booking completion 和 completed-only review。 |
| T-022 | Deep | 完成空/错/加载状态、Debug Panel、RLS 负向测试、冲突边界测试和核心 E2E 验收。 |

每次只启动一项任务；不得自动进入下一项。涉及后端、Auth、Storage、RLS 或原子事务的任务必须在启动时写明独立验证方案。

## Interfaces and Validation

- T-002 不增加或修改任何 Swift 类型、网络接口、数据库 schema 或公共 API。
- 唯一验证尝试：`./scripts/preflight.sh`。
- 随后只读检查 `git diff --stat` 和当前 diff，不运行 Xcode build、单元测试或 UI 测试。
- 若 preflight 失败，记录首个真实错误并停止，不进入修复循环。

## Assumptions

- Fresh Brief 是后续实现的正式产品来源。
- T-001 保持 completed，不重建基线。
- Mock 仅允许用于 Preview 和测试，不提供运行时假成功。
- 后续任务文档按需创建，不预建二十份 intake。
- 不使用子代理，不提交，不推送。
- T-003 是完成 T-002 后唯一推荐的下一任务。
