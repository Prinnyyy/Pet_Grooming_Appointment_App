# Beckon Launch Video Implementation Plan

<!-- task-artifact
task: T-393
status: completed
type: plan
-->

> **Execution record:** T-393 first-version production is complete. The original detailed checklist below is retained as the adopted plan; actual evidence and deviations are summarized here and in the project README. No subagents were used.

**Goal:** 使用真实 iOS 模拟器素材制作一支 60 秒、中文文字递进、无旁白的 Beckon 产品介绍片，并交付可编辑工程。

**Architecture:** 将模拟器素材采集和视频编排分开。Hyperframes 工程只处理真实截图/录屏、介绍文字与动画，时间轴由八个独立场景组成。首先渲染 10 秒样片验证完整链路，再完成 60 秒影片。

**Tech Stack:** XcodeBuildMCP、Apple Simulator / simctl、Node26.3.0、Hyperframes0.8.41、GSAP3.14.2、Chrome152.0.7977.30、FFmpeg / ffprobe8.1.2，依赖已锁定。

**Spec:** [Beckon 60 秒介绍视频设计稿](../specs/2026-09-15-beckon-launch-video-design.md)。

**阶段：**用户于2026-09-15启动执行并授权必要依赖、隔离测试账号及演示数据写入/恢复，另授权缺失宠物图片生成。首版制作与技术验收已完成；用户审美反馈尚未发生。T-392继续其独立验收，不作为本片完成证明。

## Completion Evidence

- 成片：`video/beckon-launch-60s/renders/beckon-launch-60s-v2.mp4`，60.000秒、1800帧、1920x1080、30fps、H.264/yuv420p/Rec.709、faststart、无音频；完整解码PASS。SHA256 `733ca99bc650b71e63ac7f0797e09de0b4fec36efd1b7379e6d4530459e8c781`。
- 样片：`renders/beckon-sample-10s-v2.mp4`，10.000秒、300帧。先验证样片再完成整片；旧版VFR截段问题已修正，首份中间文件保留。
- HTML运行/布局检查无错误，21/21对比度检查通过；27份素材校验值、8幕时间轴和本地引用检查PASS。检查21处代表帧、7个边界前后各2帧、390px主字幕及960x540报价画面。
- 最终MP4在QuickTime正常速度从0播放到60秒，观察到0.39/53.57/60秒进度及结束状态。完整播放器文件与可编辑工程已准备交付；浏览器直连大文件一次持续缓冲未计为通过。
- 真实素材来自独占Simulator；S04用同需求的独立请求补拍未提交报价表单，S07明确标记另一笔历史已完成服务。无App拍摄专用逻辑、伪造成功、时钟修改或安全规则变更。
- 精确恢复PASS：14张表业务基线一致，合法更新时间/eligibility revision不回拨；本次4请求、2预约、1评价、2会话、1宠物及Storage图片、2服务已删除，原排班/偏好/3地址时区恢复；私有派生残留及队列全0。
- 制作说明与重渲染命令见[工程README](../../../video/beckon-launch-60s/README.md)。详细本地证据在`qa/review.md`、`qa/*-technical.json`、`capture/manifest.json`、`fixtures/recovery.json`，不提交私有数据。

**实际调整：**样片入口位于`compositions/sample.html`以避免多根合成；最终文件v2是内部质检修订后的首个交付版本。报价大特写放在完整片中；原生不可逆操作不为补足原片尾余量重复提交，确认结果以真实稳定截图补足3秒停留。生成图片只用于真实Coco档案。初始4帧白色是开场淡入，片中没有空白帧。三条lint警告分别为两个明确采用局部时间的视频及五步字幕同轨，17处信息级重叠仅处于0.3秒交叉淡化。未启用自动motion检查，动画通过播放与抽帧核对。

## Global Constraints

