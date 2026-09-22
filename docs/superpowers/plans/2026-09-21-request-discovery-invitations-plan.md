# 推荐浏览、定向邀请、需求池与收藏实施计划

> **For agentic workers:** 使用 `superpowers:executing-plans`，由当前执行者连续完成工作包；项目禁用 subagents。复选框是验收记录，不是暂停、重新征求普通确认或微步骤提交的边界。

<!-- task-artifact
task: T-397
status: active
type: plan
-->

**Goal:** 实现同一 Request 下的推荐轮播、全量候选、定向邀请、可选需求池和私人收藏，补齐无人报价/到期恢复，保持唯一成交和权限安全。

**Architecture:** SwiftUI -> 有界 feature Store/flow state -> Repository -> 受控 RPC；复用现有资格与评分内核、报价/Booking 和分发队列。旧新发送共享一个PublicationCoordinator，首次回执仅归既有publish operations所有；独立发现/报价入口委托共用内核，不合并权限。私有预览先于公开发布，显式邀请与公开池共享 Request，收藏独立于交易。

**Tech Stack:** Swift 6 / SwiftUI / 现有 iOS deployment target；既有 Supabase Swift SDK、PostgreSQL/PostGIS、站内通知；Node 内置测试、Swift Testing/XCTest、现有 Simulator/TestOps。无新依赖、独立服务或通用测试框架。

**Spec:** [详细设定](../specs/2026-09-21-request-discovery-invitations-design.md)。本计划落实该文全部范围；参数与语义由设计文档拥有，不另复制一套规范。

**状态:** 2026-09-21 完成文档编写与自检，业务实施未开始。T-397 只代表编写交付；以后执行时从 Current State 分配/恢复实施任务，沿用本计划并更新元数据，不把文档完成标成软件完成。本轮没有迁移、后端查询、部署、账号/Storage/夹具写入或客户端运行验收。

T-398根据现有代码补齐设计第7节的模块复用约束，并将验证并入原工作包及A01-A48；没有增加实施阶段或另立重构计划。

## 1. 全局约束

- SwiftUI -> Store/flow state -> Repository -> 受控 RPC；不新增依赖、独立服务或通用任务框架。
- 一份 Request、多入口、多报价、至多一个 Booking；邀请/收藏/浏览不占时段、不代表成交。
- 不隐式扩大需求条件，不把收藏、滑动、未回复写入专业评分或长期偏好。
- 全部合法候选可分页发现，不以排名阈值、缓存容量或加载速度截断全集。
- 保留现有请求额度、幂等、terms revision、RLS、资源/容量/缓冲/DST、评价和隐私边界。
- 仅本地 Simulator 客户端验收；真机、签名、上架、APNs 部署和真人推荐质量评审不作为完成门槛。
- 实施开始与远程 DDL/夹具/恢复需本计划明确授权；文档任务不执行，不继承旧任务授权。
- 保留已有用户改动；整个采用目标验收完成后才按工作分支授权提交/推送，不自动合并或创建 PR。

工作方式：一包内实现、针对性验证、自检，直接进入下一包；HD-07 集成/发布节点运行完整回归。静态 migration 测试只证明源码契约，不能代替真实权限、锁、Storage 和 HTTP 验收。只维护 Current State、本计划复选框及末尾简短验收记录，不另写逐日工作日志。

## 2. 审查重点

下面五项最容易漏在正常点击之外，已分别绑定工作包与验收编号：

1. 发布已提交但回执丢失，30分钟预览到期后重启仍恢复原 Request，不重新发单：HD-02/05，A12-A14。
2. 已在需求池打开的详情页，在池关闭后仍尝试报价、读原始列或请求图片：HD-02/03/06，A18-A22。
3. 卡牌和全量列表之间发生资格变化或收藏操作，不能重复、漏人、混页或清空用户选择：HD-01/04，A05-A09、A33-A35。
4. 收藏的美容师暂停/删除，或者顾客换号，不能继续展示被撤销的身份媒体/前一账号名单：HD-03/04，A26-A31。
5. 邀请截止、Request截止、已有报价有效期不同；后台/重启/竞态中不得错误保留或错误终止报价：HD-02/05/06，A15-A17、A23-A25、A39-A45。

## 3. 顺序、交付物与权限

| 包 | 交付物 | 前置 | 退出条件 |
|---|---|---|---|
| HD-00 | 精确影响面、迁移/回退次序、授权边界与最小夹具 | 采用本计划 | 不遗漏旧API/原始表/Storage/回执；无新通用工具 |
| HD-01 | 私有预览与全量候选读取 | HD-00 | 无公开副作用；复用资格/评分，合法全集和游标正确 |
| HD-02 | Request 分发、邀请、池与并发权限 | HD-00/01 | 双入口同单；关闭池即时生效；幂等/锁/唯一成交成立 |
| HD-03 | 收藏与候选资料/媒体权限 | HD-01/02 | 私人收藏可同步；头像/照片不越权，匿名化清理完整 |
| HD-04 | 推荐轮播、完整列表、详情与收藏客户端 | HD-01/03 | 原生浏览无隐式操作；跨页面状态统一；假失败与零候选区分 |
| HD-05 | 首次发送、追加、等待进展、历史恢复和美容师入口 | HD-02/04 | 客户端从草稿到未成交/成交均闭环；重启恢复可信 |
| HD-06 | 独立会话竞态、旧版兼容与真实双端交互 | HD-01 至05 | A01-A48 按层级通过，既有关键流程不回归 |
| HD-07 | 完整回归、受控启用、精确恢复与Git收尾 | HD-06 | 代码、真实部署、恢复、证据各自明确，无未完成阻断项 |

