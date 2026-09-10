# 预约实测缺陷修复 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. 本项目禁用子代理；工作包不是停止或重新征求普通执行确认的边界。

**Goal:** 修复 T-387 已复现的三个缺陷，使满额请求替换保持原子性、已确认预约及时进入列表、双角色消息通知准确打开所属会话。

**Architecture:** 请求替换继续使用现有事务与发布限额锁；客户侧共享一个会话范围内的 BookingsStore，并保护已确认结果免受旧读取覆盖；消息通知增加可空会话引用，按参与者权限精确读取会话。保留现有仓储、状态机和测试工具，不增加通用事件总线或新业务框架。

**Tech Stack:** SwiftUI、Observation、Swift Testing / XCTest、现有 Supabase Swift SDK、PostgreSQL / PLpgSQL、Node 原生测试与现有 TestOps 脚本。

**Spec:** [T-387 真实预约测试及三个缺陷](../../04_ios/testops/T-387_BOOKING_SCENARIOS.md)。该报告的历史结论保持 **72 个已执行、69 通过、3 个缺陷失败**，不能用修复后的结果覆盖。

<!-- task-artifact
task: T-388
status: completed
type: plan
-->

## Global Constraints

- 计划编写阶段仅交付文档；用户随后要求开始执行，T-388 进入实施。远程写入仍遵循下述独立授权边界，未经验收不能标记缺陷已修复。
- 范围仅为 F1 / B71、F2 / B72、F3 / B67 及其直接回归；不重启已经验收的 WP-00 至 WP-14，也不调整时区设置位置、匹配政策或全局模块结构。
- 顾客最多三个有效待接单请求；待定报价不占预约资源；宠物、美容师容量、行程缓冲、版本化协议和权限规则保持不变。
- Simulator 足够完成本地 App 验收；真机、签名、应用商店和 APNs 部署不作为前置条件。本地 App 与共享 Beckon 后端不是同一授权边界。
- 不新增依赖，不修改已应用迁移，不扩大 RLS / grants，不使用高权限写入伪装顾客发布或美容师报价。
- 沿用 [开发指南](../../05_workflow/DEVELOPMENT_GUIDE.md) 的状态、授权、验证与 Git 边界。仅修复计划的采纳不等于迁移、部署或测试数据写入授权。
- 实施前保留当前用户修改，尤其是已脏的后端契约、Runbook、历史记录；不要顺手整理或提交这些文件的无关差异。

## 顺序与完成口径

| 工作包 | 对应缺陷 | 独立交付与边界 |
|---|---|---|
| RP-01 | F2 / B72 | 修正满额替换事务；发布额度仍为三个，不改变公共 RPC 签名 |
| RP-02 | F3 / B67 | 已确认预约同步到已加载列表；旧读取、重试与账号切换不能破坏状态 |
| RP-03 | F1 / B71 | 双角色消息通知携带准确会话目标；权限、历史数据和部署兼容闭环 |
| RP-04 | 联合验收 | 一次集成回归、授权范围内的后端应用与实际行为验收、精确清理 |

默认按 RP-01 至 RP-04 连续推进。先完成三个包的本地实现与针对性测试，再在集成节点处理后端应用和真实行为验收。缺少远程授权时，继续可独立完成的本地工作，不提前宣称端到端完成。

完成必须同时满足：三个原始复现由红转绿，原 72 个场景全部重新验收，下面的直接边缘测试通过，相关 Swift 集成回归通过，后端定义与测试环境一致，测试数据清理有证据。静态 SQL 字符串测试、单独的 API 成功或大量局部绿灯均不能替代这些条件。

## RP-01：满额请求原子替换

### 文件与接口