- 成片：60.000 秒，1920 × 1080，16:9，30fps，共 1800 帧，H.264 MP4、yuv420p、faststart。
- 声音：首版静音，无旁白、配乐和音效；理解信息不依赖音频。增加音乐另作为后续剪辑选择。
- 文字：中文介绍文案，App 保留当前英文界面，不为拍片修改 App 文案。
- 素材：iOS 模拟器中的真实 App 截图和录屏；手机外框、介绍文字、触点和镜头动画在视频工程中制作。
- 发布保留五步真实流程；报价接受保留确认页；评价来自已完成服务。
- 执行权限只沿用本视频任务已获得的范围，不借用其他测试任务的账号/数据写入授权。
- 新依赖与需要的远端写入在执行前核对授权；本规划不执行安装、登录、数据注入、发布或上传。
- 维持当前 App 源码、产品规则、签名与构建配置；视频工程不向 App 添加模拟成功或拍片专用运行模式。

---

## 文件职责

以下为原定工程职责；现已建成。实际样片入口和交付文件名以上方完成记录为准。原始素材与私有演示资料留在本地，不自动提交或上传。

```text
video/beckon-launch-60s/
  README.md                    运行、重录、导出与交付说明
  DESIGN.md                    复制设计稿中已确定的视觉规则，补充实际字体与色彩配置
  package.json                 本工程依赖与命令
  package-lock.json            依赖版本锁
  .gitignore                   node_modules/assets/renders/qa/capture/fixtures 的本地输出排除
  index.html                   60 秒主时间轴
  sample.html                  10 秒样片入口，复用相同素材和样式
  styles.css                   固定画布、字体、颜色、安全区与手机构图
  timeline.json                八幕的帧区间与素材 ID
  compositions/
    01-brand.html
    02-pet.html
    03-request.html
    04-groomer.html
    05-offers.html
    06-confirm.html
    07-followup.html
    08-outro.html
  capture/manifest.json        本地素材来源、片段区间、裁切、角色和操作事件
  capture/runbook.md           模拟器选择、账号用途、预演和重录顺序
  fixtures/plan.md             仅在数据不足时编写的具体演示数据范围与恢复计划
  assets/raw/                 原始视频，保留文件与输入色彩信息
  assets/stills/              原始分辨率 PNG 截图
  renders/                    样片和正式 MP4
  qa/environment.txt          实际工具与字体版本
  qa/review.md                渲染检查、素材完整性与最终观看记录
  qa/frames/                 代表帧及转场边界截图
```

目录只建立单一制作工程，不拆分多个依赖包，不新增通用视频框架。相同字体、颜色和手机边框只在共享样式中定义一次。

## Task 1: 固定环境与拍摄范围

**Files:** 创建工程中的 `README.md`、`DESIGN.md`、`package.json`、`package-lock.json`、`.gitignore`、`capture/runbook.md`、`qa/environment.txt`。仅在资料不足时创建 `fixtures/plan.md`。

**输入：**设计稿、当前任务状态、现有模拟器与依赖检查结果。

**输出：**具备锁定依赖的独立制作目录；可用的拍摄设备/数据范围；无竞争的录制窗口。

- [ ] 阅读当前 Git 差异与 Current State，识别仍被占用的模拟器和账号。将本计划纳入当前明确采用的制作任务；如仍有其他任务运行，协调资源，避免改写其活动状态来假装已暂停。
- [ ] 对当前视频任务的依赖安装和数据写入授权做一次具体核对。缺失时先列明要安装的 Hyperframes 依赖、演示账号及数据范围，取得必要授权后再执行相应步骤；没有数据写入需要时不申请该权限。
- [ ] 调用 `session_show_defaults` 和 `list_sims`，选择一个未被现有任务占用的兼容 iPhone。需要两端并行采集时才使用第二个模拟器；不对整个模拟器集合执行重置或停止。
- [ ] 沿用现有 Beckon 项目与 scheme，设置当前会话 defaults；只有需要更新安装包时才串行 build/run。实际设备 ID 从工具结果取得，不把试录设备 ID 固化进脚本。
- [ ] 使用 `node --version`、`ffmpeg -version`、`ffprobe -version` 记录实际版本。检查字体解析，明确 PingFang SC 可用；记录 Chrome 版本。
- [ ] 获得依赖授权后，在仓库根目录按 CLI 当前帮助初始化：

```bash
npx hyperframes init video/beckon-launch-60s --example blank --resolution landscape --non-interactive --skip-transcribe
```