所有包属于一个实施目标，不能把“HD-04 UI已显示”当全部完成。实施授权不自动允许真实用户数据改造、Auth账号创建/删除、Storage整桶开放或无关项目操作。

已有 C/G TestOps 账号优先；授权范围包含必要 Beckon 迁移、指定 run-owned 业务夹具、受控修改及精确恢复时才能运行真实后端验收。只在确实缺少访问/账号/必要媒体时报告具体缺口，不引入真机/上架作为替代前置。

## 4. 文件与职责

表内 `Core/`、`Features/`、`SharedFeatures/`、`App/` 相对 `ios/Beckon/Beckon/`；Tests 相对 `ios/Beckon/`。新增名称是实施目标，不表示文件已存在。新迁移通过已安装 CLI `supabase migration new <名称>` 生成真实版本，禁止预造时间戳或改写已应用 SQL。

| 所有者 | 新文件 | 受影响既有文件 |
|---|---|---|
| Discovery | `Core/Models/CustomerGroomerDiscovery.swift`；`Core/Repositories/CustomerGroomerDiscoveryRepository.swift`；`Core/Infrastructure/Supabase/SupabaseCustomerGroomerDiscoveryRepository.swift`；`Features/Customer/Discovery/CustomerGroomerDiscoveryStore.swift`、`CustomerGroomerDiscoveryView.swift`、`CustomerGroomerListView.swift`、`CustomerGroomerDetailView.swift` | `Core/Models/MatchRanking.swift`、`MatchingEvidence.swift`；`SharedFeatures/Matching/BeckonFitEvidenceBlock.swift`；`App/AppComposition.swift` |
| Distribution | `Core/Models/RequestDistribution.swift`；`Core/Repositories/RequestDistributionRepository.swift`；`Core/Infrastructure/Supabase/SupabaseRequestDistributionRepository.swift`；`Features/Customer/Requests/CustomerRequestDistributionStore.swift`、`CustomerRequestProgressView.swift` | CustomerRequestsStore、WizardState/View、RequestsView、DashboardView、DetailView；CustomerRequestRepository/SupabaseCustomerRequestRepository；CustomerTabView |
| Publication恢复 | 从旧Store窄抽取`Features/Customer/Requests/CustomerRequestPublicationCoordinator.swift`、`PendingRequestPublication.swift`，不新增全局基础设施 | CustomerRequestsStore.publish/持久化/恢复、DistributionStore、CustomerTabView会话装配；旧照片上传与重试路径继续使用 |
| 安全美容师投影/显示 | `Core/Models/MarketplaceGroomerSummary.swift`；`Core/Infrastructure/Supabase/MarketplaceGroomerSummaryRow.swift`；`Features/Customer/Discovery/GroomerCandidateSummaryView.swift`、`GroomerCandidateActionsView.swift` | Discovery/Favorites仓储和页面；涉及的旧CustomerOfferGroomerProfileRow做安全适配；不改owner GroomerProfile编辑模型，不复制报价卡 |
| Favorites | `Core/Models/GroomerFavorite.swift`；`Core/Repositories/GroomerFavoritesRepository.swift`；`Core/Infrastructure/Supabase/SupabaseGroomerFavoritesRepository.swift`；`Features/Customer/Favorites/GroomerFavoritesStore.swift`、`GroomerFavoritesView.swift` | `Features/Customer/Profile/CustomerAccountView.swift`；AppComposition；CustomerTabView |
| Groomer/安全读取 | 在现有模型内增加安全 Request 摘要，不新增通用 router | GroomerRequest、GroomerRequestsStore/View、GroomerRequestRepository/SupabaseGroomerRequestRepository、GroomerOfferFormState、PrivateImageLoader、SupabasePrivateImageDataSource、SupabaseParticipantAvatarLoader |
| 透传与测试替身 | 新领域 Fake 在所属测试文件 | `Core/Diagnostics/DebugRepositoryWrappers.swift`、既有 Preview/CustomerRequestFeatureTestFakes、CustomerRequest/GroomerRequestFeatureTests |
| Backend | migrations 名称 `request_discovery_context`、`request_distribution`、`customer_groomer_favorites`、`request_distribution_cutover` | 在新迁移中替换受影响函数/触发器/策略；不编辑历史文件 |
| Tests | `tests/migrations/request-discovery.test.mjs`、`request-distribution.test.mjs`、`groomer-favorites.test.mjs`；`tests/fixtures/request-distribution.sql`；`scripts/test-request-distribution.mjs` | 复用已有 TestOps fixture/replay/身份加载；不新建控制模拟器框架 |
| Native Tests | `BeckonTests/CustomerGroomerDiscoveryTests.swift`、`GroomerFavoritesTests.swift`、`RequestDistributionTests.swift`；`BeckonUITests/TestOpsRequestDiscoveryTests.swift` | 保留既有评分、恢复、报价、导航和隐私测试 |
| 契约文档 | 无新长期规则文件 | 实施完成时精确更新 SUPABASE_CONTRACT、RLS_RPC_POLICY、STORAGE_POLICY、DATA_FLOW、FEATURE_INDEX 与涉及的 DESIGN_SYSTEM 条目 |

不把新 Store 代码堆入已很大的 CustomerRequestsStore。原Store继续管理需求/报价/照片上传重试；分发Store拥有新发送界面状态与池动作，首次发送和旧未决恢复都委托唯一PublicationCoordinator。协调器持久保存已确认Request ID再通过显式结果交接原照片流程，不重复publish或产生第二份未决文件。收藏Store与协调器在顾客会话内共享，退出清理内存并隔离磁盘身份，不创建跨账号全局单例。

