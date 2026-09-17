# T-391 Matching And Rating Validation

2026-09-17 用户明确暂不考虑真人推荐质量独立评审：T-391 剩余独立标签、盲评及真人决策验证已移出当前任务清单，不作为阻塞、下一步或自动恢复项；仅在用户重新明确提出时考虑。未执行的评审不标记为通过，原计划和已有证据保留。

下文是 2026-09-14 的历史验证结果，[执行计划](../../superpowers/plans/2026-09-12-matching-rating-reliability-validation-plan.md)保留原目标。本地工程子阶段及拟真数据受控回放已完成并恢复数据；当时未达标的浏览预算已在后续 [T-392 验收](T-392_CLIENT_ACCEPTANCE.md)修复并通过。排序效果与真人理解仍无实证结论，但不再列为当前待办；动态任务由 [Current State](../../00_memory/CURRENT_STATE.md) 维护。

## Findings

| 编号 | 发现与证据强度 | 处置 |
|---|---|---|
| V-01 / P2，已修复 | **美容师分页过度失效。** B 只用 F/D，但旧 revision 包含整份 score；软事件 ID 与缓存软刷新版本也是独立失效来源。 | 已部署追加迁移；真实认证 HTTP 在旧版复现、修正版通过。纯星级更新使 Q 变化而 F/B 不变时，美容师旧游标在软队列处理前后均有效；顾客可见星级变化仍使旧游标失效。 |
| V-02 / 能力边界 | 同账号限权不等于多人防串通。合成全覆盖、同龄边界中，同账号 100 条好评 F 约 58.33，10 个账号好评/差评约 83.33/16.67。本轮另用 10 个指定账号的 SQL 回滚夹具，单项专业回答、不同服务时点得到 F=74.784161/25.215839，Q=83.140923/16.859077，均与独立 oracle 一致。 | 不混用两种夹具数值，不把账号当作独立真人，不声称发生过实际刷评；不增加 KYC/风控平台。 |
| V-03 / 待实证参数 | 12 个合成决策、每侧 8 个非默认单因素版本，96 组对照中 32 组发生 Top-3 集合替换；跨参数比较累计 397 个候选发生 2 分桶变化。 | 不是 397 个独立用户或失败事件；不能据此证明不稳定、优于基线或应换权重。未选择替代参数，生产评分公式未改。 |
| V-04 / 浏览预算未达标 | 专业评价每 10 秒变化时，美容师五页浏览仅 3/10 首次完成，低于 8/10；7 次中断均在停止变更后一次刷新恢复。变化确实改变可见专业证据，并非 V-01 的无关失效。 | 按原计划保留未达标结论，不降低预算，不以旧资格成交换取顺滑。若继续改善，需要明确软证据展示的一致性取舍；本轮不自动建设持久快照平台。 |
| V-05 / 冷启动排序优化观察 | C 回放中 G05 的综合 Top-3 为 R05、R20、R22；距离 Top-3 为 R05、R22、R03。R20 距离 15.23mi、B=42.414，R03 距离 12.30mi、B=43.670；均无专业证据，落入同一 2 分桶 21，由确定性 HMAC 打破并列。 | 符合现行规则，不是资格错误或显式距离排序失效，但暴露无证据时远距离候选的取舍。后续开发集可比较无证据同桶按距离打破并列；未采用或发布替代规则，不据合成案例声称效果更好。 |

V-01 定位在 [ranked_marketplace_page](../../../supabase/migrations/20260911143541_t390_reuse_page_evidence.sql) 的整份 score 入候选与后续整对象哈希；公开专业说明的 [public_matching_evidence](../../../supabase/migrations/20260911075128_t390_matching_evidence_v1.sql) 不含 Q/S。只读核对线上定义与此源码一致；连接中的 PostgreSQL 为 17.6，函数仍为 STABLE / SECURITY DEFINER、空 search_path、仅 postgres 执行。未读取签名密钥或业务行。