- [ ] 初始化后记录实际 Hyperframes 版本，将所用依赖设为明确版本并保留锁文件。此后从工程目录运行锁定的本地 CLI，避免每次执行重新获取最新版本。初始化所写文件必须处于该工程范围，检查新增技能或配置是否落到工程以外。
- [ ] 从设计稿写入 `DESIGN.md` 后才开始 HTML 编排。声明本片使用纯白舞台、无背景装饰、双角色色和系统字体，避免模板默认样式覆盖品牌方向。
- [ ] 运行本地 `hyperframes doctor` 及 `--help`；确认字体、浏览器、FFmpeg、`lint`、布局检查、预览和渲染命令的实际名称。新版本用 `check` 时不盲目照搬旧版 `inspect` 参数。

**验收：**设备和账号用途明确；App 可运行；制作环境健康检查通过；版本已锁定。技术准备通过不等于场景数据已齐备。

## Task 2: 预演并采集真实素材

**Files:** 创建 `assets/raw/`、`assets/stills/`、`capture/manifest.json`，更新 `capture/runbook.md`。数据不足时补充 `fixtures/plan.md`，不改 App 代码。

**输入：**A01-A08 素材需求与已确认的设备、演示账号及数据范围。

**输出：**带来源的原始素材、可重复的操作清单、对应镜头的精确裁切/起止区间。

- [ ] 清点现有演示状态：一只宠物、一份请求、至少两份有效报价、一次真实接受、预约后对话、合法已完成服务及评价。两端人物/价格/时间与服务模式对应一致。
- [ ] 若状态不足，先把所需账号、记录、图片来源、恢复方法列入 `fixtures/plan.md`。账号隔离和设备隔离分别确认；不得直接复用另一测试任务尚待恢复的资料，也不借此次拍片解决其恢复阻塞。
- [ ] 正式采集前预演导航及可逆表单操作。发布、提交报价、接受和评价为状态变化，预演仅到确认前；正式执行时录一次成功，后续重录结果页面，不以重复提交来重拍。
- [ ] 使用 `snapshot_ui` 确认当前控件后再操作；刷新页面、滚动或弹窗后重新获取元素引用。等待实际界面稳定再拍摄。
- [ ] 全分辨率截图用于成片。XcodeBuildMCP 在试录中返回过 368 × 800 优化预览，不能把它当作原始制作素材。优先原生 PNG 或从原生视频提取高分辨率帧。
- [ ] 使用运行时得到的模拟器 ID 和素材路径执行原生采集，以下环境变量在该次录制前由实际值设置：

```bash
xcrun simctl io "$BECKON_VIDEO_SIM_ID" screenshot "$BECKON_VIDEO_STILL_PATH"
xcrun simctl io "$BECKON_VIDEO_SIM_ID" recordVideo --codec=h264 "$BECKON_VIDEO_RAW_PATH"
```

录制由受控会话开始，完成后向该会话发送中断并等待文件写完。不能只杀整个 Simulator。必要的沙箱访问按平台权限流程处理，不将访问失败误诊为 App 故障。

- [ ] 每条素材保留动作前后至少 1 秒余量；关键确认和成功状态保留至少 3 秒。键盘、网络等待在后期裁剪，原始文件完整保留。
- [ ] 按 A01-A08 采集；A05 保留真实确认页，A07 保留完成状态和评价条件。结束前确认没有遗留录制进程。
- [ ] 对每条原始视频使用以下命令记录帧率、时长、像素及色彩信息：

```bash
ffprobe -v error -show_entries format=duration:stream=codec_name,width,height,avg_frame_rate,r_frame_rate,nb_frames,pix_fmt,color_space,color_transfer,color_primaries -of json "$BECKON_VIDEO_RAW_PATH"
```

- [ ] `capture/manifest.json` 每条素材至少包含：`assetId`、`path`、`sha256`、`role`、`simulatorId`、`buildRef`、`captureMode`、`sourceWidth`、`sourceHeight`、`durationSeconds`、`sceneIds`、`sourceInSeconds`、`sourceOutSeconds`、`cropRect`、`events`。`captureMode` 使用 `runtime`；`cropRect` 为原始像素的 x/y/width/height；事件记相对素材时间、操作目标及实际结果。
- [ ] 请求、报价、预约与对话的内部对应关系仅存在本地清单，不包含密码、令牌。日期/姓名等演示文本已在界面中真实存在，不能在剪辑层覆盖成另一条业务记录。