### 4.1 复用接线与非目标

| 消费方 | 共用实现/单一状态 | 保留独立的部分 |
|---|---|---|
| Wizard、预览、重发 | 既有Draft/地址/时间校验；PublicationCoordinator持久意图 | Wizard步骤与Discovery浏览不是同一个Store，照片上传仍由既有路径负责 |
| 轮播、完整列表、资料、收藏 | MarketplaceGroomerSummary；候选摘要/动作组件；FavoritesStore；按ID叠加DistributionStore状态 | 详情布局、favorite keyset分页与ranked候选分页保持各自语义，不造万能页面或分页协议 |
| 旧Request、预览、Offer后端 | 可信context适配后委托同一资格/评分核心 | 真实Request状态、私有session、Offer目标事实与actor授权分别校验；预览不进入worker |
| 旧ranked读取与新发现 | cursor签名、快照表/存取清理、每actor共用预算 | 成员查询、scope/purpose和安全输出分离；不强塞进旧Offer RPC |
| 首次发送、原子替换、重试 | request_publish_operations及提取的发布写核心 | 追加/池切换/撤回才使用request_distribution_operations，不双存首次回执 |

旧代码抽取后同时将受影响入口改为委托，删除被替代的活跃实现；历史迁移不编辑。安全模型不复用私人字段，客户端不复刻服务端F/Q/D。禁止借此全量拆旧Store、造全局事件总线、通用Repository、DTO生成平台或独立复用检测工具。HD-00只记录实际调用差异，不再次设计一套模块体系。

## 5. 跨包客户端契约

RPC 及其字段由设计第5节定义。Swift最小接口如下；新增wire DTO仅在Supabase基础设施层，同一安全资料投影供相关仓储共享；已有RankedPageRow直接复用，不为了调整旧文件位置展开清理。业务模型不泄漏数据库原始行。

```swift
enum GroomerDiscoveryScope: Equatable, Sendable {
    case preview(sessionID: UUID, inputDigest: String)
    case request(id: UUID, termsRevision: UUID)
}
enum GroomerDiscoverySort: String, Codable, Sendable { case fit, distance }
struct DiscoverySession: Equatable, Sendable {
    let id: UUID
    let inputDigest: String
    let expiresAt: Date
}
struct RequestDistributionReceipt: Equatable, Sendable {
    let requestID: UUID
    let termsRevision: UUID
    let distributionRevision: UUID
    let poolEnabled: Bool
    let invitedGroomerIDs: [UUID]
}
struct GroomerFavoritesPage: Sendable {
    let items: [FavoriteGroomer]
    let nextCursor: String?
    let revision: String
    let asOf: Date
}
@MainActor protocol CustomerGroomerDiscoveryRepository: AnyObject {
    func prepare(draftID: UUID, draft: GroomingRequestDraft) async throws -> DiscoverySession
    func candidates(scope: GroomerDiscoveryScope,
        page: RankedPageRequest<GroomerDiscoverySort>) async throws -> RankedPage<DiscoveredGroomer>
    func profile(scope: GroomerDiscoveryScope, groomerID: UUID) async throws -> DiscoveredGroomer
}
@MainActor protocol RequestDistributionRepository: AnyObject {
    func publish(operationID: UUID, session: DiscoverySession, poolEnabled: Bool,
        groomerIDs: [UUID]) async throws -> RequestDistributionReceipt
    func invite(operationID: UUID, requestID: UUID, expectedTermsRevision: UUID,
        groomerIDs: [UUID]) async throws -> RequestDistributionReceipt
    func setPool(operationID: UUID, requestID: UUID, expectedRevision: UUID,
        enabled: Bool) async throws -> RequestDistributionReceipt
    func withdrawInvitation(operationID: UUID, requestID: UUID,
        groomerID: UUID) async throws -> RequestDistributionReceipt
    func progress(requestIDs: [UUID]) async throws -> [CustomerRequestProgress]
}
@MainActor protocol GroomerFavoritesRepository: AnyObject {
    func setFavorite(groomerID: UUID, isFavorite: Bool,
        expectedRevision: UUID?) async throws -> GroomerFavoriteState
    func favorites(scope: GroomerDiscoveryScope?, limit: Int,
        cursor: String?) async throws -> GroomerFavoritesPage
}
```

HD-01定义`MarketplaceGroomerSummary`白名单（id、businessName、bio、yearsExperience、粗略城市/州、公开评分/评价数、验证状态和授权avatar引用，不含住宅坐标/门牌/联系方式）；`DiscoveredGroomer`组合该summary、既有`MatchEligibilityEvaluation`/`MatchingEvidence`与设计5.2其余字段。HD-02定义`CustomerRequestProgress`；HD-03定义`GroomerFavoriteState`（isFavorite/revision）与`FavoriteGroomer`（id/favoritedAt、相同summary可空、available/paused/unavailable、可选本次资格）。复用已有`RankedPageRequest<Sort: Sendable>`、`RankedPage.canAppend`、`RankedPageRow`和时间解析，不另建发现分页协议或隐式改matching-v1版本。

HD-05的`CustomerRequestPublicationCoordinator`是首次发布意图唯一读写者，通过注入既有CustomerRequestRepository和新RequestDistributionRepository选择协议；只重放旧已受理发布，不新增旧协议发布。`PendingRequestPublication`兼容原customerID/draft/photos无版本文件，并新增有版本的discovery意图及已确认Request/待交接阶段。旧结果不能伪装成含distributionRevision的新回执。RequestsStore与DistributionStore只接收结果，不各自持久化/恢复；原照片处理接收真实Request ID和不可变photos，不得再调用createRequest。