- 新建迁移：实施时运行 `supabase migration new t388_atomic_request_replacement`，只编辑 CLI 生成的文件。
- 修改函数：`app_private.supersede_grooming_request(uuid, uuid, uuid, jsonb, text)`；公共包装器及返回值 `table(request_id uuid, match_count integer)` 保持不变。
- 依据：`supabase/migrations/20260908203810_t376_versioned_agreements.sql` 的替换函数、`20260908185059_t375_feasible_matching.sql` 的发布 v4、`20260728215928_t358_request_publish_idempotency.sql` 的 v3、`20260712014418_t294_postgis_private_address_locations.sql` 的 v2。
- 撤销逻辑依据：`supabase/migrations/20260622142020_t044_cancel_grooming_request.sql`，其函数随后迁入 `app_private`。这些迁移只读，不能就地修改。
- 测试：新增 `tests/migrations/atomic-request-replacement.test.mjs`；扩展 `scripts/test-t387-booking-scenarios.mjs` 的 B72 和替换边缘组，不复制夹具管理器。

### 修复决策

当前顺序为创建新请求后撤销旧请求，创建时把原请求也计入三个名额。改为**一次 RPC、同一事务内撤销后创建**，不是让客户端先调用撤销 RPC。

1. 保留认证、操作 ID 锁及已提交回执的优先重放。重放仍需证明回执的请求属于当前顾客且 `supersedes_request_id` 等于目标原请求。
2. 锁定当前顾客拥有的原请求，验证 `terms_revision`、有效期和 `open / has_offers` 状态。
3. 调用现有私有撤销函数关闭原请求、待定报价和匹配；随后调用发布 v4。v4 → v3 → v2 中已有的顾客 profile 行锁继续串行保护限额统计和创建。
4. 设置新请求的 `supersedes_request_id`，保留已有唯一约束。任一后续步骤失败，异常传播到事务边界，旧请求、报价、匹配、通知、地址与发布回执全部回滚。

核心替换片段，位于现有校验之后：

```sql
perform app_private.cancel_grooming_request(original.id);
select created.request_id, created.match_count
  into strict replacement, matches
  from app_private.create_grooming_request_v4(
    p_publish_operation_id, p_request, p_preference_time_zone_identifier
  ) created;
update public.grooming_requests
  set supersedes_request_id = original.id
  where id = replacement and customer_id = actor;
return query select replacement, matches;
```

不得引入 `ignore_request_id` / 绕过额度开关、第四个名额、客户端补偿事务或吞掉异常后返回成功。保持现有操作锁 → 原请求行锁 → 发布链 profile 锁的相对顺序，不为这次修复随意把 profile 锁移到原请求之前。审查撤销触发器与接受报价路径；只有证明存在阻断此事务的锁环，才对相应路径做最小一致调整。

同一操作 ID 重试采用现有“返回首次提交结果”的语义：相同原请求但改变载荷不能产生第二次修改，也不要求新增载荷指纹；拿别的原请求或普通发布回执冒充替换必须返回 `publish_operation_intent_changed`。新的替换意图需要新的操作 ID。

### 执行与验收

- [x] 在现有 B72 的三个请求夹具上加强断言，并增加 E01-E08。保留原始失败证据；授权后的新测试若环境未变，直接复用原始 RED，不为截图反复制造失败。
- [x] 新增静态保护测试：读取新增迁移，检查撤销在 v4 调用前、回执归属与原请求校验仍在、没有改变限额或公开新参数。运行 `node --test tests/migrations/atomic-request-replacement.test.mjs`，先证明缺少修复时失败。
- [x] 生成并实现前向迁移；运行上述测试及 `node --test tests/migrations/request-publish-idempotency.test.mjs tests/migrations/versioned-agreements.test.mjs`。
- [x] 在 RP-04 授权环境以真实客户 token 执行 B69、B70、B72 与 E01-E08；每个失败分支比较操作前后权威摘要。静态通过仅记为本地通过。

成功 B72 至少断言：

```javascript
assert.equal(openRequests.length, 3);
assert.equal(originalAfter.status, "cancelled");
assert.equal(replacementAfter.supersedes_request_id, original.id);
assert.notEqual(replacementAfter.id, original.id);
assert.deepEqual(unrelatedRequestsAfter, unrelatedRequestsBefore);
assert.equal(pendingOffersForOriginal.length, 0);
```

## RP-02：确认预约后的列表一致性

