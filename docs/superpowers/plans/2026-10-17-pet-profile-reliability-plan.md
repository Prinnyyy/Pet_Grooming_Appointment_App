# 宠物档案可靠性修复实施计划

> **For agentic workers:** Use `superpowers:executing-plans` to implement this plan in the current session. Steps use checkbox syntax. Subagents remain disabled by repository policy.

<!-- task-artifact
task: T-406
status: completed
type: plan
-->

**Goal:** 修复宠物档案的旧编辑覆盖、创建重试重复、旧刷新覆盖新状态三个问题，复用现有保护模式，不建立通用同步系统。

**Architecture:** 保留 View -> CustomerPetsStore -> CustomerPetRepository -> Supabase 的现有边界。创建复用请求发布的操作编号、原子回执与单条待确认记录模式；编辑复用排班的版本校验与显式重新加载；读取复用资料页的 loadID + mutationRevision。复用行为和基础设施，不让宠物模块依赖请求发布或排班 Store。

**Tech Stack:** Swift 6 / SwiftUI / Observation / Supabase Swift / PostgreSQL；不新增依赖。

**Spec:** 本文“范围与规则”是本次修复的完整设计依据，来自用户明确提出的三项问题及“尽量复用、避免过度设计”的要求，不再拆出另一份规格文档。

本文同时保留实施范围和定域验收记录；动态状态见 [Current State](../../00_memory/CURRENT_STATE.md)。

## 1. 范围与规则

| 问题 | 必须达到的结果 | 不采用的替代办法 |
|---|---|---|
| 旧编辑覆盖新数据 | 同一旧版本的两次不同编辑最多一个成功；另一方明确收到冲突，草稿保留 | 仅靠行锁、防连点、先读后写；把刚刷新的版本贴到旧草稿上 |
| 创建结果未知后重复创建 | 同一创建意图在重复点击、响应丢失、退出表单、App 重启后仍只对应一条档案 | 按名字/品种猜测重复；每次点击生成新编号；只在内存保存编号 |
| 旧刷新覆盖新状态 | 旧列表、照片、错误和缓存写入不能覆盖较新的加载或本地修改 | 只暂停界面刷新；只保护列表但遗漏照片和错误分支 |

- 只治理宠物档案链路及必要入口、测试、契约。不扩展到顾客/美容师资料重构、匹配评分调参、历史重复档案自动合并、照片事务重做。
- 不新增离线队列、后台自动重试、通用 BaseStore、全局事件总线、全套字段合并界面或新测试平台。
- “重复意图”由操作 UUID 定义；用户明确另建一只同名宠物是合法行为，不能按字段相似度拦截。
- 新建需求使用当时的有效档案；已发布需求、报价、预约和评价保留已有快照规则，不自动改写历史。
- [Development Guide](../../05_workflow/DEVELOPMENT_GUIDE.md) 和 [Backend Contract](../../03_backend/SUPABASE_CONTRACT.md) 继续约束实现。保留已有工作区修改、RLS、数据来源标记及已应用迁移。
- 用户已采用 T-406 并授权计划所需必要操作，包括定域远程迁移、既有测试账号验证与精确恢复；不借此扩大到其他项目、创建账号或无关数据修改。
- Simulator 足够；不增加真机、签名、上架或真人推荐评审门槛。按工作包连续执行，工作包完成不要求结束会话或提交检查点。

## 2. 复用清单