## V-01 Correction

用户明确授权后，通过 installed CLI 应用 [20260913161338_t391_semantic_page_revision.sql](../../../supabase/migrations/20260913161338_t391_semantic_page_revision.sql)。与上一版相比，仅排除版本哈希中的原始 score、两处缓存投影中的软刷新元数据，并将两处队列版本限制为硬资格事件。硬 source_revision、资格结果/有效期、所有可见 payload、排序键、完整候选池、授权与签名校验保留。没有新增表、RPC、权限或评分参数。

- [只读探针](../../../tests/support/matching-page-revision-probe.mjs) 从实际函数源码提取缓存、队列和哈希表达式，以常量输入在连接的数据库执行 SELECT。21 种变化分别使用两处缓存投影，共 42 项；旧表达式 14 项失败，修正后 42 项通过。覆盖纯 Q/S 变化、三类软事件、软 worker 元数据、无明细 pending 计数，以及必须失效的硬事件、资格/报价变化、可见评分、专业证据、候选增删、模式与开关变化。
- `artifacts/testops/TESTOPS-T391-20260913-V01-READONLY/` 保存源哈希、原始执行 SQL 和 RED/GREEN 结果。结果列 `cache_branch` 指两处缓存表达式，**不是两个账号执行 RPC 的证明**；固定 sort_key/页面内容，不冒充完整排序、触发器或并发验收。没有写入远程夹具，也没有修改函数。
- 部署前 107 项历史对齐，dry run 仅列本迁移；部署后 108 项对齐，再次 dry run 无待应用项。`deployment-catalog.json` 中线上函数正文与迁移精确相等，STABLE / SECURITY DEFINER、空 search_path 和仅 postgres EXECUTE 未变；enabled=true、验证名单为空。
- B 运行的 `revision-live-before.json` 保留真实 HTTP 旧版反例；`matching-results-revision-live.json` 为部署后通过结果，包含前后 F/Q/B、revision、顾客失效及软队列处理后复读。星级修改在 finally 中恢复。上线时旧游标可能一次 `list_changed`，刷新建立新版本。
- `./scripts/preflight.sh`：3 品牌、162 迁移、10 Edge 通过；离线与门禁测试 19 项通过。集成 iOS 回归 670 通过、25 跳过、0 失败，跳过的播种 UI 流程不冒充通过；本次认证 UI 单独记录。

```bash
node tests/support/matching-page-revision-probe.mjs --source supabase/migrations/20260913161338_t391_semantic_page_revision.sql
node tests/support/matching-page-revision-probe.mjs --results artifacts/testops/TESTOPS-T391-20260913-V01-READONLY/green.json
```

第一条只向 stdout 生成只读 SQL，不连接数据库；第二条核验已保存的真实表达式查询结果，不重新调用 RPC。

## Earlier Local Evidence

先前 A 子阶段：`artifacts/testops/TESTOPS-T391-20260913-A/`，受 Git 忽略且使用私有文件权限。以下零远程写入结论仅描述 A，不描述已授权部署的 B。A 原始材料未覆盖。