候选页中的favorite/invitation字段仅用于初始化操作覆盖层；后续revision/动作回执优先，晚返回旧页不得覆盖本地已确认状态。可变状态只有上述所属Store一份，View接收数据/动作闭包；换号、scope变化和取消都校验当前会话/读取generation。

Favorites 用上述领域内Page类型承接签名keyset cursor，默认limit=25、服务端最大50，不拿offset仿造稳定页。收藏成员/排序发生变化则旧cursor返回list_changed，安全profile信息与操作状态可刷新；有scope时硬资格仍逐页检查。false最小状态/revision保留30天后清理，已清理的旧revision写不能覆盖新状态。

错误分类至少覆盖：notAllowed、discoveryExpired、discoveryChanged、requestChanged、distributionChanged、listChanged、groomerUnavailable、invitationLimitReached、requestLimitExceeded、operationIntentChanged、alreadyPublished(requestID)、clientUpdateRequired、networkUnavailable、cancelled。默认失败不能落成空候选、未收藏或发送成功。

## 6. 工作包步骤

### HD-00 影响面与最小验收输入

**Files:** 新 SQL 夹具/runner；受影响当前 migrations、Repository、媒体策略只读定位；本计划末尾仅记录实测差异。

**Interfaces:** 输入当前实现；输出给HD-01/02的权威上下文入口、锁顺序和旧写/读入口清单。至少包含 create_request_matches_for_request、refresh_candidate_evaluation、两版ranked reads、quote v2/v3、accept、replace、request SELECT、request-photos、通知深链、匿名化。设计7.1/7.2为定位清单，核对最新生效定义；只在本计划记录实际调用差异、抽取所有者和需改为委托的旧入口。

- [ ] 为现有请求上下文建立不改变业务的差分样例：同宠/地址/时间/score_as_of分别走原包装器和待抽取内核，expected state/reasons/witness、F/Q/D与MatchingEvidence相同；同时保留原固定预期，不能只比较两个共享实现的返回。固定/自定义服务、未知体型、DST及缓冲边界共用原fixture；Offer特有时间目标单独测。
- [ ] 将已有有效评分/接受证据限定到其原SHA/数据库定义；新的预览/分发/权限证据不复用为通过。记录当前CLI `--help` 支持的命令，安装或升级不作为默认动作。
- [ ] 冻结最小角色与样本：C1/C2、G1/G2/G3，加既有规模美容师至至少26位；同一组需求承载多个状态，不为每个断言重新播种。媒体优先复用授权测试账号的真实已有对象；缺少必要对象时精确列出所需授权，不放宽安全验证。
- [ ] 明确新增数据列、旧原始SELECT如何转到owner/safe RPC、何时启用旧接口门禁及可回退边界；没有可执行顺序不部署。

**退出:** 影响面覆盖上述入口；run manifest 可描述创建、修改、备份、恢复对象，不保存凭据，不创建Auth账号或通用数据生成平台。

### HD-01 私有上下文与全量发现

**Files:** Discovery模型/Repository、`request_discovery_context`、`request-discovery.test.mjs`、`CustomerGroomerDiscoveryTests.swift`。

**Interfaces:** 实现 prepare/candidates/profile；向HD-04提供同scope/cursor的前25项和安全详情；向HD-02提供规范化发布输入与digest。

- [ ] 写失败用例 A01-A09：预览不产生公开行/通知/额度；跨owner/篡改digest失败；前8与列表前8完全相同；第26位更适配者能进前8；pending/零/失败不同。
- [ ] 对evaluate_match_constraints/evaluate_match_eligibility_with_zones及match_target_keys/score_match_evidence窄抽取可信context重载，原request_id wrapper验证真实状态后委托同一规则；预览不调用带落库的refresh_candidate_evaluation。保存30分钟私有预览、完整规范发布输入（含备注/原子替换身份）和可信源revision；发送时源变化要求复核，不丢备注或偷换宠物快照。
- [ ] 实现完整粗筛、资格分组、同输入评分复用、稳定排序；复用match_cursor_encode/decode和match_browse_snapshots存取/清理，必要窄抽取helper并接回旧浏览，actor总预算共用。成员查询/purpose/scope与旧报价隔离，不复制整套ranked_marketplace_page。既有Request使用owner上下文，首次发布后preview scope按唯一publish回执解析为新Request只读别名，沿用原截止和draft平局键。
- [ ] 运行定向源码契约和真实只读/回滚差分；达到A01-A09、P01性能门槛后继续，不运行完整iOS回归。

测试关键断言（以下SQL中的 fixture actor/scope由runner绑定，不把SQL变量拼入凭据）：

```sql
-- 在受控事务中保存前后计数，preview RPC后必须均为0差量。
select count(*) from public.grooming_requests where customer_id = :customer_id;
select count(*) from public.request_matches where customer_id = :customer_id;
select count(*) from public.groomer_notifications where related_request_id = any(:run_request_ids);
-- ranking校验由独立预期ID序列比较，不能拿同一SQL函数当唯一oracle。
```

Run: `node --test tests/migrations/request-discovery.test.mjs`；Focused Swift: `xcodebuild -project ios/Beckon/Beckon.xcodeproj -scheme Beckon -destination "$CODEX_IOS_DESTINATION" -only-testing:BeckonTests/CustomerGroomerDiscoveryTests test`。destination使用既有可用Simulator，不预设机器UDID；Xcode写入串行。

### HD-02 分发、邀请与权威权限

**Files:** Distribution模型/Repository、`request_distribution`、`request-distribution.test.mjs`、既有Request/Groomer读写实现。