### 文件与接口

- `ios/Beckon/Beckon/Features/Customer/CustomerTabView.swift`：创建、持有并注入客户会话的共享 BookingsStore。
- `ios/Beckon/Beckon/Features/Customer/Requests/CustomerRequestsStore.swift`：接受成功及不确定结果恢复后同步；详情使用共享 Store，保留无注入的测试/独立页面路径。
- `ios/Beckon/Beckon/Features/Bookings/BookingsView.swift`：在现有完整初始化器增加 `store: BookingsStore? = nil` 注入，不丢失 republish、profile、聊天及美容师日程依赖。
- `ios/Beckon/Beckon/Features/Bookings/BookingsStore.swift`：加强 `synchronizeExternalBooking(_ booking: Booking)`，为列表读取增加代次保护和合并后的补读。
- 测试：`CustomerRequestFeatureTests+Offers.swift`、`BookingScopedReadTests.swift`、现有 fakes，以及 `ios/Beckon/BeckonUITests/TestOpsLaunchSmokeTests.swift` 的 B67/B68。

在 CustomerRequestsStore 现有初始化器追加 `bookingsStore: BookingsStore? = nil`。由根视图把同一个实例交给 Requests 和 Bookings；绑定必须在子视图开始加载前完成，不靠某次 `.onAppear` 恰好先执行。不要使用单例、跨账号缓存或通知总线。

### 修复决策

已提交结果的传播路径：

```text
接受 RPC 成功 / 接受结果恢复并完成身份校验
  -> 当前客户的共享 BookingsStore 同步该预约
  -> 列表与接受后的详情看到同一预约身份
  -> 合并一次权威刷新，补齐最新状态、分页和提醒快照
```

- 接受回执不携带“首次创建/幂等重放”的区分，confirmed 也可能对应已改期预约。因此成功后统一按 booking ID 精确读取当前 Booking，再在串行附加刷新之前同步；不再使用旧报价投影。代价是一笔有界权威读取，失败保留恢复身份，不伪造当前时间或重复接受。
- 恢复/重放可能对应已经取消、改期或完成的预约，必须精确读取当前 Booking 后同步，不能用旧报价时间和旧回执投影覆盖当前预约。覆盖 `accept` 的恢复分支及 `reconcileUnresolvedAcceptances`，不只修确认按钮回调。
- 同步和每次 `await` 返回后检查当前参与者/会话；外来 Booking 不进入 Store。账号切换销毁旧会话 Store，晚到结果不能发布到新账号。
- 列表维护读取代次：外部同步使旧代次失效；旧首页或后续页不能覆盖新状态、推进失效分页 offset，或标记刷新完成。正在加载时合并一个待刷新标记，结束后补读，不能被 `isLoading` guard 永久吞掉，也不能无限重试。
- 共享 Store 内已经提交的取消、改期及履约状态更新也使用同一代次失效入口；不能只保护来自 Requests 的新增预约，再让详情操作被旧列表覆盖。不为此重构服务端状态机。
- 保留已确认且尚未包含在当前分页中的预约，按 ID 去重；首页没有某 ID 不等于该预约已删除。只凭精确权威读取更新/移除额外保留项，并在会话销毁时清空。重试失败保留已确认结果与可恢复错误，不退回“没有预约”。
- 复用已有日程/最近预约失效逻辑及完整提醒快照接口。局部投影不能冒充完整提醒集合，不缩短 45 秒全局轮询作为修复。

列表并发控制的实现形状：

```text
synchronizeExternalBooking(ownedBooking):
  校验参与者；增加 listGeneration；按 ID 合并预约
  标记一次待补读；使旧分页失效；沿用现有日程失效
load / loadNextPage:
  保存开始时 listGeneration
  await repository 读取
  若取消、会话无效或代次变化：不应用结果与分页游标
  否则合并页面及已确认的页外预约，更新有效游标
  结束忙碌状态后消费一次待补读；失败等待下一次用户/生命周期重试
```

### 执行与验收