| 现有实现 | 本次复用 | 刻意不复用 |
|---|---|---|
| `CustomerProfileStore.load()` | loadID、mutationRevision、当前响应判定、错误/defer 的归属检查 | 不抽取通用 Store 父类 |
| `GroomerProfileStore+ServicesAvailability.saveAvailability()` | expectedRevision、HTTP 409、保留草稿、结果未知时先核对再保存 | 不把宠物版本绑定到排班版本；不复用排班表结构 |
| `CustomerRequestPublicationCoordinator` / `PendingRequestPublication` | 发送前原子落盘、按账号隔离、不可变创建意图、确认后清理、取消不等于撤销服务端提交 | 不调用发布 Coordinator，不扩展它成为多业务队列 |
| `request_publish_operations` / 分发写入 RPC | actor + operation 唯一性、意图摘要校验、事务内创建与回执、重放不再次写入 | 不把宠物记录塞进 Request 回执表 |
| `save_my_pet_v2` / `guard_pet_match_facts` | 所有权、输入白名单、体重派生体型、coat 来源和未知事实规则 | 不复制一套宠物事实规则，也不保留可绕过新保护的旧客户端写入口 |

## 3. 最小设计

### 3.1 服务端：创建幂等，编辑比较版本

新增一个 `pets.revision uuid`，由数据库初始化和维护。编辑字段或软删除状态实际变化时更新；无关图片下载不影响版本。旧档案回填一次，不能借机改写体重、coat 来源或历史请求快照。

新增一张小型私有表 `app_private.pet_create_operations`，仅记录 customer_id、operation_id、canonical_hash、pet_id、created_revision、created_at；主键为 `(customer_id, operation_id)`。不保存整份健康备注/档案快照，不公开表级读写。仅创建需要回执，编辑沿用现有排班式核对恢复，不为所有 CRUD 建操作日志。

统一新入口：

```text
public.save_my_pet_v3(
  p_pet_id uuid, p_facts jsonb, p_coat_confirmed boolean,
  p_operation_id uuid, p_expected_revision uuid
) -> { pet_id, result_revision, replayed, state: active|unavailable, pet }
```

- 创建：pet_id / expected_revision 必须为空，operation_id 必填。先用现有不依赖发现开关的 `require_request_customer()` 验证身份，再按 actor + operation 加事务锁；已有回执先校验服务端规范化意图摘要，再返回原 pet_id，绝不再次创建或覆盖档案。
- 首次创建：复用私有 v2 的事实校验/写入，创建档案和回执在同一事务提交。失败两者一起回滚。同一编号不同内容返回 `PT409/pet_operation_intent_changed`，不猜测用户是否想修改。
- 创建重放返回原创建版本及该宠物当前的 owner-safe 数据，而非历史整行快照。若已被另一设备编辑，展示当前数据并说明创建已确认；已删除则返回 unavailable，不复活、不重新创建。回执不随软删除或普通重试超时清理；活跃账号下即使目标不存在也保留去重记录，避免长延迟重试再建档案。
- 编辑：pet_id / expected_revision 必填，operation_id 为空。锁住所属且有效的行，比较表单打开时版本；不一致返回 `PT409/pet_revision_conflict`，没有任何字段写入。成功返回新版本。失效/已删目标返回 `pet_not_found`，不能转成创建。
- 继续通过私有 v2 写入并由版本 trigger 覆盖所有有效写入口，避免复制 coat/size 规则。私有 v2 不再授予客户端 execute；公开 v2 写入口明确返回 `pet_client_update_required`。撤销直接创建/修改档案事实的旧表级和列级授权，只保留当前 owner 软删除所需列授权及读取；软删除同样推进 revision。
- 新私有表启用 RLS 且无客户端策略/授权；公开包装为 invoker，私有受控写入固定 search_path、重新验证 owner。按既有账号匿名化入口清理该账号回执，清理后旧 JWT 仍须被身份校验拒绝。不得因新表引入隐私残留或绕过。

保留旧读取，不保留不安全旧写入降级。准备并验证新客户端后协调迁移及客户端切换；旧版本写入明确提示更新。本计划不承诺旧客户端仍能继续编辑，也不引入一套长期双写兼容协议。

### 3.2 客户端：沿用原表单，增加可恢复状态

**编辑：** `startEdit` 固定保存 petID 和原 revision；之后列表刷新不更新这个编辑基准。缺少 revision 时禁止提交并要求重新加载，不能生成假版本。当前 `savePet` 的“找不到 editingPetID 就创建”分支必须拆开：编辑目标失效只能报错。

