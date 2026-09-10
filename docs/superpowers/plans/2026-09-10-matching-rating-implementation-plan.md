# 匹配、评分与偏好体系实施计划

> **For agentic workers:** 使用 `superpowers:executing-plans`，按下列工作包连续执行。项目禁用 subagents；步骤复选框用于跟踪，不是暂停、重复确认或提交检查点的边界。

<!-- task-artifact
task: T-390
status: active
type: plan
-->

**Goal:** 完整落地可信的资格判断、预约评价、专业证据、双端全局排序与可靠刷新，保留现行发布、报价、确认、履约闭环。

**Architecture:** 继续使用 SwiftUI -> Store -> Repository -> 受控 RPC/私有 SQL。资格评估和锁内成交校验沿用现有时间/资源权威实现；证据与排序独立，不能成为新的成交锁。复用刷新队列，以结构化结果和版本化游标替代字符串解析及客户端单页重排。

**Tech Stack:** Swift 6 / SwiftUI / iOS 18+；现有 Supabase Swift SDK、PostgreSQL/PostGIS、刷新 worker；Node 内置测试、现有 TestOps、XCTest/Swift Testing 与 Simulator。不增加依赖或独立服务。

**Spec:** [匹配、评分与偏好体系设计](../specs/2026-09-10-matching-rating-system-design.md)。本计划落实 A1-A5、R1-R7，并在第 2 节说明两项实施细化。

**交付状态:** 2026-09-10 已制作并自检计划；所有实施复选框仍未完成。artifact `active` 表示计划描述的实施未验收，不表示已开始后台执行。本次没有修改业务代码、创建迁移或写入远程数据。

## 1. 全局约束

- 保留 `Request -> Matches -> Offers -> Customer Confirmation -> Booking -> Review`，不引入目录、直接预约、ML、隐式画像、顾客价值分或客服裁决平台。
- 所有合法候选均可发现、可翻页；不得以低分、无评价、排名阈值或客户端截断缩小候选全集。
- 请求使用发布快照；历史证据使用最终协议和可信服务时点。作品、自报、自由备注、未回复、取消不是已完成专业证据。
- 保留身份/权限、私有坐标、RLS/列权限、请求额度、幂等回执、协议 revision、锁顺序、同宠/美容师占用、每日容量、缓冲、DST 和履约资源释放。评分不可覆盖任何硬约束。
- 公开星级保留所有真实有效评价；内部独立顾客限权不删除公开差评。既有隐私删除必须清除对应派生数据。
- 时间契约仍由 [Service Timing](../../03_backend/SERVICE_TIMING_CONTRACT.md) 拥有；时区设置页面迁移、真机、签名、应用商店、APNs 不在本计划。
- 本次只授权计划制作。后续本地实施与远程 DDL、历史派生修复、测试账号/夹具写入分别按实际授权执行，不挪用 T-388 或旧总计划的远程授权。缺少授权时先完成可做的本地工作，只提出具体剩余范围。
- 每个工作包完成实现、针对性验收、自检后直接进入下一包；集成/发布节点才跑完整回归。复用未受影响的证据，不增加通用测试平台、周期审查、记忆文件或微步骤报告。
- 只维护 Current State、此计划复选框和最终一份验收摘要。既有脏文档、未跟踪历史归档不属于本任务，不批量暂存。整个采用目标验收完成后才按现有权限提交/推送。

## 2. 实施细化与可修订边界

### 2.1 用有效性证明减少无变化重算

现有 worker 每 10 秒最多处理 25 对候选。即使忽略查询成本，每分钟也只能处理 150 对；若每对都无条件 60 秒重算，较大的候选集会持续积压。此为容量上界推导，不是已测得的生产故障。

采用如下路线，仍使用原 worker 和同一个资格评估器：

1. 评估器返回已证明可行的完整服务区间 witness、来源 revision、`evaluated_at` 和 `valid_until`。
2. 无事实变化时，确定性 witness 的有效期取请求到期、该服务起点减现有 5 分钟截止、适用的下一次通知天数本地日期边界中的最早值；必须同时满足协议中其他更早截止。到界即 pending，不能继续断言可服务。
3. 硬来源变化同事务追加事件，读取检查来源 revision/未处理事件；无需等待 worker 就能识别旧证明。旧结果不得覆盖新来源。不能仅把 TTL 数字改大。
4. 对不能证明的评估结果保留最长 60 秒保守重验；对纯时间推进只会更不可能的固定窗口排除，记录单调性理由，靠事实变化重新发现，不盲目每分钟扫描。
5. 私有候选评估记录覆盖尚未产生 match 的粗筛候选。临时排除须有事件或 `next_evaluation_at`；没有有界恢复入口的优化不能启用。结束/取消请求退出到期索引，dismissal 不被刷新复活。

MR-04 必须以时间 oracle 差分、事件覆盖和积压测试证明这一路线。无法证明的类别保持 60 秒重验并计入容量测试，不能通过隐藏 pending、缩小候选集或放松验收解决积压。若确需新的聚合/扫描方式，记录实际反例后局部修订，不另建通用调度系统。

### 2.2 年龄不能由浏览当天决定

有具体报价时，目标护理键使用报价服务时点；完成评价使用最终协议 `scheduled_start` 和保存的服务地点时区。尚无报价的请求窗口若跨越年龄分类边界，仅在整个可选服务日期范围分类一致时使用该年龄键，否则标记 `age_varies_with_slot`，不提前给予专业加分；具体报价时重新确定。不能每天浏览都给同一已发布请求换年龄事实。

初版年龄分类沿用现有业务阈值：未满 18 个日历月为 puppy，满 10 个日历年为 senior；未来生日、非法日期为未知。不是物种医学标准，也不推断健康状况。2 月 29 日及服务地点跨日按同一数据库日历规则生成，Swift 不另算一套。

### 2.3 修改路线的纪律

权限、事实真实性、公开星级、范围同意、容量保护、合法候选可发现与真实失败状态不可降低。参数、窄聚合、证明缓存和游标内部实现可凭反例/测量调整；在本计划对应段落写明原因、代价、算法版本和受影响测试即可。没有实证，不宣称参数最优或成交率提升。

## 3. 工作包与文件边界

依赖顺序为 MR-01 -> MR-02 -> MR-03 -> MR-04 -> MR-05 -> MR-06。MR-01/02 的正确性保护可以先独立发布；MR-03 默认影子运行，MR-05 新排序通过 MR-06 后再开启。发布节点不是普通执行确认点，但仍需真实远程授权。