**Interfaces:** 实现publish/invite/setPool/withdraw/progress； quote和worker消费同一可报价谓词；后续Store不自行合成成功状态。

- [ ] 写失败用例A10-A25与A39-A45：双入口同pair、两次首次发送、scope过期重放、未受邀伪造match/quote、池开关/报价竞争、取消/接受与追加竞争。
- [ ] 实现schema和唯一回执所有权：首次发送/原子替换只扩展request_publish_operations；追加/池切换/撤回使用request_distribution_operations。提取原额度/快照/替换写核心并显式传分发上下文，旧wrapper改为委托，不是在旧发布自动广播后补UPDATE；所有触发器读取同事务的pool/邀请事实。
- [ ] worker、ranked/exact读取、直接表权限、quote/admission、request-photos和旧API共用分发事实，分别导出发现/新报价/旧报价管理/媒体访问规则，不共用宽松canAccess。offer关系不授予新报价；昂贵全量评分不放入逐行RLS或图片鉴权。新入口继续各自鉴权和实时复核。
- [ ] 5位上限、邀请pair唯一、明确期满、dismissal不复活、池关闭保留旧报价及revision隔离均在事务内成立；进展批量读取不再次计算全量专业评分。
- [ ] 运行真实角色负例及独立连接两种提交顺序；不能仅模拟HTTP返回或用同一事务顺序调用冒充竞争。

必须符合的控制流：

```text
authenticate actor -> resolve owner -> lock idempotency/request in existing order
-> replay accepted identical operation before checking preview expiry
-> reject changed intent or changed request terms
-> validate explicit pool consent + current recipients + locked quota
-> write one request/invitations/notifications/receipt atomically
-> return receipt; client subsequently fetches current request state
```

Run: `node --test tests/migrations/request-distribution.test.mjs`；真实验收经下文runner `--phase distribution`，受授权门禁保护。取得真实RED再修GREEN，不捕获权限错误并伪装零报价。

### HD-03 收藏、安全资料与媒体

**Files:** Favorites全套、`customer_groomer_favorites`、PrivateImage相关实现、隐私删除函数的新迁移、`groomer-favorites.test.mjs`、`GroomerFavoritesTests.swift`。

**Interfaces:** 收藏为owner私有目标状态写；发现/收藏共享安全资料DTO，owner/full Request与pre-booking safe DTO明确分离。

- [ ] 写失败用例A26-A31：跨账号、重复set、相反并发set、暂停/删除、媒体路径枚举、旧地址SELECT/owner读取；Storage权限用真实合法和非法actor验证。
- [ ] 实现owner收藏RPC/分页/上限，删除后的不可识别呈现；同一账号有两个客户端时旧revision不得覆盖新状态。复用HD-01的MarketplaceGroomerSummary/wire投影和现有图片loader；不得调用owner profile仓储、扩展参与者头像身份或将bucket改public。
- [ ] 将groomer-avatars的新增读取精确限定到活跃可发现业务profile；原customer头像、pet-photos、聊天图片和legacy bucket不随之放宽。request-photos按实时分发可见性读取。
- [ ] 把新会话/收藏/邀请/幂等记录的个人内容纳入既有匿名化处理，测试数据库回滚，不实际删除Auth/Storage账号。缓存与签名URL撤销局限如实说明，客户端不持久保存被撤权的新图片。
- [ ] 跑静态、Swift与真实授权负例A26-A31，确认已有Booking参与者取图未被破坏。

```swift
@Test func favoriteDoesNotInvite() async throws {
    let fixture = FavoritesFixture()
    try await fixture.store.setFavorite(fixture.groomerID, enabled: true)
    #expect(fixture.favoriteRepository.writeCount == 1)
    #expect(fixture.distributionRepository.callCount == 0)
}
```

`FavoritesFixture`是该测试文件内的Fake组合，记录两仓储调用并暴露固定groomerID；不用默认unavailable方法掩盖漏接线。Run: `node --test tests/migrations/groomer-favorites.test.mjs` 与同样方式的 `-only-testing:BeckonTests/GroomerFavoritesTests`。

### HD-04 推荐、列表与收藏原生交互

**Files:** CustomerDiscovery/Favorites Views与Store；CustomerAccountView、CustomerTabView、AppComposition、必要Debug透传。

**Interfaces:** 同一顾客会话复用favorites状态；同一scope共用DiscoveryStore实体/排序快照；发送按钮调用HD-05的显式分发动作，不在View写RPC。

- [ ] 写失败用例A32-A38：滑动零业务写、8卡/不足8/零/仅评估、尾页确认、前8合并到完整列表、收藏状态跨页一致、pending与error区分。
- [ ] 实现稳定尺寸轮播、页码与明确按钮；尾页不是美容师。完整列表与轮播共用一个DiscoveryStore的实体/ID和RankedPage.canAppend，使用已加载25项和游标，返回保留当前ID与位置；切sort才新建browse。GroomerCandidateSummaryView/ActionsView按数据与闭包组合，不复制完整报价卡或在View引入仓储。
- [ ] 收藏页挂Account及当前需求入口；无scope不编造适配，选择当前Request/创建新Request后再评估。复用FavoritesStore的revision与DistributionStore操作覆盖层，晚返回页不反转已确认动作；证据复用BeckonFitEvidenceBlock且scoreText=nil。共享顾客组件留所属Feature，跨角色组件才放SharedFeatures，业务不进DesignSystem。
- [ ] 定向Store测试完成后在Simulator验证一轮紧凑屏幕/大字号/VoiceOver可操作标签、长名称、缺图、网络失败和硬变化。截图只用于布局证据或失败，不每滑一次抓图。