- 冲突时保留原草稿，不自动强制覆盖；沿用现有表单错误区提供“重新加载已保存档案”，覆盖本地草稿前确认，加载失败则原草稿继续保留。
- 更新超时、取消或响应解码失败属于“结果未知”，不宣称保存失败或成功，也不直接再提交；重新读取该宠物后让用户确认当前保存状态，再开始新编辑。复用排班的恢复流程，不做字段级自动合并。

**创建：** 首次提交生成 operationID，将账号、schemaVersion、operationID、不可变 draft 原子保存到按账号隔离的单条待确认文件，再发送 RPC。保存文件失败则不发送。采用发布 Coordinator 的 Application Support、排除备份和文件保护方式，不放 UserDefaults 或日志。

- 结果未知时保持同一编号、同一内容；再次进入或重启后提供“继续确认”，仅用户点击时重放，不后台重试。已有待确认创建不能被新的创建草稿覆盖。
- 退出表单不代表撤销已发出的创建，保留待确认记录并在现有首页状态区域提供恢复入口；不新增独立恢复中心。明确收到服务端输入拒绝后才可解除冻结、编辑并生成新的创建意图。
- 收到权威结果并交接到当前宠物后清理记录。清理失败必须保留可重放状态，不能开放第二次创建；重放不会重复插入。未知版本/损坏记录不能被静默删除或覆盖。
- 复用现有 session 校验方式，在网络调用前和回写前验证当前账号；另一账号不能读取、重放或清理该记录。同账号下次进入才恢复。
- 照片仍走现有独立上传流程；照片失败不得重新创建宠物。本次不承诺照片上传事务化或照片跨重启续传，恢复界面不得暗示未确认的照片已保存。

### 3.3 读取：复用双重响应校验

- `CustomerPetsStore` 增加 loadID 和 mutationRevision；每次 load 固定捕获两者。开始创建、更新、删除、头像上传/删除时先递增 mutationRevision，使旧读取立即失效。
- 每一个 await 后、每次列表/照片/缓存/错误回写前均判断账号仍有效、任务未取消、loadID 相同、mutationRevision 相同。旧请求的 defer 不能清除新请求的 loading 状态。
- `photoDataMap` 当前内部会写缓存：改为先返回下载结果，仅在响应仍有效后统一写缓存，不能只在函数返回后才挡住 UI 更新。
- 写入期间不发起新的宠物 load；结束后仍通过现有刷新入口更新，不新增定时器。首页在宠物表单显示时暂停自动宠物刷新只是减少干扰，正确性由 Store 保证；不得连带停止其他首页必要状态刷新。
- 表单草稿、编辑基准不由后台 load 改写。取消/失效的旧请求不得写错误、恢复已删除条目或重新缓存旧头像。

## 4. 工作包

### WP-01 服务端安全写入契约

**Files:** 新增 `supabase/migrations/<CLI生成时间戳>_pet_profile_reliability.sql`、`tests/migrations/pet-profile-reliability.test.mjs`；必要时在切换节点使用独立增量迁移，不编辑旧迁移。

**Interfaces:** 产出 3.1 的 v3 JSON 契约、revision、创建回执、错误码；仍使用现有私有宠物事实校验。

- [x] 写静态迁移保护测试，先确认缺少上述契约时失败；这些测试只验证定义，不替代行为验收。
- [x] 实现版本、原子创建/重放、编辑 CAS、权限收口与回执生命周期。审查所有旧 grants 和实际依赖，不按“新客户端不用了”判断旧入口安全。
- [x] 运行 `node --test tests/migrations/pet-profile-reliability.test.mjs tests/migrations/matching-input-contracts.test.mjs tests/migrations/pet-capacity-acceptance.test.mjs`；全部通过后才交接客户端。

### WP-02 表单冲突与创建恢复

