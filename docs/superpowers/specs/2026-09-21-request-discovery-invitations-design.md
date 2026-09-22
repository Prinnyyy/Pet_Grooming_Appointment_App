# 推荐美容师、定向邀请、需求池与收藏设计

<!-- task-artifact
task: T-399
status: completed
type: spec
-->

2026-09-21。T-397 是方案与计划编写任务；T-398 对照现有代码补齐第7节复用边界与对应验收。T-399于2026-09-22完成实施；实际部署、验收证据及限制见[实施计划](../plans/2026-09-21-request-discovery-invitations-plan.md#8-完成标准与执行记录)。本文保留采用时的产品规则，不单独证明部署或未来更大规模性能，也不继承历史任务的远程写授权。

## 1. 产品目标与范围

让顾客先说明宠物、服务、地址和时间，再选择向哪些美容师发出同一份 Request；可自愿同时开放需求池，允许其他合格美容师报价。滑动是浏览，不是拒绝；收藏是账号级私人名单，不是邀请或预约。

统一主链：

```text
本地需求草稿 -> 私有候选预览 -> 首次明确发送/仅开放需求池
                                      |
                              一份已发布 Request
                                      |
             定向邀请 + 可选需求池 -> 同一组 Offers
                                      |
                           顾客接受一份 -> 一个 Booking
```

不改变 Request 的服务条件，不加入多套备选时间、范围外还价、自动加价、自动预约、预留空档、预约前聊天、长期候补或隐式行为学习。报价、接受、改期、履约和评价复用现有权威流程。没有供给时必须承认没有供给，不能以动画、假人数或承诺回复时间代替结果。

### 1.1 用户已确定的方向

- 创建需求时可选需求池，所有符合条件的美容师有机会发现并报价；定向邀请同时保留。
- 推荐 5-10 张可反复查看的美容师卡牌，左右滑动不 pass、不发送。
- 卡牌有明确发送 Request 和收藏按钮；收藏在独立列表中管理。
- 末尾允许用户明确选择查看更多；完整列表包括前面的推荐美容师，并覆盖当前需求下的全部合法候选。

### 1.2 首版默认值

以下是可审阅的产品参数，不声称经过真实市场最优化；更改须同步测试，不能静默改变授权范围。

| 参数 | 首版设定 | 原因 |
|---|---|---|
| 推荐张数 | `min(8, 当前已确认可展示候选数)` | 在用户的 5-10 范围内固定，不凑数 |
| 需求池 | 新需求默认关闭，每次单独确认，不继承账号默认 | 避免把浏览或上一单选择当作本次公开同意 |
| 完整列表 | 默认适配排序，支持距离排序；每页 25、服务端上限 50 | 复用分页习惯；没有真实报价前不提供最低成交价排序 |
| 定向邀请 | 同一 Request 最多 5 位未结束的受邀者；含其尚可选择的报价 | 防止对全部列表群发；不截断候选浏览，不限制池中合法报价 |
| 重复邀请 | 同一 Request/美容师最多一条定向邀请；取消、婉拒、到期后不反复催发 | 追加其他人可行；不能靠新操作号刷新邀请期限 |
| 邀请回复期限 | `min(sent_at + 24h, request.expires_at)`；服务器时间 | 只表示本次邀请的报价入口期限，不保证真人回复 |
| 新版需求期限 | `min(published_at + 48h, preferred_end - 5min)` | 沿用 48h 上限及现有提前量，不在可服务窗口结束后继续等待 |
| 私有预览 | 30 分钟有效、每账号最多 4 个未消费会话，输入修改创建新会话 | 有限留存，不形成开放订单或占用现有 3 单额度 |
| 浏览软快照 | 最长 5 分钟，每账号 32 个、单个 256KiB；硬事实实时重核 | 沿用 D-056 的边界，超限不能截断候选池 |
| 收藏 | 最多 500 位，账号同步，默认最近收藏在前 | 明确容量，幂等设置，不广播给美容师 |
| 页面更新 | 可见且 App 前台时复用 45 秒兜底；前台恢复/操作后刷新 | 不为等待页高频重算所有评分，不后台循环 |

24h/48h 是 elapsed time，不伪称营业小时。最后可报价时点仍由实际服务时长、时间窗、缓冲、提前通知和资源校验决定；上述上限不赋予可服务资格。用户可只邀请一位；界面不强迫选满，不承诺人数越多越快。

### 1.3 路线取舍

纯定向目录会收窄无人回应时的机会；继续纯公开分发缺少用户对对象的选择权；两套独立订单系统会复制额度、报价与结束规则。因此采用单Request的混合分发。首版不做批量勾选面板：用户逐张/逐行发送即可邀请多人，后台接受小批量参数用于原子性而非鼓励群发。全部名单仅是当前需求上下文中的候选，不扩展为全站陌生人社交目录。

## 2. 页面与交互

### 2.1 创建与预览

复用现有 Wizard 的宠物、服务、地址、时间和复核步骤；将最终直接发布动作改为 `Find Groomers`，进入私有推荐预览。需求池开关放在复核步骤，推荐页保留紧凑可见状态及修改入口。

进入预览只创建 owner-scoped 临时上下文和短期排序缓存，不创建公开 Request、match、通知、聊天、报价，不上传 request-photos，不扣开放请求额度。照片保留本地已有草稿路径，服务端读取当前 owner 宠物资料生成可信快照，不接受伪造宠物来源。

第一次点卡牌 `Send Request` 时，确认摘要列出本次目标、需求条件及需求池状态；明确确认后原子发布并邀请。后续给其他人发送直接追加到同一 Request，展示已邀请数。提供明确的 `Publish to Request Pool` 独立操作，允许没有选人或当前零候选时仅开放需求池；池关闭且未选人不能发布空的定向请求。

首次成功后推荐页保留，不立刻关闭导致用户无法继续邀请；页头改为已发布状态，并提供查看需求进展入口。第一次发送过程中禁用同一草稿的其他发送动作；后台幂等仍必须处理多设备、重复点击和丢响应，不能仅靠按钮禁用。

未发布时退出不留下可被美容师看到的需求；已发布后退出推荐页不取消 Request。恢复未决发送必须先对账，不能让用户修改输入并用新操作号再次发布。

### 2.2 推荐轮播

每张卡牌展示：美容师名称/业务名、真实头像或作品缩略图、服务方式、距离、预计时间资格、相关专业证据、公开星级与数量、明确标注的服务参考起价，以及发送、收藏、查看资料入口。

- 使用 `预计符合` / `需进一步评估`，不得显示保证可约、虚构接单概率或把参考价当正式报价。
- 8 位来自同一个全量排序结果的前 8 位，不用客户端对第一页单独重排。
- 卡牌等宽、稳定高度区域；长名称/大字号允许布局增高和内部内容滚动，不遮挡按钮。原生分页轮播、页码、辅助功能可操作按钮；不以自绘手势取代所有导航。
- 左右滑只换页，不写偏好、不 dismiss、不通知；收藏与发送不改变本次浏览的排序。
- 最后一位后是一张非美容师的尾页，显示 `View All Matching Groomers` 按钮；用户点击确认进入完整列表。越界拖动只露出尾页，不再次弹模态确认，不劫持系统返回手势。
- 只有 0/1/3 位时如实展示，零候选仍允许调整输入或仅开放池；网络失败、评估未完成不能渲染成零候选。

### 2.3 完整列表与资料

完整列表共用 DiscoveryStore 的候选实体、已发送与收藏状态、浏览快照和游标。推荐页可先请求 25 条只展示前 8 条；进入列表显示已缓存 25 条后继续翻页，包含前 8 条且每人一次。回到轮播保留当前美容师 ID，不重置到第一张。

列表的“全部”指同一输入和本次浏览时点下所有 `estimated_fit` 与 `assessment_required` 候选，不包括已确定排除者；pending 数量单独标注“仍在检查”，不能声称全集已穷尽。资格、时间或隐私发生硬变化时停止追加，保留可安全展示的数据并提示刷新；不可继续把被撤权的卡片/图片留作可用。

不为第一屏加载全部人或全部作品。详情复用安全资料与专业证据展示；不开放美容师私人日程、联系方式、精确住址或原始评价顾客数据。业务到店地址只在其明确公布的业务地址契约内展示，不把 owner 地址 RPC 当公共目录。

### 2.4 收藏

Customer Account 新增 `Saved Groomers` 导航入口，不增底部 Tab；需求推荐页提供进入收藏并使用当前 Request 的入口。

- 没有当前 Request 时，收藏页展示普通资料；发送动作引导选择已有开放 Request 或进入现有创建流程，不跳过需求输入。
- 有当前 Request 时逐位显示当前资格，不适合者仍保留在收藏页并禁用发送，说明不符合本次需求，不偷偷从收藏中删除。
- 收藏状态服务器同步，UI 可乐观更新并按操作代数拒绝晚响应；失败回滚/重新读取。使用 `set favorite true/false` 而非非幂等 toggle。
- 跨设备写采用revision比较；相同目标状态可返回当前结果而不写，冲突后读取真实状态，不自动重试覆盖另一设备。取消收藏保留最小false状态/revision以解决竞争；false记录30天后可清理，旧revision再写视为冲突，不当作新建。
- 本人列表只对本人可见；美容师不知道谁收藏了自己，没有收藏数、收藏通知或公共加分。
- 暂停服务的美容师显示暂停；删除/匿名化账号以不可识别占位或关系清除处理，不能继续回显旧姓名头像。退出登录清理内存和图片关联，收藏本身不随退出删除。

### 2.5 已发布需求与美容师端

顾客详情显示两个独立区域：受邀美容师回应状态、需求池开放状态；报价合并到现有 Offers，标记来源只用于解释，不影响资格或重复排列。对每位美容师的单条报价不因来自两条入口而复制。

美容师端保留现有 Requests / Offers 布局，为受邀项增加 `Invited by customer` 标记和邀请截止时间；非受邀项来自需求池。相同 Request 只一行。保留原资格分组和排序，不在评分里偷偷加邀请权重；“受邀”可作为显式筛选而非第二套任务列表。

美容师可报价或婉拒。复用原 dismissal 入口扩展可信回复结果；顾客只看到 `Declined`，不展示每一条私人拒绝理由。曾在池中 dismiss 的同一 Request 不因随后邀请、池开关或 worker 重算复活；顾客看到该对象当前不可邀请，无需获知内部理由。

## 3. 单一生命周期

### 3.1 三类状态不混用

| 对象 | 权威事实 | 禁止的解释 |
|---|---|---|
| Request | 现有 open/has_offers/booked/cancelled/expired；条件 revision | 不增加名为 matching 的预约状态来假装系统持续工作 |
| 分发 | pool_enabled、distribution_revision、受邀关系 | 开关不改服务条款，不重新发布、不重置期限 |
| 候选资格 | estimated_fit/assessment_required/excluded/pending，有时效 | 不是邀请已送达、已读或接单承诺 |
| 邀请回应 | waiting/quoted/declined/withdrawn/expired/closed，按权威数据推导 | 不拿通知创建或列表出现当真人查看 |

回应主状态优先级：Request 终态 -> 存在当前可选报价 -> 邀请撤回/明确拒绝 -> 未报价邀请自然到期 -> 等待。邀请是否撤回作为独立事实可同时显示；撤回邀请不代替报价撤回，已有有效报价仍显示其真实状态。报价已失效且邀请仍有效时可重新报价，沿用既有同人报价历史与唯一可选约束。

### 3.2 可报价权限

```text
can_create_offer =
  request仍开放且未到期
  AND actor是合法美容师
  AND 本Request未被本人dismiss
  AND (有效定向邀请 OR request.pool_enabled)
  AND 现有权威服务/地点/时间/宠物准入通过
```

match 只是当前候选事实，不能单独授权报价。已存在报价的双方仍可在其必要范围读报价历史、撤回、核对与接受；其可选性由现有报价规则加本设计的分发规则明确决定，而非保留整个 Request 的公开访问权。

### 3.3 操作规则

| 操作 | 明确结果 |
|---|---|
| 开启池 | 仅同一 Request 开放合格发现，排队刷新资格；不保证通知全员，不复活 dismissal |
| 关闭池 | 同事务撤销未受邀且未报价者的新发现/详情读取/报价权限；有效邀请保留；已有报价仍可按原条款选择 |
| 取消某邀请 | 停止该定向授权；若池仍开且对方符合条件，他仍可从池报价，确认文案说明；不能冒充屏蔽此人 |
| 邀请到期 | 停止该定向的新报价入口；池仍开时可以走池；已有有效报价不因回复期限到期而作废 |
| 美容师婉拒 | 同一 Request 的两种新报价来源均停止；已有报价撤回和 dismissal 必须原子协调 |
| 追加邀请 | 不创建新 Request、不占额外开放需求额度、不改条件或已有报价，重查资格和人数 |
| 接受一份报价 | 复用原唯一成交、宠物/美容师资源锁；其他邀请关闭，其他报价按原规则结束 |
| 取消/到期 | 两种入口同时结束；旧界面提交被服务端拒绝；有历史与重发入口 |
| 修订服务条件 | 复用原 atomic replacement：旧需求与报价关闭，新条件先预览，再确认新发送范围；不复制旧邀请、不默认重新公开 |

退出池或关闭客户端不能让已看过的人“忘记”资料；承诺的是撤销未来服务端访问和动作。为降低持续暴露，私有请求图片使用鉴权读取而非长效签名链接，缓存撤权时丢弃；已被用户截图或下载的数据不能技术撤回。

### 3.4 没有报价与到期

等待页文案按真实事实生成，而非伪进度条：

- 仅定向、还有待回应者：列出对象与截止时间，可邀请其他人、开放池、取消需求。
- 仅定向、全部已结束且无有效报价：明确“目前没有可用报价”，提供追加邀请或开放池；不静默关闭仍有效 Request。
- 池开放、候选为零：显示“当前条件下暂无合适美容师”；新候选可由原事件/时间刷新发现。
- 池开放、存在候选但无报价：显示开放中及最近检查时间，不显示未采集的已读数或推送送达数。
- 后端处理未完成/读取失败：单独显示检查中/无法更新，不按零候选处理。
- 到期或取消：主列表的最近关闭区域同时容纳 cancelled/expired，提供可分页历史与从模板创建入口；不因只显示最近 3 条导致其余历史无法访问。

一期不新增自动催促或多个“30分钟没有回复”任务。请求自然截止不依赖 App 前台或 cron 成功：读取和写入按服务器时间立即判定，已有批处理负责落库与一次性到期站内通知。UI 在有效截止点刷新本地呈现，但不能据此代替服务器授权。

## 4. 候选与评分

### 4.1 报价前独立读取，复用评分内核

旧顾客 RPC 排的是已存在 Offers，新发现 RPC 排的是 Groomers。不能反向读取美容师私有 match 表或调用现有发布接口造一个隐藏订单。

新排序：完整候选资格筛选 -> estimated_fit 优先、assessment_required 其次 -> 适配组内沿用 `S = 0.60F + 0.25Q + 0.15D` 的 2 分桶与稳定 HMAC 平局 -> 分页。距离模式组内距离升序，后续沿用稳定键。F/Q/D 的定义、独立顾客限权、衰减、负面/未知、宠物服务隔离不变；只做可复用的输入适配，不复制算法。

尚无报价时按现有跨日期年龄处理契约构造目标特征；缺最终价格/时长不得猜测成已达成条款。公开显示专业证据而非私有 S 或百分比。收藏、卡片浏览、邀请、未回复和成交失败不进入评分。新人保留中性证据且可全量发现，不承诺必定进前 8。

预览使用持久的本地 draft UUID 作为稳定推荐键，服务器校验所有权并记录在私有会话中；发布操作保存其到Request的关联，HMAC平局键继续使用该draft身份，老Request无关联时才用Request ID。刷新/重开同内容不重新抽取平局顺序。变更排序或条件建立新浏览，不混合新旧页。

首次发布成功后，原preview scope在原会话/浏览截止前成为本人新Request的只读别名，服务端通过已受理publish operation解析Request并核对input digest；当前卡牌、位置和分页保持，所有动作转向真实Request ID。不得因延续浏览再次创建match/邀请，也不能延长原快照寿命。刷新或自然过期后转为request scope；真实硬条件变化仍返回list_changed。预览原始输入可清理，但最小alias关联保留到会话截止；换号与非owner无法使用。

### 4.2 新鲜度与性能

复用现有地点、资格和时间 oracle，提取接受可信 request context 的私有重载；现有 request_id 包装器保持行为。只允许服务器从 owner 宠物、地址输入和合法服务时间构造 context，客户端不能提交 eligibility、评分、时区目录或身份。

粗筛不等于结果截断；没有证据的新人、只需评估者仍进入合法全集。新读不为每位候选分别发 HTTP，不扫描全站图片。头像和专业补充信息沿现有 core-first / 有界并发加载。

复用 D-056 的短期软证据存储方式，scope 使用 `discovery:<preview-or-request-id>`，和报价浏览隔离；硬资格、membership、会话/账号权限及隐私 revision 每页重核。收藏/已发送是操作覆盖层，不因一次收藏重排整个列表。超快照预算回退严格一致性读取，不声称“仅有前 N 位”。

首版性能验收：至少26候选/约1,200条历史评价，沿用 SQL P95 <=1500ms、认证 HTTP P95 <=2500ms，每组30次，首读单列。100位以上真实容量测量需足够现成授权身份或既有隔离数据库；不可用时明确未验证，不新建Auth账号或数据库平台作为本计划前置。至少101项本地向量只证明全量排序/分页逻辑，不冒充服务器压测。超预算先剖析重复资格/评分和JSON构造，不放松资格、截断全集或升级工具链；原报价/成交路径不因本功能超原预算。

## 5. 数据与接口边界

名称为实施契约；实施中可以凭代码反例统一更名，但不得保留两套不同语义接口。

### 5.1 数据所有者

| 对象 | 字段/约束 | 所有权与留存 |
|---|---|---|
| `grooming_requests` 扩展 | `pool_enabled boolean`、`distribution_revision uuid`、`distribution_version` | 旧行标记 legacy pooled；新分发协议必填公开同意，拒绝隐式 true |
| `app_private.request_discovery_sessions` | id、customer_id、draft_id、server input digest、规范化 context、expires_at | 无客户端表 grant；30min、每人4个；过期私有输入批量清理，无公开状态/通知 |
| `app_private.request_invitations` | request_id、groomer_id、terms_revision、sent_at、reply_by、withdrawn_at、declined_at；pair 唯一 | 服务端写；回应由邀请+报价+Request 推导，不复制一套 Booking |
| `app_private.request_distribution_operations` | customer_id、operation_id、kind、canonical input hash、request_id、receipt；owner/op 唯一 | 仅覆盖发布后的追加/池切换/撤回；不重复存首次发送回执，不是通用任务队列 |
| `app_private.customer_groomer_favorites` | customer_id、groomer_id、is_favorite、favorited_at、updated_at、revision；pair 唯一 | 只经 owner RPC，500上限只计true；false最小状态30天清理，账号删除清理 |
| 既有 `app_private.request_publish_operations` | 补 discovery_session_id 唯一关联、discovery_draft_id、协议版本、canonical input hash、分发回执 | 首次发送/原子替换的唯一回执所有者；同一预览不能因两台设备各用一个 operation ID 发布两单；稳定排序/短期scope别名与回执关联不依赖保留原始预览 |

新会话保存规范化的完整待发布文本输入（含service_notes、现有draft的supersedingRequestID/expectedRequestRevision）及可信宠物/地址来源revision，并从中派生匹配context；不存照片字节。digest覆盖完整发布文本输入，排除transport operation UUID与本地文件路径，不能只哈希影响评分的字段；服务器自己规范化与计算，不相信客户端digest。发送时源资料被修改则返回`discovery_changed`，保留草稿并要求复核，不偷偷替换快照。图片/图片说明仍由本地不可变发送意图及后续上传负责。过期清理不删除已受理操作的最小回执；隐私删除清除新表中的个人内容副本。

### 5.2 新 RPC

均为 authenticated/non-anonymous 受控 wrapper，显式校验数据库角色/owner，固定 search_path。以下 JSON 只含命名契约的字段；拒绝未知写字段和无效组合。

| RPC | 输入 | 输出/行为 |
|---|---|---|
| `prepare_request_discovery_v1` | `p_draft_id uuid, p_input jsonb` | session_id、input_digest、expires_at、规范复核摘要；相同有效输入可复用，不公开 |
| `get_request_groomer_candidates_v1` | `p_scope jsonb, p_sort text, p_limit int, p_cursor text?` | 候选页、两种资格计数、pending_count、as_of、valid_until、revision、next_cursor |
| `get_discovery_groomer_profile_v1` | `p_scope jsonb, p_groomer_id uuid` | 当前授权下的安全资料/媒体元数据，不返回完整日程/私人地址 |
| `publish_request_with_distribution_v1` | `p_operation_id uuid, p_session_id uuid, p_input_digest text, p_pool_enabled bool, p_groomer_ids uuid[]` | 一个 Request ID、terms/distribution revision、邀请回执、池状态；首次原子发布 |
| `invite_request_groomers_v1` | `p_operation_id uuid, p_request_id uuid, p_expected_terms_revision uuid, p_groomer_ids uuid[]` | 新发送/已发送回执；不修改条款或公开范围 |
| `set_request_pool_v1` | `p_operation_id uuid, p_request_id uuid, p_expected_distribution_revision uuid, p_enabled bool` | 新分发 revision、实际池状态；目标状态写入，不是 toggle |
| `withdraw_request_invitation_v1` | `p_operation_id uuid, p_request_id uuid, p_groomer_id uuid` | 撤回回执、是否仍存在池入口、已有报价状态 |
| `get_customer_request_progress_v1` | `p_request_ids uuid[]`（1-25） | owner 批量进展：权威请求状态、受邀状态、池状态、候选是否完成评估、有效报价数量、截止与检查时间 |
| `set_groomer_favorite_v1` | `p_groomer_id uuid, p_is_favorite bool, p_expected_revision uuid?` | favorite、revision；并发旧 revision 返回冲突后读权威，不任意逆转新操作 |
| `get_my_favorite_groomers_v1` | `p_scope jsonb?, p_limit int, p_cursor text?` | 按favorited_at/id的签名keyset分页，items/next_cursor/revision/as_of；有scope才附资格，无scope不显示假适配 |

`p_scope` 恰为 `{kind:"preview", id:<session UUID>, input_digest:<digest>}` 或 `{kind:"request", id:<request UUID>, terms_revision:<revision>}`，不能同时提交两种身份。scope 不是 bearer 授权，逐次校验 actor。session 失效返回 `discovery_expired`；Request 条件改变返回 `request_changed`。

候选项共同字段：groomer_id、safe_profile、eligibility、matching_evidence、distance_miles、reference_price（amount/currency/service_id/reference_only）、favorite_state、invitation_state。公开状态枚举保持窄范围，原始评分、私有拒绝原因、其他顾客数据不返回。

操作 `p_groomer_ids` 规范去重，0-5位；首次为空仅允许 pool=true；追加必须1-5位。新目标逐一重新鉴权/校验，其中一位失效则整次新发送不提交并返回可修复错误，不暗中转为 pool-only，也不静默发送给另一批人。已受理相同操作回放先于 session 到期/当前额度检查；不同 payload 复用同一操作号返回 `operation_intent_changed`。

同一 session 已发布但新 operation 指向另一个目标时返回 `already_published` 与 owner 可见的原 Request ID，不创建第二单、不偷偷追加。客户端确认恢复原 Request 后再执行显式追加。

用于修订的session携带原Request及其expected terms revision，`publish_request_with_distribution_v1`在同一事务调用既有版本化替换核心，再按新pool/recipients生成替代Request；旧Request取消和新发布要么都成功要么都回滚，不能在客户端分两次请求完成。新旧客户端未决操作按各自protocol_version恢复；既有`create_grooming_request_v4`属于旧发布协议，不把其重试改送新分发RPC，也不把RPC名字中的v4当作新分发版本。

### 5.3 事务与并发

首次发布原子写 Request、明确 pool 值、邀请、受控 matches、操作回执和站内通知；不能先跑旧 create_request 自动广播再撤回。照片继续发布成功后上传，失败沿现有可见重试路径，不把“照片失败”当成未发布。

同一 Request 的 pool/save-invite/withdraw/quote/cancel/accept 以现有 Request 锁为共同线性化边界；涉及 groomer 资源时严格复用当前 Save/acceptance 的 advisory/row 锁顺序，不凭本文臆造另一顺序。先记录实际锁图，再新增分发锁。数据库锁约束参照 [PostgreSQL 官方说明](https://www.postgresql.org/docs/current/explicit-locking.html)，具体顺序由现有权威实现和竞态测试确定。

并发语义必须验证两种顺序：quote 先提交再关闭池，既有报价可保留；池先关闭且无邀请，新 quote 被拒绝。invite 与 cancel/accept 竞争，后提交者不能创建终态 Request 的有效邀请。5位上限必须锁内计数，两台设备同时追加不能变成6位。窗口变化/资格 pending 时邀请失败可恢复，但不得误报为已通知。

对仍有效的旧 quote，pool/invitation 开关不是 terms_revision 变化，不直接作废协议；服务/宠物/地址/时间条件变化继续通过版本化替换处理。资格变更或资源冲突仍使 quote 不可选择，邀请不绕过门禁。

## 6. 权限、媒体与旧客户端

### 6.1 访问规则

| 场景 | 顾客 | 美容师 |
|---|---|---|
| 私有预览 | 本人可看候选安全资料；不读内部候选/评分表 | 不可发现该草稿或收到通知 |
| 定向 Request、池关 | owner 看进展及报价 | 有效受邀且资格允许者读报价所需摘要；未受邀者拒绝 |
| 池开 | owner 知道其他合格者可回应 | 全部合格者可发现，不按排名截断；精确详情仍受作用域控制 |
| 池关且已有报价 | owner 正常管理 | 报价方保留管理该报价所需的最小资料，不因历史报价取得任意新报价权 |
| 成交 | owner 进入既有 Booking | 获选者进入参与者权限；其他人只保留自己的报价历史摘要 |
| 收藏 | 本人列表；安全业务资料 | 看不到收藏关系，不取得顾客访问权 |

所有入口包括表 SELECT、RPC、Storage、通知跳转、旧客户端都需符合相同规则；RLS/grants 缺一不可，不能只藏按钮。[Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security) 与 [Storage 访问控制](https://supabase.com/docs/guides/storage/security/access-control) 作为实现参考，不代替本项目真实负例验证。

需求池列表只显示服务、宠物必要属性、时间窗和粗略位置；不含完整门牌、联系方式或自由备注。授权的需求详情可看用户确认用于报价的宠物安全备注和请求照片，结构化精确住宅地址仍不在 pre-booking DTO。服务地点距离由服务器私有坐标计算；成交后按既有参与者协议提供所需地址。用户自由备注/照片本身可能含个人信息，复核页明确其可见范围，不承诺自动识别和抹除所有隐私。

这会触及当前 groomer 直接读取含 street_address 的原始 Request 路径。需要安全 DTO/RPC 接管，并收紧原始列/关系权限；owner 顾客仍可经 owner RPC 读全量。不能声称行级 RLS 会自动隐藏同一行中的私密列。

美容师发现头像只能扩展为 authenticated customer 对 active marketplace profile 所需的专用 groomer-avatars 读取；不开放 customer-avatars、legacy avatars、任意前缀 listing 或整桶 public。无合法头像用正常占位，不伪造图片。作品继续走现有 active portfolio 契约。请求照片的新读取条件跟随实时分发授权；在关闭池/取消后清理客户端副本与失效状态。

### 6.2 通知与旧版安全

定向邀请与公开 match 建立通知去重规则：同一 pair 首次可发现创建一次站内通知；已有 pool 通知后增加邀请只更新其邀请语义/必要未读状态，不再创建第二条相同任务。重复操作和 worker 重跑不能再通知；关闭再开启不重新轰炸原 pair。通知 ID 可以复用，深链每次按实时授权解析。

旧请求保留其原先已经采用的公开分发语义，明确标 `legacy_pool`，不能把旧请求静默改成仅邀请导致业务丢失；旧请求 owner 可显式关闭池。

新分发协议请求必须经新发送接口。启用新客户端路径前，旧写接口不能产生没有明确 pool 参数的新发布：新操作返回 `client_update_required`，已受理的旧幂等回执仍可恢复。旧修订/报价/直接读取路径均补安全门禁；无法安全映射时明确要求升级，不回退到宽松授权。现有 Booking 参与者履约读取不因新发现功能停用。

功能回退只能停止新发现/新邀请，仍保留已发送 Request、进展/报价/收藏读取及所有收紧后的权限；绝不能为恢复旧 UI 重新开放已关闭的需求。

## 7. 实现范围与效率

复用：现有 Wizard/Store/Repository、可信匹配事实与 F/Q/D、报价与容量锁、atomic replacement、请求发布持久恢复、私有图片加载、站内通知和45秒前台兜底。

新增最少领域模块：CustomerDiscovery（推荐+全量+资料共享状态）、CustomerFavorites（账号名单）、RequestDistribution（发布/邀请/池及回执）。业务组件按所有权放Features或SharedFeatures，通用按钮与token才在DesignSystem。禁止继续把所有新逻辑塞进CustomerRequestsStore，也不为这一功能抽象全局workflow engine。

只维护这份设计、实施计划及 Current State；真实实施结束在计划末尾附一份简短验收记录，不新增每日长报告。日常针对性测试；集成/发布才完整回归。原 T-390/T-392 结果只是未受影响部分的基线，不冒充新增预览、收藏、权限或并发已经通过。

### 7.1 前端复用与状态所有者

以下路径相对 `ios/Beckon/Beckon/`。这里只抽取本功能实际有两个消费者的行为，不提前建设通用框架。

| 能力 | 现有来源 | 本次复用边界 |
|---|---|---|
| 需求输入、地址与时间 | `Features/Customer/Requests/CustomerRequestWizardState.swift`、CustomerRequestsStore的makeDraft/校验；`SharedFeatures/Address/BeckonAddressEditorState.swift` | 预览、首次发送、模板重发都使用同一GroomingRequestDraft和既有校验入口，不另写发现专用表单或DST逻辑。服务端仍独立权威校验 |
| 发布与重启恢复 | CustomerRequestsStore的publish、私有PendingRequestPublication、持久文件读写 | 窄抽取为同目录`CustomerRequestPublicationCoordinator.swift`与`PendingRequestPublication.swift`，旧发布入口和新DistributionStore委托同一实例；统一不可变意图、持久化、协议选择、重试/换号取消和回执确认，不复制publish方法 |
| 候选分页与证据 | `Core/Models/MatchRanking.swift`、`MatchingEvidence.swift`、GroomerRequest内`MatchEligibilityEvaluation` | 直接复用RankedPageRequest/RankedPage/RankedPageRow、canAppend与证据模型；推荐与全量使用同一DiscoveryStore的实体表和ID序列，不另建CarouselStore/ListStore或第二套分页器 |
| 美容师展示 | 现有GroomerProfile含私人地址；报价repository内有私有CustomerOfferGroomerProfileRow投影 | 新增窄`MarketplaceGroomerSummary`白名单模型及共享wire投影，发现/收藏/资料页共用；涉及的报价公开展示可适配该投影。不得直接暴露完整GroomerProfile、owner编辑仓储或复制整张报价卡冒充候选 |
| 展示组件 | `SharedFeatures/Matching/BeckonFitEvidenceBlock.swift`、既有DesignSystem token/按钮 | 证据块传公开MatchingEvidence，scoreText=nil；在Customer/Discovery内共用候选摘要/动作组件，收藏页复用。只有跨角色真实消费才移SharedFeatures；轮播/列表/详情保留各自布局，不做万能卡片 |
| 图片与刷新 | PrivateImageLoader、SupabasePrivateImageDataSource、SupabaseParticipantAvatarLoader；ForegroundRefreshGate | 复用取图/缓存/有界并发及45秒门禁，按新授权接入，不复制下载器。Participant头像入口若要求既有交易，则保留该限制，发现只复用底层loader，不伪造参与者身份 |
| 收藏与装配 | `App/AppComposition.swift`与CustomerTabView的会话生命周期 | composition注入既有SupabaseClient、仓储与loader；顾客会话只保有一个FavoritesStore和PublicationCoordinator。DiscoveryStore拥有一个scope的浏览；DistributionStore拥有该Request的动作/进展。显式传结果，不用全局事件总线或Store互相强引用 |

发布恢复的唯一写入者是PublicationCoordinator。原RequestsStore保留需求/报价管理及已有照片上传、重试路径，通过显式成功交接处理，不能再次调用createRequest。协调器先保存已确认Request ID，再交接照片；交接未完成可恢复，但不因此重发订单。沿用原账号隔离文件位置并兼容原无版本JSON；新意图明确标识`legacyV4`/`discoveryV1`与session/digest/pool/recipients。未知版本保留原文件并报错，不能当空草稿覆盖。这里只补本发送链路的可恢复交接，不建设照片任务平台。

收藏状态以FavoritesStore的revision为唯一来源；发送/池状态以DistributionStore的权威回执和进展为来源。Discovery页面按groomer ID叠加这两类状态，不把副本当成另一份可写事实；候选中的初始favorite/invitation字段不能用晚返回页覆盖更新后的状态。换号后取消读取并校验会话身份，清空内存，旧账号未决文件保留在原隔离空间而非交给新账号。

### 7.2 后端复用与副作用边界

核心不是“让所有RPC共用同一个大函数”，而是**独立鉴权入口，共用领域规则，隔离写副作用**。按仓库当前迁移定义定位；实施时核对实际最新定义，不能照旧文件复制一份算法。

| 能力 | 现有来源 | 抽取/接入方式与限制 |
|---|---|---|
| 可信上下文与资格 | `evaluate_match_constraints`、`evaluate_match_eligibility_with_zones`（`20260911070125_t390_match_input_contracts.sql`） | 将request行依赖收敛为服务器构造的私有context；request_id适配验证真实Request状态/来源/截止，各业务入口负责actor授权，受控worker不要求actor等于顾客owner。preview入口校验本人私有会话，不伪造open行；两者调用同一约束及可行时段内核，宠物、地点、时区、容量/缓冲原函数保持唯一实现 |
| 专业证据与评分 | `match_target_keys`（`20260911115915_t390_batch_ranking_timezone_validation.sql`）、`score_match_evidence`（`20260911142538_t390_materialize_review_decay.sql`） | 同样提取可信context输入；预览/Request/Offer适配器提供不同目标事实，F/Q/D、衰减、去重复权重、证据投影仅一份。原函数成为兼容包装；报价前与报价后时间事实不同，不强求最终排名相同 |
| 排序与短期快照 | `match_cursor_encode/decode`、`match_browse_snapshots`、`ranked_marketplace_browse`（`20260915233821_t392_browse_evidence_snapshot.sql`） | 复用游标签名和私有快照存取/清理，必要窄抽取被两种读取调用的helper；actor总上限32包含两种用途。发现与Offer保留独立成员查询/序列化、purpose/scope/排序白名单，不把不存在的Offer塞给旧RPC，不复制整套ranked_marketplace_page |
| 候选物化与队列 | `refresh_candidate_evaluation`、既有match refresh queue | 已发布Request沿原worker落评估、match和通知；私有预览只调用无业务写的资格/评分内核，不调用会落库并锁Request的refresh_candidate_evaluation，不让预览进入公开队列 |
| 首次发布与替换 | `create_grooming_request_v4`、`supersede_grooming_request`、`request_publish_operations` | 提取已有额度/快照/原子替换写核心，显式传分发意图并去掉无条件广播。首次发送仅在publish operations保存hash/协议/回执；发布后动作才写distribution operations。两套账本不同时拥有首次发送的“成功” |
| 分发权限与通知 | 既有match生产、quote/admission、Request/Storage策略和通知触发器 | 同一私有分发事实解析供多个用途使用；区分可发现、可新报价、可管理旧报价、可读最小媒体，不能共用一个宽松canAccess布尔值。各入口保留actor检查；贵的资格计算不塞入逐行RLS/每图片重算；通知复用原pair去重入口 |

Swift与SQL不共享可执行源码：服务端拥有资格、评分、公开范围和成交约束；客户端复用DTO、证据呈现与错误映射，不再实现一套F/Q/D或授权决策。共享契约通过现有SQL/Swift测试里的同组固定输入与预期校验，不为此引入代码生成、跨语言包或第三套规则引擎。

### 7.3 复用验收与范围控制

- HD-00形成一张短调用关系表：既有入口 -> 共用核心 -> 新消费者，写在本计划，不新增长期模块登记文档。
- HD-01用相同可信context/时钟/目标特征验证旧wrapper与新内核的资格、witness、F/Q/D及公开证据一致；再用既有固定预期防止“双方同时错”。Offer特有事实单独覆盖，不用不同输入要求相同排序。
- HD-02/05验证旧新发布都走唯一恢复组件，丢响应与照片交接失败不重复发单；首次只产生一份权威发布回执，发布后动作不另建Request。
- HD-03/04验证统一资料字段、分页解析和状态覆盖层；同一groomer在卡牌/列表/收藏之间的收藏与发送状态一致，但不越过各自权限。
- 抽取同时将受影响旧调用方改为委托并移除被替代的活跃实现，不能留下“shared”和旧副本并行演化。历史迁移保留原样，不按文本重复数量误判；审查当前生效函数和调用关系。
- 验收并入原A01-A48/P01-P03，不新建通用复用扫描器、不全量拆分旧大Store、不迁移未受影响页面。仅名称相似、权限或语义不同的代码允许独立；DRY不优先于隐私、事务和清晰职责。

### 7.4 不变约束

- SwiftUI -> Store/flow state -> Repository -> 受控 RPC；不新增依赖、独立服务或通用任务框架。
- 一份 Request、多入口、多报价、至多一个 Booking；邀请/收藏/浏览不占时段、不代表成交。
- 不隐式扩大需求条件，不把收藏、滑动、未回复写入专业评分或长期偏好。
- 全部合法候选可分页发现，不以排名阈值、缓存容量或加载速度截断全集。
- 保留现有请求额度、幂等、terms revision、RLS、资源/容量/缓冲/DST、评价和隐私边界。
- 仅本地 Simulator 客户端验收；真机、签名、上架、APNs 部署和真人推荐质量评审不作为完成门槛。
- 实施开始与远程 DDL/夹具/恢复需本计划明确授权；文档任务不执行，不继承旧任务授权。
- 保留已有用户改动；整个采用目标验收完成后才按工作分支授权提交/推送，不自动合并或创建 PR。

## 8. 自检结论与待审阅默认值

已在本文消除：预览提前公开、双入口复制订单、池关闭误废报价、邀请到期误废报价、收藏当资格、滑动当负反馈、完整列表漏前8位、旧API越权、原始地址列泄漏、过期预览导致重复发布、到期请求无恢复入口。

交叉自检进一步收紧：首次发布保留短期浏览scope别名和稳定推荐键；完整发布digest包含备注与替换身份；收藏采用keyset/revision且取消状态保留有界tombstone；扩展容量测量不成为新增Auth账号或工具平台的隐形前置。上述修订已同步实施接口与验收矩阵。

T-398复用复核补齐：发布恢复单一所有者、首次回执不双写两份账本、公开资料窄投影、旧新资格/评分包装器委托同一内核、发现与交易权限不混用。原工作包和产品验收范围不变；这些是待实施约束，不表示代码已完成抽取。

需用户审阅但不妨碍文档完成的默认值是：8位推荐、池默认关、5位未结束定向邀请、24h邀请期限、30min私有预览，以及末尾尾页按钮。实现前若调整这些值，直接改对应契约和验收，不另造并行方案。本文没有声称上述参数最优、功能已上线或成交率已提升。