- [x] 增加 E09-E16 的 Store 测试。旧响应测试使用 continuation 控制返回次序，不能依赖随机睡眠制造时序。
- [x] 先用已有 `synchronizeExternalBooking` 构造“旧首页开始 → 新预约同步 → 旧首页返回”的 RED，再实施共享注入及代次保护。
- [x] 精确验证三个路径：新接受、同操作恢复、启动时恢复。接受详情中取消/改期后回到列表也必须保留最新状态。
- [x] 串行运行针对性 Swift 测试；编译改动完成后运行 `./scripts/ios-build.sh`。RP-04 用实际 B67/B68 验收，不加自动拉刷新、重登录或延长等待来隐藏缺陷。

建议新增测试名：`acceptedBookingSurvivesLateFirstPage`、`lateNextPageCannotOverwriteSynchronizedBooking`、`recoveredAcceptanceUsesCurrentBooking`、`oldSessionCannotPublishBooking`。它们分别断言 ID 不丢失、当前状态不倒退、当前时间/状态准确、跨账号发布为零；测试需要的延迟返回闭包只加入现有 fake，不创建新测试框架。

针对性命令使用实际可用 Simulator，`CODEX_IOS_DESTINATION` 由现有 `scripts/ios-destination.sh` / 设备枚举确定：

```bash
xcodebuild -project ios/Beckon/Beckon.xcodeproj -scheme Beckon \
  -destination "$CODEX_IOS_DESTINATION" \
  -only-testing:BeckonTests/BookingScopedReadTests \
  -only-testing:BeckonTests/CustomerRequestsStoreTests test
```

## RP-03：消息通知精确路由到会话

### 文件与接口

- 新迁移：`supabase migration new t388_message_notification_conversations`，给 `public.customer_notifications` 和 `public.groomer_notifications` 增加 `related_conversation_id uuid null references public.conversations(id) on delete set null` 及非空引用索引。
- 修改现有两条消息触发函数：`app_private.customer_notifications_after_groomer_message_insert()`、`app_private.groomer_notifications_after_customer_message_insert()`；参考 `supabase/migrations/20260713223400_t351_participant_conversations_booking_events.sql`，不修改该历史文件。
- 模型：`Core/Models/CustomerNotification.swift`、`GroomerNotification.swift`，增加可空 `relatedConversationID`，初始化和 `replacingReadState` 必须保留字段。
- 仓储：`Core/Infrastructure/Supabase/SupabaseCustomerNotificationRepository.swift`、`SupabaseGroomerNotificationRepository.swift`，更新显式 select、DTO CodingKeys 与映射，校验 mark-read / mark-all-read 返回行。
- 精确会话查询：`Core/Repositories/ChatRepository.swift`、`Core/Infrastructure/Supabase/SupabaseChatRepository.swift`、`Core/Diagnostics/DebugRepositoryWrappers.swift` 及 `Features/Chat/ChatStore.swift`。
- 路由：`Features/Customer/Notifications/CustomerNotificationsStore.swift`、`Features/Groomer/Notifications/GroomerNotificationsStore.swift`；必要的不可用提示放在对应 NotificationsView。
- Swift 路径均相对 `ios/Beckon/Beckon/`。测试扩展现有 `NotificationRoutingTests.swift`、`ChatFeatureTests.swift` 及通知 fakes；新增 `tests/migrations/message-notification-conversations.test.mjs`；复用 B71 和 UI 驱动。

新增接口的完整契约：

```swift
// ChatRepository 与实际仓储、Debug wrapper、测试 fake 一致实现。
func conversation(id: UUID, participantID: UUID, role: UserRole) async throws -> ChatConversation

// ChatStore 使用自身参与者身份，查不到或无权访问时返回 nil。
func resolveConversation(conversationID: UUID) async -> ChatConversation?
```

### 修复决策