**验收：**八幕均有可用素材；采集文件可解码；主要动态操作无明显卡顿。静态页面的可变帧率和 `r_frame_rate=600/1` 不能直接当作动画流畅度结论，需检查动态片段的时间戳和实际播放。

## Task 3: 制作并验证 10 秒样片

**Files:** 创建 `styles.css`、`sample.html`、`compositions/05-offers.html`、`compositions/06-confirm.html`，输出 `renders/beckon-sample-10s.mp4`、`qa/frames/`，更新 `qa/review.md`。

**输入：**A04/A05 原生素材、DESIGN.md、样片时间表。

**输出：**300 帧样片及内部视觉验收结果，作为整片复用的视觉基础。

- [ ] 先做静态关键帧：报价全景、价格/时间特写、确认页、预约已确认。检查安全区、手机比例、字体和原生画面裁切，再加入动画。
- [ ] 样片按 0-2s / 2-4s / 4-7s / 7-10s 四段组织。使用真实记录完成确认，触点跟随素材；不把时间不足的过程伪装成一次点击。
- [ ] HTML 使用固定 1920 × 1080 画布、10 秒根合成；按 Hyperframes 规范注册暂停的 GSAP 时间轴。样片中的视频保持 muted/playsinline，不自行用计时器控制视频播放。
- [ ] 主标题使用设计稿实际文案；长句显式换行。每个素材层分别承担场景可见性和几何动画，避免同一元素的同一属性被两个时间轴写入。
- [ ] 从制作目录运行本地 CLI 的 lint、布局检查和预览。对 1.5、3.5、5.5、8.5 秒及转场边界取帧，修复文字越界、遮挡和黑帧。
- [ ] 渲染样片，当前 CLI 参数若有差异以实际帮助为准：

```bash
npx hyperframes render --composition sample.html --output renders/beckon-sample-10s.mp4 --fps 30 --quality high
```

- [ ] 检查真实动态录屏、文字、裁切和颜色；在正常尺寸与 960 × 540 播放观察，另以 390px 宽小窗检查主字幕。原始帧与导出帧并排比对，确认图像没有拉伸或重复刘海。
- [ ] 样片必须包含 300 帧，7-10s 的已确认结果稳定完整。对不满足的项就地调整一次相关参数，再复核受影响区间，避免反复重跑无变化检查。
- [ ] 提供可播放样片与代表帧供用户查看。这个节点用于风格反馈，不要求用户亲自录屏、操作剪辑软件或逐个批准镜头。

**验收：**完整 HTML -> MP4 流程已实测；字体/色彩/动态表现通过；无素材真实性缺口。失败时记录具体问题，先修复该路径，不默认把已经可用的素材采集也推倒重来。

## Task 4: 完成 60 秒时间轴

**Files:** 创建 `index.html`、`timeline.json` 及剩余六个场景，复用样片场景和 `styles.css`，输出 `renders/beckon-launch-60s-v1.mp4`。

**输入：**通过样片检查的视觉与渲染方式、A01-A08、设计稿八幕脚本。

**输出：**1800 帧完整影片及可单独调整的场景文件。

- [ ] 写入明确时间表，不由多个手写总时长互相推断：

```json
{
  "fps": 30,
  "width": 1920,
  "height": 1080,
  "totalFrames": 1800,
  "scenes": [
    {"id":"S01","startFrame":0,"endFrame":120,"assets":["A01","A08"]},
    {"id":"S02","startFrame":120,"endFrame":270,"assets":["A01"]},
    {"id":"S03","startFrame":270,"endFrame":600,"assets":["A02"]},
    {"id":"S04","startFrame":600,"endFrame":810,"assets":["A03"]},
    {"id":"S05","startFrame":810,"endFrame":1170,"assets":["A04"]},
    {"id":"S06","startFrame":1170,"endFrame":1410,"assets":["A05"]},
    {"id":"S07","startFrame":1410,"endFrame":1650,"assets":["A06","A07"]},
    {"id":"S08","startFrame":1650,"endFrame":1800,"assets":["A05","A08"]}
  ]
}
```