| 范围 | 已执行结果 / 证据 |
|---|---|
| 起点 | Git `818508ae56b49b2c5b54539ed394382e96900473`；开始时 `git diff --name-only 26ffdf69 -- ios supabase scripts tests` 为空。T-390 业务代码未变，部署/Simulator 结果引用原验收记录，不称为本轮复跑。 |
| 协议 | `protocol.json` 固定来源 SQL 哈希、基线、样本目标、参数/翻页预算。实际收到的真实决策与真人标签为 0，不以合成案例补齐 60 个真实样本。 |
| 离线工具 | `node --test tests/matching-quality.test.mjs`：18 项通过、0 失败。先 RED 后 GREEN；覆盖手算、未知/缺失标签、来源聚类、候选全集、版本/哈希绑定、拆分泄漏、来源隔离、评审角色、有效报价、显式排序隔离与结果不覆盖。同一来源键不能在同一拆分中被标成多个独立组，防止虚增样本量。 |
| 本地集成 | `./scripts/preflight.sh` 通过：3 个品牌、162 个迁移、10 个 Edge 本地测试，含旧默认评分 oracle 回归。未改 Swift/业务 SQL，不重跑 iOS 编译/全量 Simulator；静态测试不替代本轮远程验收。 |
| TestOps 适配 | T-391 前缀、匹配专用宠物/评价恢复分支共用谓词；缺少执行标志/远程授权的子进程在读取凭据前拒绝。两个真实读取测试入口在 enabled 状态不生成配置写入，保留旧 T-390 私有名单路径并检查配置漂移。仅本地门禁/策略与语法通过，真实恢复未执行。 |
| 参数实验 | `sensitivity-inputs.json` / `sensitivity-results.json` 保存所有输入、参数、分数和排序；648 次分数计算有限且位于 0..100。固定字典序并列不是服务端 HMAC，未执行资格评估或真人判断。可用现有 `scoreEvidence(target, reviews, distance, parameters)` 按保存数据重算。 |
| 边界与失效 | `score-boundaries.json` 保存账号、跨物种 F/Q、缺项边界；`unused-rating-revision-counterexample.json` 保存 V-01 的源文件哈希、分数及本地哈希模型，明确 `actualDatabaseReplay=false`。 |
| 无资料结果 | 空 `decision-snapshots.json` / `blind-labels.json` 经实际 CLI 输出 `quality-results.json`：`insufficient`、0 案例、无效果结论。不是已收集真实数据或已完成盲评的证明。 |

一次测试调整：新增显式排序校验后，原哈希测试同时破坏了价格排序，先被排序校验拒绝；已改为只改变冻结 seed，独立验证哈希绑定，没有放宽业务/数据校验。

## Input Contract

入口为 [test-t391-matching-quality.mjs](../../../scripts/test-t391-matching-quality.mjs)，不联网、不读取凭据、不修改生产数据。完整可执行数据例子在[单测](../../../tests/matching-quality.test.mjs)，全部为单测构造，不是真人证据。

- 快照根：`schema_version=1`、`frozen=true`、整数 `seed`、双端 `primary_baselines`、`cases`。每例包含 `case_id/role/split/source_kind/source_group/leakage_keys/strata/intent/as_of/source_revision/scoring_version/candidates/rankings`。
- 来源：`real_redacted/controlled_fixture/synthetic`，对应真实脱敏资料/受控夹具/合成反例。请求、顾客、近似复制来源键须完整，不能用随机 ID 隐藏重复；来源真实性仍需外部核验。
- 候选保存独立资格来源与角色可见的脱敏 facts；顾客须有 `offer_id`、`offer_status=pending`、`selectable=true`。排序携带相同时点、revision、版本和完整 ID 集。`intent=recommended` 才参与综合质量对照，其他模式只验排序契约。
- 标签根：`snapshot_hash`、`cases`。哈希是快照解析结果 `JSON.stringify` 后的 SHA-256；每例 `reviews` 保留评审 ID/角色、`origin=human|synthetic` 与各候选 `rating/reason`，不抹除分歧。改写 origin 不等于完成真人来源核验。
- 默认只分析 `development`；保留集须显式 `--split holdout`，先冻结唯一候选/主基线，按计划仅打开一次。CLI 排他创建输出，不额外建设实验管理系统。

```bash
node scripts/test-t391-matching-quality.mjs --input "$RUN_DIR/decision-snapshots.json" --labels "$RUN_DIR/blind-labels.json" --out "$RUN_DIR/quality-holdout.json" --split holdout
```

## Authorized Engineering Evidence

证据目录 `artifacts/testops/TESTOPS-T391-20260913-B/`。共享夹具包含 1000 条受控预约/评价历史、26 个开放需求和两位美容师的有效报价；预约走现有函数，完成状态及历史服务时点为 SQL 控制，不是 1000 次真实美容服务。原始恢复快照在任何写入之前建立。测试始终保持全局排序启用，不修改权重或验证名单。