| 工作包 | 独立交付物 | 必须通过的退出条件 |
|---|---|---|
| MR-01 输入与资格 | 可明确配置服务物种，发布快照和报价确认可信 | 配置/发布/报价/接受全链条不越权、不扩大范围，旧配置可恢复 |
| MR-02 评价正确性 | 服务端冻结评价上下文，准确星级，历史使用资格 | 伪造标签被拒绝，历史不漂移，增删/并发/级联不破坏总分 |
| MR-03 证据计算 | 单一私有评分实现与结构化解释 | 公式、口径、稀疏与负面反馈满足固定样例和真实数据库重放 |
| MR-04 刷新与时间 | 分原因失效、证明有效期、未匹配候选恢复 | 硬事实立即失效，软故障不阻断成交，无漏事件及队列持续积压 |
| MR-05 全局排序与双端 UI | 完整候选集排序、签名游标、本地显式偏好 | 后页优候选可进首屏，跨版本不拼页，双方列表/动作闭环 |
| MR-06 集成与启用 | 授权部署、历史派生重建、实际预约验收、回退 | 60 项矩阵及必要回归通过，Simulator 真实行为通过，夹具恢复且部署可核验 |

下文文件表中 `Core/`、`Features/` 均相对 `ios/Beckon/Beckon/`；`BeckonTests/`、`BeckonUITests/` 相对 `ios/Beckon/`。新迁移必须先用已安装 CLI 的 `supabase migration new <名称>` 生成真实时间戳，再用 apply_patch 编辑；不预造迁移版本或修改已应用 SQL。

| 所有者 | 修改既有文件 | 新增文件/迁移名称 |
|---|---|---|
| MR-01 | `Core/Models/CustomerPet.swift`、`CustomerRequest.swift`（含 GroomingRequestPetSnapshot/Draft）、`GroomingRequestTaxonomy.swift`、`GroomerProfile.swift`、`GroomerRequest.swift`；对应 Pet/Profile/CustomerRequest/GroomerRequest 的 Repository 与 Supabase 实现；Pets/Services 编辑、Requests Store/报价表单 | `Core/Models/MatchEligibility.swift`；迁移 `t390_match_input_contracts`；`tests/migrations/matching-input-contracts.test.mjs` |
| MR-02 | `Core/Models/Booking.swift`；Booking Repository、SupabaseBookingRepository、DebugBookingRepository；`Features/Bookings/BookingsStore.swift`、`BookingsView.swift`；Profile/CustomerRequest 星级读取与显示 | `Core/Models/BookingReviewContext.swift`；迁移 `t390_verified_review_context`；`tests/migrations/verified-review-context.test.mjs`；`BeckonTests/BookingReviewContextTests.swift` |
| MR-03 | Profile 的证据 summary Repository/Store/展示；`Core/Models/CustomerRequest.swift`、`GroomerRequest.swift` 中旧 FitPresentation | `Core/Models/MatchingEvidence.swift`；迁移 `t390_matching_evidence_v1`；`tests/fixtures/matching-rating-v1.json`、`tests/support/matching-rating-reference.mjs`、`tests/migrations/matching-evidence-v1.test.mjs` |
| MR-04 | 在新迁移中替换 T-375 队列/消费/资格读取的受影响定义，不编辑 T-375 文件 | 迁移 `t390_match_refresh_validity`；`tests/migrations/match-refresh-validity.test.mjs` |
| MR-05 | CustomerRequest/GroomerRequest Repository、Supabase/Debug 实现、Store、两端 Requests/Offers View；相关 Fake 与 Preview | `Core/Models/MatchRanking.swift`；`Core/Infrastructure/MatchSortPreferenceStore.swift`；迁移 `t390_ranked_marketplace_reads`；`tests/migrations/ranked-marketplace-reads.test.mjs`；`BeckonTests/MatchRankingTests.swift` |
| MR-06 | 按需窄扩展 `scripts/test-t387-booking-fixture.mjs` 的新 run ID/备份范围；`BeckonUITests/TestOpsLaunchSmokeTests.swift`、现有 Scenario runner；受影响活动后端契约 | `scripts/test-t390-matching-scenarios.mjs`；必要的启用迁移 `t390_enable_matching_ranking`；`docs/04_ios/testops/T-390_MATCHING_RATING_ACCEPTANCE.md` |

定位提示：Services 表单在 `Features/Groomer/Profile/GroomerServicesEditorView.swift`，存储在 `GroomerProfileStore+ServicesAvailability.swift`；宠物表单在 `Features/Customer/Pets/CustomerPetFormView.swift`；报价读取/排序在 `Features/Customer/Requests/CustomerRequestsStore.swift`、`CustomerOffersView.swift`；美容师在 `Features/Groomer/Requests/GroomerRequestsStore.swift`、`GroomerRequestsView.swift`。仅改本职责涉及的成员，不借机拆整个 Store 或通用分页。

DebugBookingRepository、DebugCustomerRequestRepository、DebugGroomerRequestRepository 均在 `Core/Diagnostics/DebugRepositoryWrappers.swift`，不是分别命名的文件。新增协议方法必须实际透传，不能依赖默认 unavailable 导致生产装饰器静默丢能力。

## 4. 跨包契约

以下是新接口的确定契约，落地时若必须更名，连同调用者、迁移、测试一起更新。

### 4.1 输入与资格

- `groomer_services.accepted_species text[] NULL`：规范值 `dog`/`cat`，不重复；null 未确认、空集合不接受。保留宠物既有 Dog/Cat 存储兼容，规范化只接受明确值，不猜品种。
- `pets.matting_confirmed boolean NULL` 及宠物/请求快照的结构化事实版本；毛型明确来源记为 `coat_type_source = explicit | legacy_unverified | unknown`。确认来源由受控写路径赋予，不能信任客户端自称来源。
- `MatchEligibility`：`status` 为 estimatedFit/assessmentRequired/excluded/pending；`reasonCodes: [String]`、`requiredConfirmations: [String]`、`sourceRevision: String`、`evaluatedAt: Date?`、`validUntil: Date?`。未知 reason 文案保守展示，不能自行推断可服务。
- 请求/服务作用域 revision 使用已有 `terms_revision`、eligibility revision；字段 change-back 也生成新 revision。新增确认信息进入报价 `agreement_snapshot`，后续 Booking 原样承接；改期更新最终服务时点但不重新读取可变宠物。
- 扩展当前 `create_groomer_offer_v2` 的私有核心，新增 public `create_groomer_offer_v3(p_request_id uuid, p_expected_request_revision uuid, p_proposed_start timestamptz, p_proposed_end timestamptz, p_price_estimate numeric, p_message text DEFAULT NULL, p_assessment_confirmations text[] DEFAULT '{}')`，仍返回 table(offer_id uuid, offer_status text, request_status text)。保留核心内从可信配置读取的缓冲/截止检查，不新增客户端覆盖参数。旧 v2 仅在不需要新增确认时转入同一核心，否则返回 `assessment_confirmation_required` 或 `client_update_required`。
- 确认只表示美容师接受这一次未知细节的服务责任，不把未知体型/毛型改造成事实。不明物种接受范围必须先保存服务，不允许一次报价暗中修改全局能力。