```swift
@Test func carouselAndListShareCandidatesWithoutSending() async throws {
    let fixture = DiscoveryFixture(candidateCount: 26)
    await fixture.store.load()
    let ids = fixture.store.recommended.map(\.id)
    #expect(ids.count == 8)
    fixture.store.showAll()
    #expect(Array(fixture.store.visibleCandidates.prefix(8)).map(\.id) == ids)
    #expect(fixture.distributionRepository.callCount == 0)
    #expect(Set(fixture.store.visibleCandidates.map(\.id)).count == fixture.store.visibleCandidates.count)
}
```

`DiscoveryFixture`只用本地确定性Fake提供至少26位、两页与可注入pending/error。Run: Discovery/Favorites两个测试类；UI只跑本工作包标签，完整回归留HD-07。

### HD-05 发送、回应进展与未成交恢复

**Files:** CustomerRequestDistributionStore/ProgressView；WizardState/View、CustomerRequestsStore、RequestsView/Detail/Dashboard；GroomerRequestsStore/View、notification routing。

**Interfaces:** 依第5节抽取PublicationCoordinator，旧发布入口和新分发Store委托同一实例；原RequestsStore处理真实receipt后的当前Request精确读取与照片交接。旧PendingRequestPublication无版本文件仍可解码为legacyV4；discoveryV1意图包含session/digest/pool/recipients/operation/photos，不混淆RPC版本名。

- [ ] 写失败用例A12-A17、A23-A25、A39-A45：首次多对象点击、丢响应Close/重启、晚响应换号、池开关失败、旧版pending恢复、期限显示、历史入口。
- [ ] 将publish中的持久意图读写、协议选择、重放及会话取消窄抽取到PublicationCoordinator，并让旧新入口委托它，移除旧活跃副本。沿用账号隔离文件，兼容旧JSON/保护未知版本，发请求前原子保存不可变payload；确认Request ID后保存待照片交接状态，交接失败/重启不再次发单。不新增通用outbox。恢复后精确读当前Request，不依旧receipt显示open。
- [ ] 首次发布后留在候选页，通过短期scope别名保留排序、位置和游标，写动作改用真实Request ID；pool-only有明确发布按钮。修改条件回到旧atomic replacement模式，重新选择接收范围，失败保留旧请求和报价。
- [ ] 实现受邀状态与池状态、有效报价数量、最后检查时间；在可见容器复用ForegroundRefreshGate/foregroundRefreshable做45秒批量轻读，操作后刷新、截止点本地保守呈现；嵌套子页不重复注册兜底，不为每个卡片创建timer或后台轮询。
- [ ] 关闭区域纳入expired并有分页历史；cancelled/expired可从模板重发，重发生成新操作但不继承旧公开同意。美容师Requests同一条显示来源，Offers继续现有报价/撤回入口。
- [ ] 运行RequestDistributionTests及受影响原Customer/Groomer请求测试，模拟器完成一次定向、一轮池报价、一次无人报价到期恢复。

```swift
@Test func expiredPreviewDoesNotRepublishCommittedRequest() async throws {
    let fixture = DistributionFixture()
    await fixture.commitThenDropPublishResponse()
    await fixture.restartAfterPreviewExpiry()
    await fixture.store.retryPendingOperation()
    #expect(fixture.repository.createdRequestIDs.count == 1)
    #expect(fixture.store.requestID == fixture.repository.createdRequestIDs.first)
    #expect(fixture.repository.lastReplayedOperationID == fixture.originalOperationID)
}
```

Fake只用于Store恢复行为；相同幂等契约还必须通过真实RPC A12/A13，不能用此测试替代数据库约束。

### HD-06 集成、兼容与并发

**Files:** TestOpsRequestDiscoveryTests、单一request-distribution runner/fixture；cutover迁移草稿；必要既有Tests窄修。

**Interfaces:** 使用真实角色登录、正常Repository/RPC及UI；SQL只用于授权夹具准备/只读断言/明确数据库回滚探针，不替代需要验证的客户端业务写。

- [ ] 逐项执行A01-A48，API负责枚举/权限/并发/分页，Simulator负责按钮/导航/持久恢复。用同一运行台账标记层级，禁止把48条断言写成48次真人预约。
- [ ] 至少三个独立Simulator容器：顾客C1、受邀G1、池候选G2；C2/G3仅在隔离/多报价需要时切换既有账号。语义AX/XCTest控制，保存关键页面和失败截图，不建设截图驱动工具链。
- [ ] 受控联动：邀请G1并开启池 -> G1仅一条需求 -> G2从池报价 -> C1关闭池 -> G2旧报价仍可选、G3新报价失败 -> C1接受一份 -> 所有其他入口结束 -> 双端重启一致。
- [ ] 第二条需求定向-only，从完整列表继续邀请，收藏跨登录恢复，实际邀请截止/请求到期有恢复入口；计时核心可用固定注入时钟单测，真实后端截止使用短期合法夹具加真实等待，不改设备/服务器时间。
- [ ] 复验旧受理回执、旧写client_update_required、旧读取不能泄露新定向Request、原Booking履约仍可用，随后进行性能P01-P03。不足或失败不把功能标为完成。

runner命令契约在新脚本内实现并提供`--help`：`--run-id`、`--phase prepare|discovery|distribution|favorites|races|performance|verify|restore`、`--allow-remote-write`、`--allow-restore`。写phase必须显式授权开关并校验Beckon项目；verify不隐含prepare，restore精确读取本run manifest，不靠模糊前缀删数据。

```sh
node scripts/test-request-distribution.mjs --help
node scripts/test-request-distribution.mjs --run-id "$RUN_ID" --phase verify
```