| 范围 | 已执行证据 |
|---|---|
| 真实角色准备 | 顾客发布、两位美容师报价、顾客四种排序与两页读取、跨顾客请求拒绝；`matching-results-prepare.json`。 |
| 评分与抗操纵 | 千评整数聚合/独立算术对照；10 账号协同正负压力 SQL 事务回滚；`matching-results-evidence-db.json`、`cohort-db.json`。 |
| 美容师性能 | 26 候选：SQL 首读 412.235ms，其余 29 次 P95 145.613ms（全 30 次 148.940ms）；HTTP 首次预读 427.989ms，随后 30 次 P95 205.352ms；`role-latency-groomer.json`。 |
| 顾客性能 | 2 有效报价：SQL 首读 1059.504ms，其余 29 次 P95 934.365ms（全 30 次 935.070ms）；HTTP 首次预读 1101.793ms，随后 30 次 P95 1124.184ms；`role-latency-customer.json`。不是 26 报价池证据，也不是清空数据库缓存后的冷启动实验。 |
| 固定负载 | 80 次双端首次浏览、一次共享报价撤回后的 20 个旧游标检查，详见下表；`paging-matrix.json` / `paging-summary.json`。 |
| 并发与隔离 | `matching-results-verify.json` 7 项通过：篡改/错角色/跨模式游标拒绝；重复服务配置不破坏有效报价，也不复活已撤回报价；4 个并发接受调用得到同一预约回执，数据库仅 1 条预约；成交使旧游标失效，未完成预约不可评价。 |
| 双端 UI | 美容师三种模式、重启保留偏好和实际第二页；顾客四种报价模式；浏览中新评价/报价两次保留旧内容、停止追加并手动恢复均通过。`ui-MatchingSortPreferenceAndPaging.json`、`ui-CustomerMatchingSortModes.json`、`ui-MatchingLivePageChanges.json` 和对应截图。顾客仅 2 个有效报价及 1 条撤回历史，不能声称正式 UI 大报价池分页已测。 |
| 自然到期 | `ui-MatchingOfferExpiresDuringConfirmation.json`：已打开确认页从可提交变为禁用并显示 Offer Expired；`natural-expiry-api.json`：真实顾客提交返回 HTTP 400 / `offer_expired`，权威评估 reason=expired，预约数 0。没有修改设备/服务器时钟。 |
| iOS 集成 | `ios-regression.json`；695 个 test cases 中 670 通过、25 跳过、0 失败，不与参数展开后的执行次数混算。 |
| 安全检查 | `advisors.json`：0 ERROR、1 既有密码泄漏防护 WARN、25 INFO；未改 Auth 配置或无关索引。函数权限/搜索路径与部署前一致。 |

| 负载 | 美容师首次完整 | 顾客首次完整 | 原预算 / 恢复 |
|---|---|---|---|
| 不变 | 10/10 | 10/10 | 两侧均须 10/10，通过 |
| 无关宠物每 10 秒变化 | 10/10 | 10/10 | 两侧均须 10/10，通过 |
| 专业评价每 60 秒变化 | 9/10 | 10/10 | 两侧均须至少 9/10；1 次中断，一次刷新恢复 |
| 专业评价每 10 秒变化 | **3/10** | 8/10 | 两侧均须至少 8/10；美容师未达标；9 次中断均一次刷新恢复 |
| 一次共享报价撤回 | 10/10 旧游标拒绝 | 10/10 旧游标拒绝 | 20 次均一次刷新完成；旧报价接受返回 `offer_not_pending` |