- 消息触发器仅处理 `kind = 'text'`，从 `new.conversation_id` 查出双方，核对 sender 后为对方创建**一条**通知，原子写入会话引用。不存在“找最新预约”的步骤。
- 两个私有消息触发函数可直接插入各自通知表，显式写入当前已验证的接收者、固定文案与 `related_conversation_id`；保留表默认值和现有约束。其他通知继续使用原七参数 helper，避免为一个字段改动所有通知调用方。
- 不保存聊天正文、坐标或更多个人信息；不赋予客户端写目标字段权限。会话查询同时约束 `id` 与当前角色的参与者列，受现有会话 RLS 保护；复用现有 hydrate / summaries，不通过分页扫描寻找目标。
- Store 再次检查返回的 ID 和参与者。`newMessage` 优先使用会话 ID；仅在新字段为空且有旧 booking ID 时，沿用已有的权威 booking → 参与者会话路径。明确提供了会话 ID 却无权读取时，不降级猜测其他目标。
- 旧通知三个目标都空时无法可靠重建，不按时间、最近消息或最近预约回填。显示确定的“原会话无法定位”结果，保留用户主动标记已读能力，不自动跳转、不误标已读；临时网络失败另给可重试错误。
- 正常点击先解析成功再尝试标记已读。标记请求失败不伪造已读，也不阻止已经验证过的目的地打开；保留现有错误反馈和稍后重试路径。

路由与 B71 的验收核心：

```text
newMessage + conversation ID -> 精确查询并校验 -> .message(conversation)
newMessage + 仅 booking ID   -> 既有受权 booking 路由
newMessage + 无目标          -> 确定不可用，不猜测，不自动已读
```

```javascript
assert.equal(notification.related_conversation_id, sentMessage.conversation_id);
assert.equal(ownedConversation.id, notification.related_conversation_id);
assert.equal(nonparticipantConversations.length, 0);
```

### 兼容与验收

- [x] 先增加真实载荷形状的 RED：`new_message` 有会话 ID、无 booking ID；两个角色均不得依赖测试中人为填充 booking ID。补 E17-E24。
- [x] 实现可空模型、精确查询及路由，补齐 Debug wrapper/fake，运行 `NotificationRoutingTests` 和 `ChatFeatureTests` 针对性测试，以及 `node --test tests/migrations/message-notification-conversations.test.mjs`。
- [x] 编写前向迁移，保留现有 RLS、函数 ACL 与通知已读 RPC。核查 `returns setof` 行类型能带回新字段，read-state 替换不丢目标。
- [x] 在 RP-04 **先应用字段及触发器，再验证实际读写，最后运行启用新显式 select 的客户端**。可空 Swift 字段不能防止旧数据库因查询不存在列而报错，不能颠倒顺序。
- [x] 旧客户端连接新后端仍能读取原字段，但不声称其消息跳转已被修好；只有更新客户端才获得新路由。当前范围不为旧二进制添加猜测目标或另造兼容服务。
- [x] 实际双向发消息并点击双方通知，验证会话 ID、参与者和消息对应。会话含多笔预约、预约已取消以及目标不在会话首页时仍正确。

## 直接边缘验收矩阵

S = 确定性 Swift/契约测试；H = 真实身份 HTTP/RPC；U = Simulator 实际交互。一次执行可以提供多条断言，但不得把参数变化或重试包装成更多已执行业务场景。