### 4.2 评价上下文

`app_private.booking_review_contexts` 按 booking_id 唯一，保存 `context_revision uuid`、`evidence_context_version integer = 2`、可信服务时点、服务时区、物种、固定服务类型、规范允许键及来源状态。revision 是实例版本，version 是字典/契约版本，不混用。随合法隐私删除级联，不暴露私有来源记录。

```swift
struct BookingReviewContext: Decodable, Equatable, Sendable {
    let bookingID: UUID
    let contextRevision: UUID
    let evidenceContextVersion: Int
    let serviceAt: Date?
    let allowedKeys: [ReviewEvidenceKey]
}

struct ReviewEvidenceKey: Codable, Hashable, Sendable {
    let dimension: String // service, coat, size, care
    let value: String
}
```

- `get_booking_review_context(p_booking_id uuid) returns jsonb`：本人顾客且可评价订单才返回；不能给旁观者探测 Booking。缺可信历史专业信息可返回空键，但星级资格仍独立判断。
- `create_review_v2(p_booking_id uuid, p_expected_context_revision uuid, p_rating integer, p_content text, p_pet_fit_outcomes jsonb) returns jsonb`：结果沿用 `CreateReviewResult` 业务字段，额外包含 context revision。outcome 行保持 `trait_type/trait_value/outcome`，前两者对应规范 dimension/value，outcome 仅 positive/negative。
- `BookingRepository.reviewContext(bookingID: UUID) async throws -> BookingReviewContext`；现有 `createReview(bookingID:draft:)` 返回类型不变，`BookingReviewDraft` 加 `contextRevision: UUID?`，正式新提交流必须非空。Supabase 只调用 v2；旧 RPC 回退不能绕过校验。
- `ReviewEvidenceKey` 到现有 `PetFitSignal` 使用显式的 canonical factory：扩展其 Group/字典以支持 service/coat/size/care，保留旧命名空间仅用于历史反馈显示。现有 BookingReviewPetFitOutcomeDraft 的 trait_type/trait_value 编码可复用，但禁止把新服务键勉强映射为旧 full_haircut_styling 等更宽的键。同步 stored 解码、title 和 outcome 展示，避免服务器可提交而客户端丢弃。上下文 DTO 的 snake_case、ISO 时间小数秒沿用现有 Supabase Row 映射并加 round-trip 测试。
- context changed 返回 `review_context_changed`，无效键返回 `invalid_pet_fit_context`，服务未完成沿用 bookingNotCompleted；新增错误映射进入 BookingRepositoryError。Store 保留星级/文字草稿，重取上下文后仅保留仍合法选择，不自动重提。

### 4.3 证据与排序结果

`app_private.review_evidence_projection` 每条原始 outcome 最多一条投影，保存规范键、服务时点、species/service、有效/隔离理由及来源 revision。它是可重建派生数据，不是第二份原始评论库。合法同义键去重，冲突旧别名隔离该键，不猜正负。

`app_private.score_match_evidence(p_request_id uuid, p_groomer_id uuid, p_score_as_of timestamptz, p_offer_id uuid DEFAULT NULL) returns jsonb`：只供已完成授权筛选的私有调用者使用。输出 F/Q/D、P/N、各维度正负/覆盖、有效预约数、独立顾客数、最近服务时间、来源 revision、`algorithm_version = matching-v1`。offer 非空时必须属于该 request/groomer，目标护理时点取其服务时间。

对外 `MatchingEvidence` 仅含事实计数、来源/时间/版本、维度正负与覆盖、`state = available | no_evidence | unavailable`；不返回顾客 ID、精确坐标、原始未授权评价或内部 F/Q/D。`no_evidence` 是已成功读取且确实无数据，不能替代 unavailable。

```swift
enum GroomerMatchSort: String, Codable, CaseIterable, Sendable {
    case fit, distance, newest
}
enum CustomerOfferSort: String, Codable, CaseIterable, Sendable {
    case balanced, distance, earliest, price
}
struct RankedPageRequest<Sort: Sendable>: Sendable {
    let mode: Sort
    let limit: Int
    let cursor: String?
}
struct RankedPage<Item: Sendable>: Sendable {
    let items: [Item]
    let rankingRevision: String
    let scoreAsOf: Date
    let validUntil: Date
    let algorithmVersion: String
    let requestedMode: String
    let effectiveMode: String
    let pendingCount: Int
    let assessmentCount: Int
    let nextCursor: String?
}
```

- `GroomerRequestRepository.rankedMatches(groomerID:page:) async throws -> RankedPage<GroomerMatchedRequest>`，page 为 `RankedPageRequest<GroomerMatchSort>`。
- `CustomerRequestRepository.rankedOffers(customerID:requestID:page:) async throws -> RankedPage<CustomerOfferReview>`，page 为 `RankedPageRequest<CustomerOfferSort>`。
- RPC：`get_ranked_matched_requests(p_sort text, p_limit integer DEFAULT 25, p_cursor text DEFAULT NULL)`、`get_ranked_customer_offers(p_request_id uuid, p_sort text, p_limit integer DEFAULT 25, p_cursor text DEFAULT NULL)`，均 returns jsonb；身份来自 auth.uid()，不接受客户端传 viewer ID。limit 1...50；其他 RPC 不顺带重构。
- `list_changed`、`invalid_cursor`、`ranking_unavailable` 为专属类型化错误；网络/权限失败不能当成软排名错误。取消任务和账号切换沿用现有 Store generation 防污染保护。

## 5. MR-01：输入与资格闭环