**Files:** 修改 `Core/Models/CustomerPet.swift`、`Core/Repositories/CustomerPetRepository.swift`、`Core/Infrastructure/Supabase/SupabaseCustomerPetRepository.swift`、`Features/Customer/Pets/CustomerPetsStore.swift`、`CustomerPetFormView.swift`、`CustomerPetsView.swift`、必要的 `Features/Customer/CustomerTabView.swift` session 注入；路径均位于 `ios/Beckon/Beckon/`。新增同一 Pets 目录下 `PendingPetCreation.swift`，集中单条记录及文件存储，不新建通用 Coordinator。扩展 `ios/Beckon/BeckonTests/CustomerPetFeatureTests.swift`。

**Interfaces:** `CustomerPet.revision: UUID?`（缺失只允许读取）；`createPet(customerID:operationID:draft:) -> CustomerPetSaveResult`；`updatePet(petID:expectedRevision:draft:) -> CustomerPet`；`pet(customerID:petID:) -> CustomerPet?`。新增结果类型承载 petID、resultRevision、replayed、state 和可选当前 pet；非 active 结果不能被当作新增卡片。draft 增加 Codable；错误映射增加 revisionConflict、operationIntentChanged、petNotFound、clientUpdateRequired。

- [x] 扩展现有 Fake 和测试：创建响应丢失、持久化失败/重启/账号切换、编辑冲突/结果未知、编辑目标消失；先验证针对性失败。
- [x] 接通 v3、固定编辑基准、单条 pending 文件及现有表单内恢复交互；更新实际协议 conformer/调用方，不大规模拆分 Store。
- [x] 用指定 Simulator 运行 CustomerPetFeatureTests，确认成功路径及新增失败恢复路径通过；草稿保留和按钮状态不得只靠截图判定。

### WP-03 旧读取隔离

**Files:** 继续修改同一 Pets Store/View 和 `CustomerPetFeatureTests.swift`；不改其他资料 Store。

**Interfaces:** Store 内私有 `isCurrentLoad(_:revision:) -> Bool`、loadID、mutationRevision；复用现有 load/保存/图片入口，无新公共同步协议。

- [x] 用可控 continuation 的现有 Fake 加入乱序测试，固定顺序而非 sleep：旧 load 晚于更新/删除、两次 load 倒序返回、旧头像晚返回、旧错误/defer 晚返回。
- [x] 接入各回写点和缓存写入保护；保留有效的新读取和当前操作的错误提示，不用“忽略所有错误”通过测试。
- [x] 重跑 CustomerPetFeatureTests；只有相关共享代码发生变化时才补跑对应 Profile/图片缓存测试，不重复无关匹配全矩阵。

### WP-04 集成、Simulator 与数据库验收

**Files:** 复用 `scripts/testops-core.mjs` 的 REST/账号工具及既有测试安全边界；最多新增一个定域 runner `scripts/test-pet-profile-reliability.mjs`，不扩展通用 TestOps 平台。必要 UI 用例放现有 `ios/Beckon/BeckonUITests/TestOpsLaunchSmokeTests.swift` 并复用 UIFlowDriver；文档仅更新本计划、Current State 和受影响的 Backend Contract 条款。

- [x] 在获授权的后端验证下表 DB/HTTP 项，包含真实独立会话竞争、明确拒绝路径、写入回读和按 run 精确清理。默认不修改远程；runner 必须遵守现有项目与 `TESTOPS_REMOTE_WRITE_APPROVED=1` 门禁。
- [x] 两个 Simulator 登录同一既有测试账号，完成三条交互链：两端编辑冲突；创建已提交但丢弃响应后重启恢复；刷新进行中保存/删除。使用 accessibility identifier/现有 driver，截图仅用于最终状态或失败定位。
- [x] 响应丢失用现有 DEBUG + Simulator 故障注入模式，必须在真实 RPC 已返回成功后丢弃客户端响应；不能用请求发出前断网冒充。乱序刷新用可控 Fake 测试作为精确证据，UI 只验证实际交互衔接。
- [x] 集成节点一次运行 `./scripts/ios-build.sh`、`./scripts/ios-test.sh`、`./scripts/preflight.sh`、`node scripts/context-hygiene-check.mjs --full`。Xcode 串行；失败定位后只重跑受影响证据，相关状态未变的通过结果可复用。
- [x] 同一次完成记录写明版本、通过/失败、跳过、迁移应用和恢复事实。未授权或未执行远程验证时只报告本地完成，不称后端已部署或整体已验收。全目标验收后才按站立 Git 授权进行当前分支的范围内完成提交/推送。