| ID | 通道 | 场景与必须成立的结果 |
|---|---|---|
| E01 | H | 分别持有一、二、三个有效请求替换其中一个；净数量不变，关联、报价关闭、其他请求不变 |
| E02 | H | 同一替换操作串行/并发重试及改变载荷后重试；仅一个替代请求，返回首次回执，不再次改动 |
| E03 | H | 不同操作同时替换同一原请求；恰有一个成功，失败有明确业务原因，不能两个替代请求 |
| E04 | H | 同一顾客同时替换两个不同原请求；允许两笔有效替换，无死锁/超时，净数量不变 |
| E05 | H | 替换与普通发布并发；初始两个请求时两者可成功，初始三个时普通第四单拒绝，不暴露事务内临时名额 |
| E06 | H | 替换分别与原请求接受/撤销竞争；结果等价于合法串行次序，失败不能改变胜方结果 |
| E07 | H | 在原请求撤销后的发布阶段因非法新参数失败；原请求、待定报价、匹配、通知、地址、回执摘要全部不变 |
| E08 | H | 过期/已预约/旧 revision/外来原请求，以及借用其他发布操作 ID；准确拒绝，无越权与多余副作用 |
| E09 | S/U | 先接受第一单并打开列表，再接受第二单返回；两条各一次、日期正确，不刷新不重登录；已加载 UI 三秒内可见 |
| E10 | S | 接受发生于首页读取中，旧页面晚到；新预约不消失，只合并一次后续刷新 |
| E11 | S | 旧下一页晚到、预约位于首页之外、重复回执；当前状态不倒退，分页无重复或因本地插入而跳项 |
| E12 | S/H | 丢弃已成功响应后恢复，且预约后来已改期/取消；同步当前预约，不恢复旧时间或状态，不再创建预约 |
| E13 | S | 网络结果不明、容量拒绝或无有效回执；不能向列表注入伪造的 confirmed Booking |
| E14 | S | 接受或列表读取未结束即退出/换账号；新账号无旧预约，旧任务不触发新账号回调 |
| E15 | S | 同步后刷新失败或被取消；确认结果仍可见，分页不使用过期游标，后续明确刷新可恢复 |
| E16 | S/U | 接受详情取消一单后回列表；另一单不变，重新发布入口和客户地址依赖仍在；美容师日程回归通过 |
| E17 | H/U | 客户/美容师各发送真实三列文本载荷并点通知；各产生一条带正确会话 ID 的对方通知 |
| E18 | H/U | 同一参与者会话包含两笔预约并取消其中一笔；通知仍打开该会话，不选所谓最新预约 |
| E19 | S/H | 目标会话不在已加载首页；按 ID 精确解析，不加载所有会话或依赖第一页 |
| E20 | S | 旧有效 booking 目标可打开；完全无目标的历史通知确定不可用，不猜测、不自动已读 |
| E21 | S/H | 他人通知/会话 ID、伪造参与者、尝试修改通知目标；权限拒绝且不泄露，不降级其他目标 |
| E22 | S | 查询网络失败保持未读且可重试；查询成功但标记已读失败仍可进入准确会话，不伪造已读 |
| E23 | S/H | 缺少可空字段的旧载荷可解码，新后端原字段查询仍可用；未知通知类型继续安全失败 |
| E24 | S/H | 通知列表、mark-read、mark-all-read 往返保留会话 ID；会话删除后引用为空，提示不可用不崩溃 |

H 并发用例记录实际请求结果及最终事务不变量；仅并发发起不能被描述成已证明锁等待顺序。需要判断死锁时使用有超时的受控交错测试，不无限扩大到全数据库锁审计。

## RP-04：集成、实际行为与收口

### 一次集成节点

- [x] 本地运行 `./scripts/preflight.sh`、`./scripts/ios-test.sh`、`node scripts/context-hygiene-check.mjs --full` 及 diff 审查。共享 Store/仓储必须运行相关完整 Swift 回归；完整 test 已包含构建时，不再为同一提交重复独立 build。
- [x] 明确本次后端应用和 TestOps 写入授权范围后，使用安装的 Supabase CLI 串行核对 Beckon 项目、受影响定义和迁移历史，先 dry-run，再应用恰好两份经审查迁移；有其他待部署内容时先核对范围，不能捎带应用。
- [x] 检查数据库新增列/FK/索引、RLS/ACL、触发器和替换函数的实际定义，确认 schema cache 可读取新字段；相关安全检查和真实负例通过后运行更新客户端。只声明实际执行过的部署与验证。
- [x] 在新的独立 run ID 中执行原 72 个场景和上述直接增量。B71 的原断言由“必须有 booking ID”改为“必须有准确且可访问的 conversation ID”，并增加实际点击，业务标准不是放宽。

### 复用现有行为测试

只扩展现有 runner 的用例和必要断言。保留 `TESTOPS-T387-` 前缀以兼容现有工具，实际 run ID 加上本次任务和唯一后缀；不能复用已经恢复完成的历史运行。沿用原报告中的角色/夹具/授权环境设置，不把凭据写入计划或命令记录。