**消费:** 现有 publish v4/supersede、create offer v2、evaluate_match_constraints、evaluate_match_eligibility_with_zones、evaluate_quote 和锁内 accept。**产出:** 第 4.1 节事实、资格与报价确认契约，供所有后续工作包使用。

- [ ] **先固定 RED。** 在 `matching-input-contracts.test.mjs` 写输入 schema/权限静态检查；在现有 CustomerPetFeatureTests、GroomerProfileFeatureTests、GroomerRequestFeatureTests 中增加行为用例：旧 null 物种显示待确认、显式 cat 不接 dog、新启用空范围不能保存、旧字段解码不伪造确认。数据库真实拒绝留到授权测试，不将正则命中视作行为通过。
- [ ] **建立受控写入与快照。** 创建 `t390_match_input_contracts`；在现有 owner/role 保护下加入确认来源、物种及打结字段，将 `create_grooming_request_v4` 和 `supersede_grooming_request` 同时接到新事实校验。若当前宠物/服务走直表更新，使用受限 trigger/列权限或窄 owner RPC 守住来源，不能只加 iOS 校验。对非空且已知字段无相关更改的旧写入保持兼容；无法证明确认的新/变更值拒绝，不默认为已确认。
- [ ] **实现规范化和评估通道。** 新体重必须 finite 且 >0；体型区间 `[0,10)、[10,20)、[20,40)、[40,60)、[60,80)、[80,100]、(100,+inf)` 对应 XS/S/M/L/XL/XXL/Giant，实际体重不允许 0；100.1 不能按展示取整算 XXL。旧冲突标记 assessment，不任选较小值。毛型字典复用现有非 unknown 枚举；服务涉及毛发时才适用。matting 未回答与 false 不同；自由备注出现 `mat` 不产生护理键。
- [ ] **贯通报价和接受。** v3 校验所需确认集合精确覆盖且无未知键，把结果和来源 revision 放进协议；明确排除不能通过确认覆盖。服务范围改变使旧报价重新遵守既有版本同意；变回也不复活。报价和 accept 都调用同一权威资格检查，不能只改匹配生成器。保留 current Booking/receipt 恢复，不因新字段补齐重写已接受协议。
- [ ] **接上实际表单。** Pet 表单增加确认事实、Services 表单物种多选及未确认状态；美容师报价表单逐项呈现 requiredConfirmations。使用现有 SwiftUI 控件，不增加设置导航；保留编辑草稿、失败重试和 accessibility identifier。新服务不预勾选“都接受”。所有 Supabase decoder、Fake、Preview、Debug wrapper 接口同步。
- [ ] **运行针对性测试与编译。** `node --test tests/migrations/matching-input-contracts.test.mjs`；针对上述 Swift suite 运行 XCTest/Swift Testing，再 `./scripts/ios-build.sh`。授权后执行矩阵 M31-M40 与相关报价/accept API 正反例，才算业务退出。

最小约束骨架（放在新迁移，不是单独执行的线上修补）：

```sql
alter table public.groomer_services add column accepted_species text[];
alter table public.groomer_services add constraint accepted_species_values
  check (accepted_species is null or
    (array_position(accepted_species, null) is null and
     accepted_species <@ array['dog','cat']::text[]));
```

写路径另验数组不重复、新建/重新启用非空；已有 active/null 合法保留为未确认，不能用一个全表 CHECK 强迫历史数据伪造确认。服务 eligibility revision 的字段比较必须包含 accepted_species。

## 6. MR-02：评价正确性与历史证据

**消费:** MR-01 快照/最终协议与规范事实。**产出:** 第 4.2 节上下文和投影，准确 rating_sum/count；MR-03 不再直接信任旧 outcome 字典。

- [ ] **写 RED 与接口假件。** BookingReviewContextTests 覆盖服务端允许键、加载失败不显示猜测键、上下文变化保留文字草稿、账号切换丢弃迟到响应。新增 SQL/HTTP 样例：小型剪甲冒报 Giant 或 curly coat、过期 context revision、重复同义/相反答案、旁观者与未完成订单均失败。空 outcome 的合法星级可提交。
- [ ] **在完成状态转换中冻结上下文。** 创建 `t390_verified_review_context`。从最终 `agreement_snapshot` 与可信 Booking 时间创建唯一 context；适配 T-378 合法改期后的 scheduled_start。完成后当前 Pet/Profile、迟确认/迟评论不能影响 context。为已完成历史行从现有可信记录重建；缺时点/物种/来源只隔离相关专业证据，绝不调用当前时间兜底。未知服务时点不能进入 Q 的时衰统计，但合法公开星级仍保留。
- [ ] **替换评价核心而非叠加校验。** public v2 和旧 create_review 共用一个 private writer；旧合法字典只通过上下文映射，无法解释的键拒绝。扩展 review_pet_fit_outcomes 的字典 CHECK，使新规范键可持久化，历史旧键保留；写入记录 context revision/version，客户端不能自行指定可信来源。保留一 Booking 一评价唯一性、1...5 整数、内容 <=2000 字符、最多 20 项，并额外限制不超过 allowedKeys 数量。写 review/outcomes、准确汇总和失效事件同事务提交，重试不重复计数。
- [ ] **建立准确汇总及删除保护。** 给 groomer_profiles 增加 rating_sum bigint，原始 reviews 权威；使用同一串行更新机制按 NEW/OLD 差额更新 sum/count，涵盖插入、允许的修改/删除、级联。移除旧 create_review 的舍入递推，避免 trigger + RPC 双加。profile 不存在的删除级联不重建已删用户；禁止未经授权改 review 归属。测试 booking/profile/review 锁依赖与账号删除，不能引入业务锁环。
- [ ] **统一显示口径。** 新客户端从 sum/count 计算，count=0 显示暂无评价；旧 rating_avg 仅由准确值生成兼容输出。不能先从保留两位的 avg 再舍入一位，避免 double rounding。Profile、收到的报价及个人页面共享同一显示输入，独立顾客数与评价数分开。
- [ ] **历史派生分类及表单上线。** 保留原始评论/outcome，投影分别记录 missing_species、missing_service_time、untrusted_fact、unrelated_key、conflicting_alias。context 校验产生服务端选择项，移除 Booking.reviewableFitReferenceDate 的 Date() 业务兜底；允许保留无关展示辅助函数，但不能进入写入或排名。
- [ ] **针对性验收与阶段 A 发布。** `node --test tests/migrations/verified-review-context.test.mjs`；BookingReviewContextTests/BookingFeatureTests、Profile/报价星级显示测试。获得范围授权后先部署 MR-01/02，使用真实角色 token 完成 M01-M15、M31-M35 的写/读/拒绝/恢复；排序仍关闭。无授权只完成本地验证，不把阶段 A 标为已部署。