每侧每负载页间计划等待 1/5 秒各 5 次，相位均匀错开。无关/60 秒/10 秒变化实际与美容师浏览重叠 8/1/7 次，顾客 4/0/4 次；因此顾客 60 秒行不证明覆盖了浏览中的变更。SQL 调用可能延长实际等待，原始事件保留计划、开始、提交与结束时间。所有完成/恢复浏览均检查重复，静态候选全集无遗漏；硬变化按变化后的集合读取。上述分母不是独立真人，也不是生产可靠率。

复用边界：取消/改期、时段释放重新发现、迟到响应与 DEBUG 失败重试复用未变的 [T-390](T-390_MATCHING_RATING_ACCEPTANCE.md) E/F 及本轮完整回归；没有重复 43 项无关角色回归，也不将故障注入称为真实断网。

测试过程偏差仅保留原因与处置：V-01 helper 初始化顺序修正后通过；顾客排序首次导航失败（目标在合成历史第 445 位），保留失败 bundle，仅将精确归属的测试需求排到最新后通过；到期准备曾被不可变条款和未完成匹配处理拦截，改为新建短有效期夹具并调用正常队列处理，不关闭保护。没有重复生成千评夹具。

附带导航边界：顾客请求当前先按创建时间分页全部状态，再筛选活动卡片，历史量大会增加查找老活动需求的加载次数；存在 Load More，不是永久丢失。此轮报价排序 UI 的受控顺序不证明千条历史导航体验通过；活动/历史查询分离可作为独立优化，不成为评分修复的新前置条件。

## Restoration

精确归属范围为 1,029 条需求、1,001 条预约、1,000 条评价及其测试服务/宠物/通知/会话。清理后 15 组业务快照对照通过；美容师资料仅保留合法前进的更新时间，其余字段逐项恢复，设置版本不倒退。私有上下文、投影、候选、队列均为 0；全局 enabled=true、验证名单为空，未改 Auth/Storage、签名或设备配置。

`matching-cleanup-scope.json`、`restoration.json`、`review-profile-restoration.json`、`matching-private-restoration.json`、`restoration-final.json` 为恢复证据，`recovery.json.restored=true`。首次清理已恢复业务数据，但三个定时批次后仍有 605 条删除源队列；`cleanup-first-pass.json` 保留该失败。随后调用正常 worker 有界排空，确认业务快照未发生变化、私有残留全零才标记恢复；没有重新执行删除或直接清空队列表。现有清理回调改用同一有界 worker，避免依赖固定 30 秒等待。

## Remaining Evidence

2026-09-14 用户采用[拟真数据](T-391_REALISTIC_REQUESTS_AND_QUOTES.md)后，已完成下述数据库受控回放。全部仍为合成来源，不占真实样本目标；未填真人标签、未开启保留集。

1. 脱敏真实需求/有效报价与独立标签：计划目标 60 个决策快照、至少 2 位美容师评审；真人可用性试验目标 5 位顾客、2 位美容师。实际收到真实决策/独立标签/参与者均为 0，不能勾选盲评/真人步骤；不打开保留集、不改线上权重。
2. 实际服务质量、成熟预约结果及市场因果提升未验证；真实服务与大规模市场实验不是本地工程收口的新增前置条件。

整体任务未完成，不作完成提交/推送；原有用户修改保持原样。

## Synthetic Source Replay

2026-09-14，`artifacts/testops/TESTOPS-T391-20260914-C/`。复用既有空闲的 22 个顾客、12 个美容师测试身份，通过 SQL 事务中的 authenticated 角色/claims 调用实际发布、报价、排序、撤回与接受 RPC。**这是数据库角色模拟，不是 JWT HTTP、Simulator 操作或真人服务。** 入口为现有脚本的 `marketplace-db` 模式，SQL 位于 [matching-marketplace-replay.sql](../../../tests/fixtures/matching-marketplace-replay.sql)；所有事务只回滚，不创建或删除 Auth 账号。