针对性 Swift 命令，`CODEX_IOS_DESTINATION` 使用当前已发现的 Simulator，不修改 scheme：

```bash
xcodebuild -project ios/Beckon/Beckon.xcodeproj -scheme Beckon \
  -destination "$CODEX_IOS_DESTINATION" \
  -only-testing:BeckonTests/CustomerPetsStoreTests \
  -only-testing:BeckonTests/CustomerPetKeyboardFocusContractTests \
  -only-testing:BeckonTests/CustomerPetPhotoPathTests test
```

## 5. 验收矩阵

| 编号 | 场景与必须断言 | 最低证据 |
|---|---|---|
| A01 | 同一 operation 同内容顺序/并发创建，只有一只宠物、一条回执、同一 pet_id | DB/HTTP 独立会话 |
| A02 | 相同 operation 不同内容拒绝；不同 operation 同名宠物可以创建 | DB/HTTP |
| A03 | 已提交后丢响应，关闭表单/重启再恢复仍是原 pet_id，不新增、不丢入口 | Store + Simulator + DB 回读 |
| A04 | 文件落盘失败不发请求；损坏/未知版本不覆盖；换号不能发送或显示原账号 pending | Store/文件测试 |
| A05 | 两端同版本编辑不同字段，恰好一个成功、另一个 409，胜者所有字段不被败者覆盖 | DB 竞争 + 双 Simulator |
| A06 | 编辑期间列表刷新到新版本，提交仍使用最初基准，不能给旧草稿套新 revision | Store |
| A07 | 冲突/更新结果未知保留草稿，重新加载失败仍保留；明确确认重新加载后才能再次保存 | Store + UI |
| A08 | 编辑目标被删/本地暂时找不到时不能走创建；重放已编辑/已删除宠物的创建回执不覆盖、不复活 | Store + DB/HTTP |
| A09 | 匿名、错误角色、其他 owner、已匿名化账号不能调用或重放；旧 RPC/直接事实写入不能绕过；合法软删除继续可用 | DB/HTTP 权限负例 |
| A10 | 旧列表晚于创建/编辑/删除完成，不能改变较新列表；第二次 load 胜出，旧错误/defer 不干扰 | 可控 Store 乱序测试 |
| A11 | 旧照片下载在上传/删除/换号后返回，不改图片、缓存或错误；新有效照片仍正常显示 | Store + 缓存断言 |
| A12 | 保存/重读保留体重、未知值、coat 来源；新请求使用最新档案，已有请求/预约快照不随之改写 | 定域 DB 回读 + 既有匹配输入回归 |

## 6. 自检与完成边界

**Review Focus:** 创建回执重放时目标已变/已删（A08）；旧表单悄悄获得新版本（A06）；写入已成功但客户端收到失败（A03/A07）；旧图片通过缓存侧路回写（A11）；新 RPC 正确但旧授权仍可绕过（A09）。这些条件均有明确归属和测试，不另建审计工作包。

设计已自检：三个原问题各有服务端/客户端责任；创建的“可重放”与编辑的“先核对”没有混用；数据库 revision 与客户端 mutationRevision 互不替代；旧接口收口不误伤软删除；既有匹配事实与历史快照保持不变。

实现完成须同时满足 WP-01 至 WP-04 与 A01 至 A12 的对应证据。只通过静态测试、只在内存防重、只让界面不闪烁，都不能关闭任务。本次完成状态以第 7 节验收为依据。