准确汇总的不变量查询，须在受控 SQL 验收中返回 0 行：

```sql
with actual as (
  select groomer_id, sum(rating)::bigint as total, count(*)::bigint as n
  from public.reviews group by groomer_id
)
select p.user_id
from public.groomer_profiles p left join actual a on a.groomer_id = p.user_id
where p.rating_sum <> coalesce(a.total, 0)
   or p.rating_count <> coalesce(a.n, 0);
```

若现有测试 Profile 的星级没有对应原始评价，修复派生值，不伪造 reviews 来保住种子高分；修复前后计数及隔离理由保存为私有证据。

## 7. MR-03：专业证据与整体评分

**消费:** MR-02 已验证投影/原始有效星级、MR-01 目标上下文与私有距离。**产出:** `score_match_evidence` 与 MatchingEvidence；服务端唯一生产算法，Node 仅独立测试 oracle。

- [ ] **固化可复用向量并先跑 RED。** 建立 `matching-rating-v1.json` 和 `matching-rating-reference.mjs`，再由 `matching-evidence-v1.test.mjs` 驱动固定期望值。涵盖中性、有界、独立顾客、完整半衰期、置换、覆盖、负面、距离与 custom。在真实数据库通过相同输入对比 SQL，不以 Node 算式通过代替部署正确性。
- [ ] **实现规范键映射。** service 使用 full_groom/bath_and_brush/haircut_only/nail_trim/de_shedding；coat 只接显式真实枚举；size 精确匹配；care 规范为 anxious/reactive/puppy/senior/matted。gentle_handling->anxious、reactive_low_tolerance->reactive、puppy_first_groom->puppy、senior_care->senior、matted_coat_handling->matted，仅在 context 真有该键时成立。旧 full_haircut_styling 等仅映射到预约实际固定服务，不能跨服务扩大。品种词和 hand_stripping 自报不变成完成证据；curly/terrier 别名也不能绕过显式毛型来源。
- [ ] **实现一次读取的私有算法。** 新迁移 `t390_matching_evidence_v1`。F 先筛同美容师/同物种/同固定服务且与目标有有效相关回答，再按顾客分组；Q 用该美容师可用于时间加权的全部有效星级，单独分组。先按预约规范键去重和分配维度份额，再做顾客限权，不能反过来把标签当独立订单。
- [ ] **固定解释口径。** 正负计数、独立顾客、服务时间和覆盖按各自范围返回；覆盖分母为有可信相关上下文的完成服务，未评价/未回答只计 unknown，不进 P/N，不成为好评。Q/F 不共享一个伪有效样本数；高样本也可能评价两极。custom 的 F=50，展示其可阅读反馈但不迁移专业等价关系。作品/声明独立标注来源，删除通用 high/medium/low 专业置信等级和英语 match_reason 反解析。
- [ ] **影子计算与成本检查。** 索引先按 groomer/species/service/可信 service_at 过滤；验证执行计划后才增加窄聚合，不能为每次读取重扫整个平台。影子算法与旧排序对照使用同一合法候选全集；不改变分发、报价或当前接受权利。
- [ ] **执行针对性验收。** `node --test tests/migrations/matching-evidence-v1.test.mjs`，授权 SQL/HTTP 重放 M16-M30；检查解释 payload 不含私有坐标、顾客 ID 或未授权评论。公开星级回归不得被内部限权改变。

核心公式的实现骨架及固定 RED 样例：

```javascript
// tests/support/matching-rating-reference.mjs: independent test oracle only
export function customerWeights(serviceAgesInDays) {
  const a = serviceAgesInDays.map(age => 2 ** (-age / 180));
  const total = a.reduce((sum, value) => sum + value, 0);
  const newest = Math.max(0, ...a);
  return a.map(value => total === 0 ? 0 : newest * value / total);
}
export const fitScore = (positive, negative) =>
  50 + 50 * (positive - negative) / (positive + negative + 5);
```

```javascript
import assert from 'node:assert/strict';
import { customerWeights, fitScore } from '../support/matching-rating-reference.mjs';
assert.equal(fitScore(0, 0), 50);
assert.equal(fitScore(5, 0), 75);
assert.equal(fitScore(0, 5), 25);
const sum = values => values.reduce((a, b) => a + b, 0);
assert.ok(Math.abs(sum(customerWeights(Array(10).fill(0))) - 1) < 1e-12);
assert.ok(Math.abs(sum(customerWeights(Array(10).fill(380))) /
  sum(customerWeights(Array(10).fill(200))) - 0.5) < 1e-12);
```

生产 SQL 用窗口/聚合计算相同权重；未来/不可信时点先排除，避免 oracle 范围外输入。目标 G 每组 1/|G|、护理组内平分，缺失不给其他键补权。F/Q/D/B/S 保留精度至最终分桶；只做浮点误差保护，不用 clamp 掩盖非法输入。

## 8. MR-04：分层失效与有效期

**消费:** MR-01 硬 revision、MR-02/03 证据 revision、现有 T-375 队列。**产出:** 可信资格缓存、精确软失效及完整候选恢复入口，供 MR-05 列表使用。