| 检验 | 结果与范围 |
|---|---|
| 数据与全集 | 24 个不同需求、57 份来源报价场景、55 份当前可选报价；美容师侧 93 个合法候选对，与独立源事实的物种、服务、体型档位、方式和 PostGIS 半径计算逐项一致，需评估状态一致，无多余或遗漏候选。 |
| 双端排序 | 12 个美容师决策和 24 个顾客决策，合计 36 份快照、132 份模式列表；各模式候选全集一致、pending=0，价格/距离/最早时间契约通过。R06 保留明确价格意图，$55、$60 先于 $75；R15/R24 保留空池，超预算报价不被硬过滤。 |
| 8 个负例 | X01/06/07/08 返回 `match_not_found`；已有预约冲突 X02 为 `groomer_unavailable`；越出顾客窗口 X03 为 `offer_outside_customer_window`；未知资料/定制范围未确认 X04/05 为 `assessment_confirmation_required`。X05 不证明系统能理解并自动识别手拔毛与推剪的语义差异。 |
| 4 组关联成交 | SEQ01 同家庭重叠、SEQ04 跨顾客共享美容师重叠：第一单成功，第二单 `booking_conflict`；SEQ02 同家庭顺序预约与 SEQ03 清洁缓冲结束边界，两单均成功。各组独立回滚；这是顺序提交，不冒充并发证据。 |
| 到期/撤回 | R23-A 在实际服务端截止前 1 微秒可选，截止时 `expired`；随后正常撤回，当前池仅 R23-C。运行时两份历史报价均为撤回状态，不是自然等待到期。自然到期 UI/HTTP 沿用 B 的既有证据。 |
| 评分边界 | 148 个候选观测全部 `no_evidence`；虚构星级/评价量未转换成评价明细，不能称已覆盖本组多评价、跨物种评价或近期负面情景。12 个美容师决策中 4 个综合/距离 Top-3 集合不同，包括同距离并列；V-05 为较明显的距离取舍。顾客池大多不超过 3 项，Top-3 集合一致不能证明排序有效。 |
| 离线结果 | `decision-snapshots.json` 冻结实际排序并保留各模式原始 revision；比较 revision 为这些版本的共同哈希。`blind-labels.json` 为空，现有 CLI 输出双端 `insufficient`。美容师共享池归 1 个来源组，顾客保留重复家庭关联；全部 development，不补足 60 个真人决策。源风险 strata 是设计意图，不能当作实际评价历史/自然到期已覆盖的证据。 |
| 恢复 | 各次 `marketplace-restoration-*.json` 前后资料/服务/设置/宠物指纹一致。`marketplace-final-audit.json`：活动回放事务、标记需求、标记宠物均 0；enabled=true、验证名单为空。未改线上权重、持久业务代码或迁移；未写 Auth/Storage。 |

运行适配与计数：服务日整体后移 7 天至 9/21-28；社区中心点替代源估算距离，同社区可能为 0，不能代表门牌位置或路程。公开 RPC 管理创建时间与 48 小时需求有效期，未实现源叙述中的任意报价截止时间；同一 SQL 语句创建时间相同，`newest` 本轮只有并列排序证据。体重约束落到既有体型档位，不是精确设备承重模型。管理接口约 120 秒网关时限导致整批尝试失败，最终按关联决策分成美容师 1 批、顾客 3 批；保留失败与恢复记录，不把失败当通过。R05 的 2 份报价为跨单验证在第二批重放，故成功顾客批次产生 59 份报价回执而非 59 个不同场景；各批另有 B01 辅助占用预约，不计入 24/57。

证据入口：`functional-checks.json` 保存全集、负例、顺序成交和到期结果及 4 份成功原始输出指针；`distance-matrix.json` 保存 288 个常量坐标对；`quality-results.json` 保存无标签结论。JSON 使用私有权限，配置摘要排除签名密钥。`node --test tests/matching-quality.test.mjs` 本轮 **20 通过、0 失败**，包含回放门禁/只回滚模板检查；未重复运行未变的 iOS 全回归与 B 的并发/分页验证。