## 7. 执行记录

- 实现：新增 `20261017105527_pet_profile_reliability.sql`，复用私有 v2 事实写入；客户端仅新增单条 pending 存储，沿用现有 Store/Repository、session 校验与表单。无新依赖、通用同步框架或照片事务改造。
- RED/GREEN：三个迁移保护测试先失败，补齐后相关迁移测试 21/21；Store 先复现失效编辑误创建及旧照片恢复，修复后原定向 47 个测试通过（`/tmp/beckon-t406-pets-green-v4.log`）。最终覆盖另补待确认清理失败、有效未来文件、上传/换号旧照片及创建/新读取乱序，最终计数见集成结论。
- 远程：授权项目已应用本次迁移；最终 linked history 对齐至 `20261017105527`，重复 dry run 无待应用项（`/tmp/beckon-t406-migration-list-final.log`、`/tmp/beckon-t406-migration-after.log`）。Advisors 无 ERROR，仅既有泄露密码保护 WARN，无新增性能/安全问题（`/tmp/beckon-t406-advisors.json`）。
- DB/HTTP：独立会话创建防重、编辑竞争一成一败、重放已变/已删记录、所有权/角色/匿名/匿名化拒绝、旧 RPC/表写拒绝及合法软删除通过。新 discovery 读取胜者最新事实；既有需求和预约摘要不变。最终证据 `artifacts/testops/T406-b5146a1c/result.json`，`restored=true`，宠物及回执精确清理为零（`/tmp/beckon-t406-backend-final-v2.log`）。
- Simulator：iPhone 17 Pro + iPhone 17e，iOS 26.5，同一既有 BTC-001。17 Pro 打开旧版本改为 25lb，17e 保存 30lb；前者收到冲突、仍保留 25lb，确认重载后显示 30lb。真实创建 RPC 成功后 DEBUG 丢弃回执，退出表单并重启后通过 Confirm Pending Pet / Confirm Save 恢复；数据库前后同一 petID/operationID/revision，恰一行，恢复入口消失。刷新、删除、再刷新后条目未恢复；精确乱序由 continuation 测试覆盖。使用语义元素定位，未进行截图循环。证据 `/tmp/beckon-t406-ui-before-restart.json`、`/tmp/beckon-t406-ui-after-restart.json`；fixture `artifacts/testops/T406-495e4ec6/result.json` 已恢复。
- 验证修正：首次错误使用文件名筛选得到零测试，已改实际 suite 并排除该结果；旧 fixture 依赖误创建分支，改为加载真实编辑对象并断言 update=1/create=0。后端 runner 的缺失 breed 和新增断言的嵌套字段路径错误均先精确清理，再按真实契约修正重跑，未调整产品验收标准。
- 自检：重点复查 CAS 基准、回执删除生命周期、旧授权绕过、账号切换、晚返回缓存及失败清理；无遗留阻断发现。仓库禁用 subagent，使用当前会话代码自审。范围外原有修改不纳入 T-406 提交。
- 集成结论：`ios-build.sh` 成功（`/tmp/beckon-t406-build.log`）；`ios-test.sh` 成功，xcresult 汇总 797 passed / 0 failed / 46 skipped（含参数展开为 929 passed，非额外独立测试），日志 `/tmp/beckon-t406-full-test.log`。跳过项为 40 个需显式 fixture 的既有 UI TestOps 和 6 个单独配置的交互/邮件/独立进程用例；T-406 的 DB/HTTP、两端 UI 及故障注入无跳过。最后仅追加一个乱序测试、未再改产品代码，定向 50/50、3 suites 通过（`/tmp/beckon-t406-pets-final.log`），复用完整回归而不重复启动全套。最终 preflight 通过；full hygiene 84 documents、0 errors/0 warnings。125 条迁移本地/远程对齐。完成提交按 `T-406:` 从 Git 查询，不在文档写自引用 hash。