- [ ] **写可控时间和并发 RED。** `match-refresh-validity.test.mjs` 覆盖 reason 路由及 worker 定义；实际场景 runner 加入事件与消费交错、截止前后、无 match 的临时排除、旧结果晚到等 SQL/HTTP 用例。时间测试向私有测试调用传固定 p_now，不能修改设备/服务器时钟来制造证据。
- [ ] **扩展现有队列，不引入同步跨业务锁。** 新迁移 `t390_match_refresh_validity` 将工作分 hard_eligibility/evidence/rating/display，并按 pair 合并。事件插入仍无业务行 FK 锁，保留 request SKIP LOCKED 与精确消费 IDs；在处理时出现的新事件必须保留。事务失败事件一并回滚，不能出现业务已改变但事件消失。
- [ ] **补齐所有来源。** 服务/物种/地址/availability/preferences/time_off/booking 占用及释放/请求替换/取消影响 hard；review/context/outcome 影响相关 F，review 星级及合法删除影响 Q；作品/claims 只更新展示。原始评价和投影修改入口均覆盖，不能只监听 create_review。缺少可验证软数据时隐藏新推荐而非阻断合法 quote/accept。
- [ ] **加入第 2.1 节证明记录。** 建 `app_private.match_candidate_evaluations`，主键 request_id/groomer_id，保存 reason、source revision、witness、valid_until、next_evaluation_at，粗筛后才生成。硬判断仍调用原评估器；本表不接受 public 直写，不替代 request_matches 的 dismissal/报价状态。读取检查 pending 事件及来源，不能把未到期但已过时的 row 当真。
- [ ] **使到期恢复有界。** 活跃请求到期索引按 next_evaluation_at 排序，消费轮次保留到期与新事件的有限配额，避免互相饿死。对未证明的类别仍按 60 秒；纯单调排除记依据并由源变化触发。time_off/占用释放等可能变好者必须有实际恢复时间或 source 事件，不能误列为永久排除。完成/删除进行同范围清理，不留隐私孤儿。
- [ ] **运行定向验收。** `node --test tests/migrations/match-refresh-validity.test.mjs`；授权执行 M36-M40、M51-M55，以及 Save/accept、同宠并发和资源释放受影响子集。250 对候选测试一个半小时等真实等待不必要：用固定边界重放和有限实际 worker 观察一起验证，分清合成时钟与真实队列证据。

事件责任矩阵的实现约束：

```text
hard source changed -> append hard event in source transaction
reader sees pending hard event OR source mismatch OR expired proof -> pending
worker computes from source R -> publish only if current source still R
worker deletes only event IDs captured for that successful computation
review/rating only -> soft revision changes; no interval analysis
soft unavailable -> independent time fallback; locked quote/accept unchanged
```

若事件/缓存失效机制的证明不完整，这是 MR-04 阻断项；不把“worker 最后会追上”当可靠性验收。

## 9. MR-05：服务端全局排序与双端交互

**消费:** MR-01 资格、MR-03 分数/解释、MR-04 时效。**产出:** 第 4.3 节 RPC/Repository/Store 契约和实际可用双端排序。

- [ ] **先建全量与游标 RED。** `ranked-marketplace-reads.test.mjs` 检查授权先于排序/limit；实际数据库放入至少 26 个合法候选，把最佳者置于旧时间分页第二页，要求新首页包含。MatchRankingTests 验证 listChanged 不清空首屏、不继续拼页、不无限重试，用户刷新与模式切换建立新请求 generation。
- [ ] **实现完整授权集合的一致性读取。** 创建 `t390_ranked_marketplace_reads`；同一语句快照中完成 actor/role/owner 检查、完整候选来源、资格分组、软证据、排序与分页。不能先 LIMIT 25 再算分，也不能另查一次 revision 拼到另一时刻的数据。私有 security definer 固定 search_path、限定 execute；public wrapper 继承现有非匿名角色保护，输入不是授权。
- [ ] **实现严格全序及稳定候选身份。** Groomer B=.70F+.30D，Customer S=.60F+.25Q+.15D。默认 floor(score/2) 降序；显式距离/时间/价格/最新为真实主字段，随后默认 bucket 和 HMAC。groomer board 的 candidate ID 是 request ID；customer 同 request 的 tie 候选是 groomer ID，而不是可换新的 offer ID。最终再加稳定 candidate ID 防理论哈希碰撞。已报价、不可选报价分别保留既有状态视图，不混成“最佳匹配”。
- [ ] **实现签名游标与 revision。** 使用现有平台 pgcrypto HMAC；执行前核对可调用的已安装函数/权限，不能擅加依赖或把秘钥置于客户端。私有单例配置保存随机秘钥与算法版本，角色无读权限。cursor 绑定 auth.uid、角色、查询 scope、请求/有效排序模式、版本、score_as_of、valid_until、ranking_revision、最后全序键；MAC 先验再使用，跨账号/角色/scope 和篡改均拒绝。
- [ ] **采用无快照的范围指纹。** ranking_revision 是同一读快照内对完整有序来源元组生成的确定性摘要，包括候选成员、terms/eligibility/evidence revision、quote revision/status/价格/时点及影响分组的当前资格状态。不能使用 max(updated_at)、count 或仅当前页摘要。已有单调 revision 进入摘要，改回字段不复活旧报价；不新建高争用的每用户全局计数器。score_as_of 固定沿 cursor，浏览有效期取 5 分钟与相关硬边界更早者。
- [ ] **明确跨页变化/失败。** revision 不同或到期返回 list_changed，保留已加载次序且停止更多加载；明确失效报价即时禁用并独立获取当前 quote evaluation。软证据失败可返回 effectiveMode=time_fallback、隐藏未验证解释，使用新的独立 revision/cursor；requestedMode 仍保留，恢复后用户刷新回到偏好。非排序错误直接失败，不能伪造空全集/末页。若某页资源预算耗尽，整页错误，禁止部分列表冒充完整结束。
- [ ] **完成双端 UI 与偏好。** `MatchSortPreferenceStore` 用现有 UserDefaults 按账号/角色/页面存枚举值；非法值回默认，退出清列表及异步请求，换账号不串偏好。菜单提供设计规定的选项；assessment/pending/zero/network 有不同状态。相关负面、未知和更新时间可见，不展示 F/Q、百分成功率或通用美容师能力分。两端排序回退显式呈现，不偷偷覆盖用户价格/时间选择。
- [ ] **执行定向验收与阶段 B 部署。** `node --test tests/migrations/ranked-marketplace-reads.test.mjs`；MatchRankingTests、CustomerRequestFeatureTests、GroomerRequestFeatureTests、ListPaginationFeatureTests 与相关 Wrapper/Fake。授权后部署 MR-03/04/05，排序开关仍为 shadow，运行 M41-M50、M56-M60；通过 MR-06 才设 enabled。

一致性读取的关键结构（`candidate_facts` 为本 RPC 内由现有权限/资格关系构建的 CTE，不是新增通用数据层）：

```text
authenticated actor + verified cursor
  -> candidate_facts MATERIALIZED (complete authorized candidate set, one snapshot)
  -> canonical source tuples -> scope digest
  -> reject list_changed if cursor digest differs
  -> score at cursor.score_as_of, group, stable total order
  -> keyset after cursor.last_key -> limit + 1 -> next cursor
```

一份来源快照、完整排序和 keyset 三者必须共同验收。仅验证排序比较器或仅检测重复 ID 均不充分。

## 10. MR-06：部署、真实行为与收口