以上是待实现runner的目标命令，不表示当前已有脚本或已运行。UI方法按生命周期而非一断言一方法组织，至少 `testPrivatePreviewAndFavorites`、`testInvitationAndPoolLifecycle`、`testRecoveryAndExpiredHistory`，共享现有TestOps驱动器。

### HD-07 验收、启用、恢复与收尾

**Files:** 新cutover/enable迁移、受影响活动契约、本计划末尾验收记录、Current State；不改无关历史脏文件。

- [ ] 先在关闭新入口的兼容模式部署增量对象；受控测试账号验证同一实现。涉及原始读取撤权/旧发布停用的cutover必须与新客户端就绪协调，新功能尚未启用不能先静默破坏旧流程。
- [ ] 在最终代码/迁移集上运行 `./scripts/preflight.sh`、`./scripts/ios-build.sh`、`./scripts/ios-test.sh` 和受影响真实后端负例/竞态；截图验证新增可见组件，不重跑未变的大型历史计划。
- [ ] 按已授权范围启用新路径；核对部署函数/ACL/策略指纹、实际迁移历史及空重复dry-run。仅本地通过时不得写“已部署”；不以静态文件存在证明权限已生效。
- [ ] 精确恢复夹具、预览/snapshot、邀请、收藏、通知、操作回执及受控资料；原业务字段和既有对象一致，合法资格revision前进不倒写。保留run-owned新对象ID和恢复差量，不记录secret。
- [ ] 执行 `node scripts/context-hygiene-check.mjs --full`、`git diff --check`；本计划末尾写摘要、证据路径、跳过/限制、部署与恢复状态。检查staged只含本目标后一次完成提交/推送当前工作分支。

回退演练：关闭新发现/发送入口时，旧已发送的定向Request仍不公开；owner可读进展/报价、取消，美容师仍可管理已有报价。不能恢复旧宽松SELECT或自动广播作为回退。允许回退展示，不回退隐私与订单约束。

## 7. 验收矩阵

类别：DB=真实角色SQL/RPC或独立连接，HTTP=认证请求，Unit=本地确定性逻辑，UI=原生Simulator动作。组合标记需要各自证据；没有依赖远程环境的默认suite skip不能替代必需DB/HTTP/UI。

| ID | 场景和必须成立的结果 | 层级 | 包 |
|---|---|---|---|
| A01 | 草稿预览前后公开请求/match/通知/额度差量0 | DB | 01 |
| A02 | 他人session/request/digest、匿名或错误role拒绝 | DB/HTTP | 01 |
| A03 | 旧wrapper/新context同输入资格、witness、F/Q/D/证据与固定预期一致；改宠物/地址/服务不复用旧候选或偷偷发布新快照 | DB/Unit | 01 |
| A04 | 0/1/3/8/26候选，卡牌数量真实；estimated/assessment/pending不混淆 | Unit/UI | 01/04 |
| A05 | 第26位高适配者进入首8，全部候选无截断 | DB/HTTP | 01 |
| A06 | 推荐和完整列表同前8、无重复/漏项；首次发布后scope别名保持排序/位置/分页且不重复发送 | DB/Unit/UI | 01/04/05 |
| A07 | 软评价变化期间合法分页继续，硬资格/隐私变化停止旧游标 | DB/HTTP | 01 |
| A08 | 候选snapshot超限回退保持全集，不隐藏剩余人 | DB | 01 |
| A09 | 刷新后及跨账号/模式/输入/发现-报价用途伪造cursor拒绝；快照共用actor预算；逐页及发送重新鉴权 | DB/HTTP | 01 |
| A10 | 定向-only：受邀者可见可报价，未受邀者所有旧新路径拒绝 | DB/HTTP/UI | 02 |
| A11 | 池-only及混合：合格者可发现；同一Request/美容师无重复条目/通知 | DB/UI | 02/05 |
| A12 | 首次丢响应只一单一邀请一份权威publish回执；共享协调器在照片上传/交接失败或重启后不重发 | DB/Unit/UI | 02/05 |
| A13 | session到期后已受理操作仍可恢复；未受理过期操作拒绝 | DB/Unit | 02 |
| A14 | 同session两operation竞争仅一Request；payload变更不能复用operation | DB | 02 |
| A15 | 5位边界两设备并发追加不超限；重放/已有pair不重复计数 | DB | 02 |
| A16 | 邀请到期/撤回后池仍开能按池报价；池关无其他权利则拒绝 | DB/UI | 02/05 |
| A17 | 已有有效报价不因邀请期限/池关闭而消失，失效报价不计有效数 | DB/Unit | 02 |
| A18 | 池关闭与新报价两种提交顺序，结果按锁内先后正确 | DB | 02/06 |
| A19 | 旧打开详情、通知、原始表、旧RPC不能绕过池关闭 | DB/HTTP/UI | 02/06 |
| A20 | 池重复开关不重复通知，不复活本人dismissal | DB | 02 |
| A21 | 前预约DTO不含结构化精确住宅地址/联系方式；候选/收藏共用安全groomer投影，不暴露owner字段；owner仍可读 | DB/HTTP/Unit | 01/02/03 |
| A22 | 请求媒体新读在撤权后拒绝，合法已报价最小访问和Booking不误断 | HTTP | 03 |
| A23 | cancel/accept与邀请竞争无终态新邀请，最多一个Booking | DB | 02/06 |
| A24 | 原子修订失败保留旧单；成功关闭旧邀请/报价，需重选新接收范围 | DB/UI | 05 |
| A25 | 只关池、不改变terms_revision；旧报价资源/资格失效仍权威拒绝 | DB | 02 |
| A26 | 收藏反复set幂等、500边界、跨账号访问拒绝 | DB/Unit | 03 |
| A27 | 两设备相反收藏写按revision解决，无晚响应逆转 | DB/Unit | 03 |
| A28 | 收藏/浏览不发邀请、不通知、不改变评分或Request额度 | DB/Unit/UI | 03/04 |
| A29 | 收藏对象暂停/不匹配保留并禁发，删除后不泄露旧身份 | DB/UI | 03/04 |
| A30 | 退出/换号不回显前账号收藏、候选、未决发送、图片 | Unit/UI | 03/05 |
| A31 | 头像只能读活跃美容师允许对象，任意bucket/path/listing和私人图拒绝 | HTTP | 03 |
| A32 | 左右滑无pass、无隐式发送；明确按钮才写入 | Unit/UI | 04 |
| A33 | 尾页确认进入全量、返回保留ID；卡牌/列表/收藏共用操作状态，晚返回旧页不反转已确认收藏/发送 | Unit/UI | 04 |
| A34 | 网络失败保留安全已有内容，不能显示零候选/假发送成功 | Unit/UI | 04/05 |
| A35 | 排序更换/输入变更取消旧读取，旧页不能追加到新scope | Unit | 04 |
| A36 | 长名、大字号、紧凑屏、缺图、辅助按钮均可完成选择 | UI | 04 |
| A37 | 第一次确认准确列出目标和池状态；浏览退出不发布 | UI | 05 |
| A38 | 收藏无当前需求时经选单/创建再评估，不直接预约 | UI | 04/05 |
| A39 | 美容师看一条混合来源需求、报价/撤回/婉拒状态同步 | UI/DB | 05 |
| A40 | 全部邀请无回应/结束但Request仍有效，提供追加或开放池 | Unit/UI | 05 |
| A41 | 真实Request到期后停止两种入口，进入历史，可从模板重发 | DB/UI | 05/06 |
| A42 | 历史超过最近3条仍可分页打开expired/cancelled并恢复 | Unit/UI | 05 |
| A43 | 接受报价后其他入口关闭，双端重启读取同一Booking | DB/UI | 06 |
| A44 | 原三开放需求额度、同宠/美容师冲突、容量、缓冲、DST不回归 | DB/Unit | 02/06 |
| A45 | 私有发现/收藏/邀请/回执个人内容匿名化清理，未发生真实Auth删除 | DB回滚 | 03/06 |
| A46 | 旧无版本pending经唯一协调器恢复原协议回执；未知版本不覆盖；危险新写需升级；原Booking履约可用 | DB/Unit/UI | 05/06 |
| A47 | 回退关闭新功能但定向单不变公开、报价/取消仍能处理 | DB/UI | 07 |
| A48 | run-owned数据全部清理且既有业务数据恢复，权限触发器保持启用 | DB/HTTP | 07 |