授权并核对空闲测试队列后，顺序如下：

```bash
node scripts/test-t387-booking-scenarios.mjs prepare
node scripts/test-t387-booking-scenarios.mjs run
node scripts/test-t387-simulator-sign-in.mjs customer PublishTwoRequests
node scripts/test-t387-simulator-sign-in.mjs groomer QuoteTwoRequests
node scripts/test-t387-simulator-sign-in.mjs customer AcceptTwoRequests
node scripts/test-t387-simulator-sign-in.mjs customer CancelOneRequest
```

随后用同一组已存在的会话完成 E17/E18 的双向通知点击，追加在原 UI 测试类及原 sign-in runner 中；只增加支持该动作所需的阶段，不另建 UI 自动化系统。确认 UI 阶段输出后再清理：

```bash
node scripts/test-t387-booking-scenarios.mjs cleanup
```

- [x] UI 验收使用现有 Simulator，可切换真实角色；第二个 Simulator 只在需要同时观察时使用，不把它或真机列为强制条件。HTTP 并发结果与 UI 交互结果分开报告。
- [x] 复用现有夹具的原地设置恢复和无关活动保护；新通知按精确会话/ID 纳入清理，不能靠 booking 外键清理，因为文本通知不再依赖 booking。
- [x] 比较原有 15 组恢复摘要并纳入新字段/引用；证明无本次请求、消息、通知、回执、地址残留，原业务数据和无关请求未被改动。保留已有审计版本前进的历史说明，不能强行回写安全 revision。
- [x] 任一阶段失败，保存首次原因和权威结果，防止不明结果下重复执行成功写入；使用原 runner 的只读验证模式读取结果，不把 UI 失败改记为 API 通过。

验收结论：T-388 完成。原 72 个场景全部通过；E01-E24 按指定 S/H/U 通道验收，未将单元测试当作真实 UI 操作。两个迁移已部署，15 组恢复摘要一致。详见 [最终验收记录](../../04_ios/testops/T-388_BOOKING_REMEDIATION_ACCEPTANCE.md)。

### 记录和完成

- 只维护 [Current State](../../00_memory/CURRENT_STATE.md)、本计划勾选及一份实施时生成的简短 `docs/04_ios/testops/T-388_BOOKING_REMEDIATION_ACCEPTANCE.md`。该验收文件记录版本/环境、72 个唯一场景结论、增量结果、三个缺陷证据和恢复摘要；不逐步追加长报告。
- 部署后只对 `docs/03_backend/SUPABASE_CONTRACT.md` 与 `RLS_RPC_POLICY.md` 写入确实改变的接口/权限事实，保留用户原有修改；会话通知目标这一持久契约决策在实施采纳时加入 Decision Log，不为本轮草拟先改规则。
- 客户端回退不删除已添加列；后端若需修正使用前向修复迁移，不重写已应用文件。发现目标错误、权限泄露、错误回执或状态覆盖时暂停该版本验收，修正后只重跑受影响证据，再完成最终集成。
- 全部完成标准满足后才更新任务完成状态并按当前分支范围提交/推送。缺少远程授权/环境时记录“本地实现完成、端到端未验收”及具体剩余项，不能把计划完成或单元测试通过当作缺陷关闭。

## 计划自检

- 三个缺陷均有独立修复、原始复现和直接边缘验收；未把无关产品改进塞入关键路径。
- 替换事务不提高额度、不改变幂等政策、不引入跨 RPC 的取消空档；保留原锁顺序并覆盖不同原请求的并发。
- 列表方案同时覆盖新接受与恢复、晚到首页/下一页、页外预约、详情状态变化、会话隔离和提醒完整性。
- 通知方案不依赖预约挑选或分页缓存；显式处理旧目标缺失、新字段部署次序和已读失败。
- 原 T-387 的 69/3 结论与此次修复验收分开；不要求真机、上架或新工具工程，不预先宣称所有未知缺陷已消除。