**消费:** MR-01...05 完整实现与必要阶段证据。**产出:** 可核验的已部署契约、实际 Simulator 流程、恢复结果与验收摘要，不只是一组绿色单测。

- [ ] **开工基线与授权清单。** 在首次需要环境的工作包即核对当前分支/代码、CLI help/版本、Beckon linked project 和受影响函数/grants；复用 T-389 已核验定义作为比较基线，只读取变化部分。记录 SQL/角色 API/本地 Simulator 的授权范围，不把文档写作解释成迁移授权。不访问 legacy project，不输出凭据。
- [ ] **接上最小场景 runner。** `test-t390-matching-scenarios.mjs` 复用 `testops-core.mjs` 的 REST/sign-in，以及 T-387 精确备份、run marker、恢复模式。支持 `prepare/run/inspect/cleanup`、`TESTOPS_CASES` 与新唯一 `TESTOPS-T390-...` ID；远程写需现有 `TESTOPS_REMOTE_WRITE_APPROVED=1` 和 `--execute` 双门。先完整盘点、再写夹具；测试脚本单元验证未授权/无 execute 不写。不要复用已关闭的 T387/T388 run ID。
- [ ] **扩展备份范围至实际新增写入。** 现有 T-387 helper 只固定两名美容师及原表，不足以直接覆盖本任务：加入受测服务、reviews/outcomes、review context/projection、candidate evaluation/队列和评分相关列；所有范围由本次明确 ID/marker 确定。需要 26 个报价方时从已授权测试账号清单选取相应 cohort，不能绕过身份认证或伪造真实账号。未纳入新字段的旧 15/15 hash 不是本次恢复证明。
- [ ] **阶段发布与历史重建。** 本地先通过静态/目标测试；授权后依序 stage A、stage B，迁移每次应用前 dry-run/差异核对，应用后函数/RLS/列权限/索引与 repeat dry-run 核验。历史修复仅重建准确汇总与使用资格，分批按确定主键、可重入/可中断；每批验证来源 revision，不能旧投影覆盖新评价。新列/RPC 先存在，新客户端后读取。private policy 状态 `shadow | enabled | time_fallback` 不能由客户端设置。
- [ ] **执行第 11 节矩阵。** 基础算术层、数据库层、真实角色 HTTP 层、Simulator 层分别记证据；所有当前必须项要通过，不能把 60 个静态断言写成 60 次真实预约。HTTP 正常路径经发布/匹配/报价/接受/履约/评价，历史与并发/时钟向量使用受控 SQL 夹具并明确标注。既有 T-388 72 场景中受输入、quote、accept、完成/评价、列表影响的用例在最终集成执行；无关通知/存储实现未变则复用原证据。
- [ ] **完成双端 Simulator 行为。** 顾客发布多请求、美容师处理多单；同时打开或顺序使用两个角色 Simulator。至少完成：物种补齐、需评估报价、比较并切换排序、跨页期间新报价/新评价、过期报价禁用、确认/改期/履约/评价、延迟/断网恢复、账号切换、取消/dismissal 不复活。评价期间编辑原宠物不得改变旧允许键。通过真实 UI 操作，截图和后端业务 ID/状态对应，不用 fixture Preview 冒充交互。
- [ ] **性能/质量与回退演练。** 按第 12 节数据与预算验收；验证关闭新排序只回退排名，不恢复旧不安全 writer 或舍入累计。后台影子对照完成后再授权启用；失败保留安全补丁、设 time_fallback，修复后向前迁移，不回滚已应用历史。
- [ ] **最终集成和恢复。** 串行运行 `./scripts/preflight.sh`、`./scripts/ios-build.sh`、`./scripts/ios-test.sh`，并保留相关 Simulator 证据；只在相关代码再次修改后重跑受影响验证。cleanup 必须证明本次新增业务/私有行、队列标记、权限/trigger 状态及配置已恢复；若期间出现用户新变更，不覆盖，保存具体冲突再处理。无任务私有恢复残留后，更新实际受影响契约及单份验收摘要。
- [ ] **整体验收与提交。** 对照每个工作包和矩阵，无关键未验收项才勾选完成并将 artifact completed。Current State 清任务，写 last_completed；审查命名文件 staged diff，按现有权限完成提交/推送。远程未应用、核心跳过、未恢复夹具或真实阻塞均不能标“全部完成”。不创建 PR、不自动合并/换分支。

目标 Swift 测试直接使用 xcodebuild 的 `-only-testing`；当前 `scripts/ios-test.sh` 不转发额外参数，不能写一个看似针对性、实际全量的命令。例如新增 XCTest 类 `BookingReviewContextTests` 的执行方式：

```bash
source scripts/ios-destination.sh
export CODEX_IOS_DESTINATION="$(ios_default_test_destination ios/Beckon/Beckon.xcodeproj Beckon)"
xcodebuild -project ios/Beckon/Beckon.xcodeproj -scheme Beckon \
  -destination "$CODEX_IOS_DESTINATION" \
  -only-testing:BeckonTests/BookingReviewContextTests test
```

同样为 MatchRankingTests 替换目标名；现有 suite 使用源码中的真实类型名，不猜文件名即 suite 名。Xcode 写操作串行，失败先定位，不增加新的测试运行器。

## 11. 验收矩阵：60 项最小场景

每个分号分隔的编号是一项独立可报告场景；新增反例加入相应组，不为凑数扩展。DB 表示实际迁移后的数据库行为，API 表示真实角色 token HTTP，UI 表示真实 Simulator。所有写入仅在授权夹具范围内。