48项是风险场景，不要求48张截图、48条新需求或48次完整回归。UI写动作覆盖首次定向、池-only、混合、追加、关闭池、收藏、报价、撤回、接受、到期重发；高维权限/竞态由API承担。单位测试不能替代这些真实关键UI路径。

### 性能与稳定性

| ID | 固定输入与测量 | 通过条件 |
|---|---|---|
| P01 | 至少26位既有授权美容师、约1200历史评价；候选首读/续页和原报价各30次SQL/HTTP | 新发现与旧报价SQL P95 <=1500ms、HTTP P95 <=2500ms；首读单列，无超时/截断 |
| P02 | 两页候选浏览，静态/软变/硬变各10次；轮播到列表共享缓存 | 静态与软变首次完成10/10；硬变均明确终止并可一次手动刷新，零混页/重复/漏项 |
| P03 | 进展页持续前台、后台、重返及操作后刷新；有图片/缺图片两组 | 后台不轮询；前台复用45秒门禁；无每卡timer/每人独立RPC；可见核心不等全部图片 |

100位及更大规模仅在现成授权身份/隔离数据库条件足够时增加真实容量测量；否则记录“尚未验证”，不创建Auth账号/新容器平台作为本计划前置，不把本地100项数组测试冒充网络/数据库压测。大集合排序/分页完整性另用至少101项合成Unit向量验证。支持首版不等于宣称无限规模。

## 8. 完成标准与执行记录

实施完成必须同时具备：HD-00至HD-07通过；A01-A48及P01-P03各有对应层级证据；新增页面实际Simulator运行；原完整集成无失败；后端真实部署核验和精确恢复（若已采用远程实施范围）；不存在未修复的权限泄漏、重复发布/成交、错误截止或不可恢复用户路径。

仅剩未采用的更大规模测试、真实市场转化评估、APNs或上架条件，不得写成当前阻断；也不得把未测能力宣称通过。所有实际失败保留原因与复验结果，不能改写成首次通过。

执行记录在实施时写本节，字段固定为：工作包、代码/数据库版本、针对性结果、集成结果、UI证据路径、部署/恢复事实、未验证限制。当前所有实施框均未勾选；本轮只交付可审阅文档。

文档自检覆盖：设计1-2节 -> HD-04/05；设计3/5节 -> HD-02/05/06；设计4节 -> HD-01与P01/P02；设计6节 -> HD-02/03/06/07；设计7节 -> 全局约束及HD-07。没有把收藏、权限、历史恢复或旧客户端迁移留到不具名的后续阶段。

T-398复用自检：设计7.1 -> HD-03/04/05与A12/A21/A30/A33/A46；7.2 -> HD-00/01/02与A01/A03/A09-A12/A18-A22及P01；7.3 -> 各包旧调用方委托与HD-07自检。仅核对文档/当前源码定位，未声称模块已抽取或新增验收已通过。