- [ ] 根 HTML 以 `startFrame / 30` 和 `(endFrame - startFrame) / 30` 设置片段起止，根时长 60 秒；逐项核对 JSON 与 HTML 属性一致。不同轨道允许有意叠加，同一轨道不得意外重叠。
- [ ] 按设计稿完成 S01/S02/S03/S04/S07/S08：发布五步、角色文字角标、服务完成后的字幕和最后 3 秒定格均须落实。
- [ ] 将样片报价/确认场景按正式片的 12 秒/8 秒展开，重新保证阅读时间，不直接把 10 秒样片整体拉伸。
- [ ] 录屏与真实截图可交替使用；跨帧静止需是主动安排的阅读停顿。切换角色以同一需求承接，价格/预约号等数据关系由清单校验。
- [ ] 所有场景静态画面通过布局检查后，检查 4/9/20/27/39/47/55 秒边界前后各 2 帧，确保入场退场无空白、重复字幕或突然裁切。
- [ ] 运行 lint、当前 CLI 布局检查，然后渲染：

```bash
npx hyperframes render --composition index.html --output renders/beckon-launch-60s-v1.mp4 --fps 30 --quality high
```

**验收：**完整时间轴覆盖 0-60 秒；文案与设计稿一致；真实功能闭环可理解；关键镜头不因转场丢失必要确认。

## Task 5: 成片检查与交付

**Files:** 更新 `README.md`、`qa/review.md`；输出最终视频、代表帧和本地工程交付目录。

**输入：**完整成片、时间轴、素材清单。

**输出：**技术与视觉验证通过的 MP4，以及可再次渲染的工程。

- [ ] 使用 ffprobe 验证成片参数，并完整解码：

```bash
ffprobe -v error -show_entries format=duration:stream=codec_type,codec_name,width,height,avg_frame_rate,nb_frames,pix_fmt,color_space,color_transfer,color_primaries -of json renders/beckon-launch-60s-v1.mp4
ffmpeg -v error -i renders/beckon-launch-60s-v1.mp4 -f null -
```

- [ ] 核对视频流 H.264、1920 × 1080、30/1、1800 帧、yuv420p，时长与 60 秒差异不超过一帧，无音频流。若容器不报告帧数，再用 `ffprobe -count_frames` 实际计数，不猜测通过。
- [ ] 检查 faststart 和输出色彩标记；确需容器调整时保留首份渲染文件并输出新的最终文件，不通过重贴色彩标签来代替正确颜色转换。
- [ ] 顺序观看最终成片，确认无意外空白帧、文字重叠、拉伸、停顿失误或业务状态跳跃。导出代表帧包括全部场景中段和每个转场两侧；播放验证不能仅由抽帧代替。
- [ ] 以 390px 宽小窗复核主字幕，以横屏视图复核强调的价格、时间和确认状态；任何核心信息看不清都回到对应场景改构图。
- [ ] 记录源素材校验值、实际渲染版本/命令、已检查时间点与残余限制。区分技术验证和用户审美反馈，不声称用户已经接受未查看的样片。
- [ ] 若本任务有获准的远端演示数据操作，按该范围完成精确恢复并记录结果；不删除其他任务数据，也不将其恢复问题列为本视频已解决。
- [ ] 在 Codex 中打开可播放成片，并提供本地 MP4 与工程路径。首版不自动上传 Google Drive、发布到社交平台或创建 App Store 素材。
- [ ] 只有整个制作目标已验收，才按仓库的任务/Git规则处理本制作任务自己的完成状态；不提交原始素材、私有清单或其他任务的变更。

**完成定义：**用户可直接播放 60 秒影片；源工程可在已记录环境中重渲染；素材与最终画面可追溯；没有借拍片改动真实产品行为或留下本任务不明的数据变更。

## 规划自检

- 需求覆盖：一分钟、发布会观感、逐级文字、无旁白、模拟器素材、独立完成制作均有对应步骤。
- 节奏：8 幕合计 1800 帧；10 秒样片 300 帧；完整片 44-47 秒确认结果与 57-60 秒片尾分别保持 3 秒。
- 真实性：五步发布、二次报价确认、完成后评价已有代码/契约依据；未定义可用 Logo 图片，因此使用字标。
- 执行边界：此段保留规划自检的来源；制作完成证据以上方Completion Evidence为准，不扩展到上架、云盘发布或T-392验收。
- 隔离：保留当前开发任务及其测试资源；拍摄设备与演示账号分别安排，权限不跨任务借用。