| 组/归属 | 场景及期望 | 必需证据层 |
|---|---|---|
| 来源 MR-02/03 | M01 小型剪甲报 Giant 拒绝；M02 剪甲报无关毛型拒绝；M03 dog 证据不加给 cat；M04 新重复/冲突别名拒绝、旧冲突隔离；M05 已完成未评价不产生好评 | DB/API；M05 解释 |
| 历史 MR-01/02 | M06 改宠物/Profile 不改已确认上下文；M07 晚写旧评价不刷新 service_at；M08 晚确认完成不改年龄；M09 缺可信时点不使用 now、公开星级保留；M10 改期/跨龄/闰日按最终服务日期 | DB/API/UI |
| 星级 MR-02 | M11 800 个 5 星+200 个 1 星=4.20；M12 插入排列一致；M13 重试/并发一次入账且总和准确；M14 删除/允许变更准确；M15 账号级联和 profile 并发无孤儿/死锁/漂移 | 算术+DB，M13 API |
| 独立性 MR-03 | M16 同顾客十单总权重<=1；M17 十个独立顾客不同于一人十单；M18 再过 180 天权重恰减半；M19 晚交旧评仍按旧服务龄；M20 F 与 Q 使用各自范围、无关/空专业回答不稀释 F | 向量+DB |
| 部分回答 MR-03 | M21 一组好评不等于全覆盖；M22 缺失不算负面；M23 新增真实负面降低对应固定证据得分且仍可见；M24 care 多键总份额不超过一组；M25 作品/自报数量变化不增 P/N/Q | 向量+DB/API |
| 稀疏 MR-03/05 | M26 新人 F/Q 中性且可发现；M27 custom 不迁移 F；M28 稀疏公开评价与独立顾客数分开；M29 no_evidence 与 unavailable 不同；M30 多种输入顺序/极端合法值均有界且可重复 | 向量+DB/UI |
| 准入 MR-01 | M31 显式物种/体型/服务拒绝不出现可报价；M32 旧 null 范围需保存、空范围不接受；M33 未知体型评估与 100/100.1 磅边界；M34 坐标缺失不能成为 assessment/零距离；M35 高分不能越权接受，范围改回不复活旧 quote | DB/API/UI |
| 时间 MR-01/04 | M36 连续完整区间与碎片不能混同；M37 DST/跨午夜/服务地点时区一致；M38 缓冲与提前通知日期边界；M39 同宠/美容师多单并发容量不超限；M40 完成/取消/未履约资源释放后正确重新发现 | DB/API，受影响既有并发脚本 |
| 排序 MR-05 | M41 第 26 位优候选进新首屏；M42 2 分桶全序传递；M43 刷新/重报/改作品不重新抽 tie；M44 显式价格/时间/距离/最新主字段不被分覆盖；M45 扩大半径不涨 D，所有合法候选最终可达 | DB/API/UI |
| 翻页 MR-05 | M46 新报价/撤回导致 list_changed；M47 新评价/硬资格变化导致新 revision；M48 valid_until 到期不混页；M49 篡改/跨用户/角色/scope cursor 拒绝；M50 失败保留已加载列表，模式切换和刷新清游标无自动循环 | DB/API/UI |
| 刷新 MR-04 | M51 相关评价更新已有证据但不跑无关日程；M52 作品只更新展示；M53 消费中到达新事件不丢、旧结果不覆盖；M54 没有 match 的暂时排除按事件/到期恢复；M55 超过 150 对活跃候选不因每分钟全量重算持续积压 | DB/实际 worker/时钟重放 |
| 恢复 MR-01/05/06 | M56 zero/assessment/pending/network 四态；M57 软排名失败仍能合法报价/接受且回退独立游标；M58 扩大范围需顾客替换确认、dismissal/取消不复活；M59 当前 Booking 回执与多订单恢复沿用 T-388；M60 旧客户端失败可恢复、账号切换无数据/偏好串号 | API/UI |

权限矩阵横切以上场景：未认证、匿名登录、错误角色、非参与者、合法顾客、美容师分别验证受影响的读取/写入；不只用 SQL owner 跑成功样例。没有授权的私有原始信息不应出现在错误详情或 explanation 中。

## 12. 性能、质量和完成标准

### 12.1 固定测量范围

MR-01 开工时记录代码/数据量/计划及受影响基线，MR-05/06 用同数据重放。先使用当前代表市场池及 T-375/T-385 25 次 closed/open probe；再增加受控的 26+ 列表成员、250 个粗筛 pair、1000 条评价样本。并发场景分别报告单请求、同美容师和不同美容师；不把服务端 SQL 耗时说成客户端延迟。

- 已采用硬预算不变：25 次 closed <=2000ms，25 次 open <=3500ms；既有 T-385 1413.549/2682.155ms 是历史 SQL 样本，不是新实现结果或 P95。
- 新分页首版工程预算：上述受控集合 page=25，固定 30 次读取，SQL P95 <=1500ms、角色 HTTP P95 <=2500ms；报告冷读与热读，禁止剔除失败样本美化。此为新增验收预算，不冒充生产 SLA。
- 一条 review 的软失效不能调用任何 interval evaluator；无事实变化的证明有效候选不能仅因过 60 秒全部重算。250 pair 突发后，在无新变化条件下 180 秒内清完本轮可处理工作，后续 3 个 worker 周期不重新堆满；锁占用/失败单独报告。
- 静态集合完整翻页无重复/漏项；一次已知变更只要求显式刷新，不循环重试。受控每 10 秒一次相关变更、每页间隔 1 秒的 5 页浏览重放，记录重启率与可完成率；若连续 3 次用户刷新尝试均无法读完一轮，视为可用性阻断，凭证据改进范围 revision/窄短期快照，不能先验扩大系统。
- 新预算不达标时先定位索引、重复查询、错误全池日程计算、摘要扫描和事件风暴；需要改变预算时说明测量及取舍，不能在失败后无说明抬高阈值。压力数据不够则补必要夹具，不以当前只有一条 match 的速度宣布可扩展。

### 12.2 质量不是“平均分更高”

影子对比必须保留同一合法全集：新人/少评价仍可发现，相关负面不被藏，显式模式排序正确，冷启动不因注册时间永久落后。记录按物种、固定/custom、地区/服务方式、稀疏程度分组的候选与曝光；只采任务所需聚合，不加设备画像或顾客价值分析。

首份有效报价等待时间、有效报价率、确认后完成率、资格复核拒绝原因是后续实际效果观测指标。现有生命周期事实可以统计；缺曝光记录时只新增同意范围内的最小匿名/聚合观测，不把一次测试“打开页面”声称生产曝光。无真实样本报告无样本；不为了等待真实市场增长无限延期，也不据 fixture 宣称转化提升。

### 12.3 收口定义

必须同时满足：六包必需项通过；60 项按正确证据层覆盖；相关完整回归与 Simulator 真实闭环通过；已授权部署/历史派生核验与恢复通过；权限与负面用例无退化；软故障回退不撤销安全修复；当前状态和活动契约准确。原 T-385/T-388 未变化证据可复用，但新评分、上下文、刷新、排序不能借旧结论豁免。

本计划制作阶段仅做文档自检、链接/状态 hygiene 与 diff review，不运行无关 App 全量测试。实际执行发现的新关键反例归入对应包；非阻断改进不变成新的开工条件。
