# 上游同步审查 — 2026-10-06 冻结并合并(处置 accept,双原则)

<!-- policy-markers: whole-diff-classification; merge-base-incoming-range; repository-audit-required; semantic-change-ledger; fork-feature-impact; disposition-required; bug-provenance-required -->

- 上游远端:`https://github.com/liuchuancong/pure_live.git`(既有 `upstream`)
- 上游完整 SHA:`e1b5055bd004…`(冻结于 fetch,证据 `local-artifacts/upstream-reviews/upstream-e1b5055bd004.json`)
- 审查基线(fork HEAD):`f79a88ea23a1d38abef579e6a463596ff8256c36`(迭代41 租约FLV对齐上游)
- merge base:`b087ee901eb35b568ec91bcedd2c259428f4c6f3`(上轮合并点,docs/UPSTREAM_AUDIT_b087ee90.md)
- 入站范围:`b087ee90..e1b5055bd` = **108 提交 / 350 文件(+14172/−3181;新增 80·删除 3·修改 267)**
- 门禁脚本实测(`tool/review_upstream_update.ps1`):`violations=[]`(无凭据/可变引用/pull_request_target/write-all 形态;**.github/ 与 assets/version.json 零入站**,工作流与版本不变量天然安全)。`diff_check_passed=false` 系入站 diff 自带尾随空格——与上两轮(b087ee90/276fae8a)同性质的上游自身卫生问题,按先例放行并记录。脚本 JSON commits 只含 62 条(PowerShell 管道丢行,先例已知);本审计以 `git log b087ee90..upstream/master` 全量 108 条为准(为其超集)
- 试合并实测(`git merge --no-commit --no-ff` 后 abort):**51 个未合并文件**(UU 为主);自动合并成功面 299
- 结论:**本轮合并**(处置 accept);冲突按双原则解决——解析/协议层跟上游(purelive,含 17 站弹幕引擎整体换代),UI 以 fork zishu 为准;版本/releases.json/更新源/firebase 删除边界保持 fork 不变量

## file_review / whole-diff-classification

全部 350 文件清单 = `git diff --name-status b087ee90..upstream/master`(机器证据 JSON 同源);全部 108 提交清单 = `git log --oneline b087ee90..upstream/master`。主题归类:

| 主题 | 代表提交 | 文件面 | 类别 |
|---|---|---|---|
| **17 站聊天引擎移植(M5.x)**:acfun(访客会话+protobuf 读写器+帧编解码)/baidulive(轮询)/bigo/chzzk/fc2live/jdlive/kilakila/kugoulive/looklive(socket.io 0.9)/missevan/pandalive/picarto/seventeenlive/showroom/sixroom/steambroadcast/twitcasting,含矩阵探针修复 | fb8e2179b/2541b88ed/7c2d9e2ba/1990e1243/fabe51c1e/d19148937/521812ae3/b58eb0a17/a46b2e502/2958e35a5/1fc235baf/47f7600c5/25d2000be/d1590cbbc/c3a9d9bd2/ba7c5d0bb/2fdc1d613/4c5483159/e89c0c6fb/0da5eb77b/bd42596ad | shared/platforms 17 站 api+danmaku+site | 语义变更(引擎换代) |
| **取流/播放内核波**:LiveStreamFacts 线路容器声明(ts/fmp4/udpxy)、B站/IPTV 容器声明、FFmpeg 转封装+清单改写接线、token 平台走 ingest 回环、legacy HEVC FLV 改 FFmpeg 重封装(不在 Dart 改 FLV 标签)、清单子行会话 Cookie 保留、mpv 属性单一归属、直播清单不可 seek、demuxer/代理按源、代理信任证书+fc2live/showroom API 直连、过期签名 URL 换新而非重试、owned-input 修 recipe/source 两缺陷、音频纯听、封面占位视频轨/耳机切换保画、声明图片尺寸跨层 | c17d9316a/85e5e0051/c7298755f/49b6fa53f/b749c3f3e/86dde8f16/c5ada971d/e03f4d98a/a9140e7da/8f55b49c6/e2fe28aab/ce44ab6c7/27334f412/784b00da3/e05675c5c/c920cc77c/15cec5bbf/559690d48/5a212628c/102b84523/df893309d/73aeb5931(7站房间声明媒体头)/960bcf7e3(weibo) | core/player + domains/live/data/stream(4 新文件)+ 多站 api | 语义变更+新增源 |
| **小窗/画中画波**:小窗弹幕 facade 自持池(3 连修)、四周自由缩放+横竖屏几何记忆、内核浮动呈现器接线、移动端 PiP 拖不动/黑边/圆角/控件修复、FloatWindowGeometry 测试 | 6fabc7d0d/b19a68642/e1b5055bd/14a49c371/cb6d72901/07aa2a245/602499790 | core/player/kernel+presentation+浮窗 | 功能+修复 |
| **录制域**:本地视频播放器+私有目录警示(3 连修 Get.back 误弹)、输入中继按 LiveStreamFacts 声明驱动 | 0b23c32fa/81ba87158/015ff3b4e/3adf25585/f59fe9142 | domains/recorder | 功能+修复 |
| **账号域**:统一登出入口、斗鱼登出落整会话、Cookie 面审计 | b8f5c5873/bbb23e521/8fad12056 | domains/account+core/config | 功能+修复 |
| **站点修复波**:bigo 指纹升级/账号 Cookie 设置/passRoom=null+http 头像(=fork 迭代36 同题)/login-walled 口径;xhs 分享链接抽取(/o/ 短链);steam CDN IP 亲和→回环中继直连×2;sixroom 弹幕服务器列表按文本读;missevan Set-Cookie 全列表取会话;fc2 中继带 l_ortkn;kugoulive 语音房封面背景;huya 通知留言板面板(C-9);niconico/youtube 身份翻转(房间即主播/频道即房间);baidulive 轮询引擎+80ms 门限复盘;jdlive 2s 卡顿归因;超时不属于"房间读不出"错误口径 | 2e84d68d3/3a960050b/91e2c75b3/21e981da5/6229284a8/321f184a9/6c29c7047/462f9b45c/ee6bf4c9a/14d965326/01fd4fec5/506186241/c873e005c/fd530a918/eda8b4bde/fcc57f56c/6974e8105 | shared/platforms 各站 | 语义变更 |
| **依赖**:flame_barrage 转**托管源 ^0.0.9**(撤回功能已发布,fork 可撤 F:/flame_barrage 本地克隆适配);media_core 新增 list_playback/feed 路径依赖(F:/media_core 本地已备齐) | 7bb5afc70/0b23c32fa | pubspec.yaml/lock | 依赖源(政策关注项) |
| **全仓去中文注释**(af884cbf9)与杂项:manifest 注释清理、托盘热重启孤儿图标、i18n 缺键渲染自身名、tray/代理设置整理 | af884cbf9/2367e7067/0a299dd00/958f72156/602499790 | 全 lib(触碰面大,均为注释/非语义) | 注释清理 |

## semantic_change_ledger(逐主题)

| commit/file | upstream intent | issue_and_bug_mapping | implementation | quality_assessment | fork_feature_impact | disposition | regression_plan |
|---|---|---|---|---|---|---|---|
| 17 站引擎(上表第一行) | 聊天引擎全站到齐(其 M5 台账) | 上游内部 4.x 同步;fork 无外部 Issue | 各站 api 取票据/服务器地址 → LiveDanmaku 子类(extends 基类复用连接态);矩阵探针验收 | 上游矩阵探针自带;与 fork 契约同形(LiveDanmaku 抽象类两侧一致,桥经 `site.getDanmaku()` 泛化消费,引擎替换对桥透明) | **fork 已验收的 9+2 家引擎被上游版本换代**(解析/协议层跟上游双原则;showroom 实测两套实现差异 246 行=独立实现非同源);baidulive/jdlive/kugoulive/looklive/sixroom/steambroadcast 为纯增量 | **accept(上游为底)**;fork 引擎退出,验收改由上游矩阵探针在 fork 网络复跑背书 | danmaku_connection_matrix_probe(合并后真网络复跑)+ 全量单测 |
| LiveStreamFacts/容器声明/FFmpeg 转封装(c17d9316a/85e5e0051/c7298755f/b749c3f3e/49b6fa53f) | 取流按线路**声明的事实**决定直连/转封装,legacy HEVC FLV 出 Dart 层 | 上游内部演进 | live_stream_ingest.dart+ingest_source_interceptor+playback_ingest_needs+playback_manifest_probe(4 新文件);recorder 输入中继改由 LiveStreamFacts 驱动 | 上游自洽;与 fork 迭代40(zishu 侧 media_core_ingest 接线)是**平行实现**:上游收拢内核链,fork zishu 链自用——两者编译共存不冲突 | zishu 播放链零波及(flv_splice_relay.dart 本轮**未被上游改动**,迭代41 接口稳定);未来 zishu 切上游 ingest 管线**另立项** | **accept**;统一接线 defer(记录恢复条件:上游管线覆盖 FLV 续签时撤迭代39 排期器,见迭代40 台账) | 编译级+全量测试;录制域受影响测试 |
| 过期签名 URL 换新(784b00da3)/owned-input 修 recipe(e05675c5c+c920cc77c) | 恢复链不得重开刚死的签名地址;owned 输入误传 source 致 FC2/bigo/niconico 打不开 | 上游自修(提交自述) | facade 接通 26 站 LivePlayRecoveryResolver;playOwned/playSource 改收 OwnedPlaybackSource+customInputMetadataOf 单一产地 | 均作用于 fork 运行时绕过的旧 UI/内核链 | 编译单元级;zishu 等价能力已在迭代39/41 落地(lease relay+_recoverLines),语义不冲突;**live_input_playback_binder 冲突取上游后须核 fork play_provider 调用签名** | **accept**(binder 冲突=注释清理+恢复绑定,fork 侧无新语义) | analyze+owned_input_playback_binder_test+ingest_relay_glue_test |
| 7 站房间声明媒体头(73aeb5931)+weibo 头(960bcf7e3) | 建连后无数据的站点靠房间级头修复 | 上游自修 | LiveRoom 声明头→取流侧带上 | 契约增强;fork 桥(purelive_backend)按 StreamLine.headers 透传,房间级头若进 LiveRoom 需桥核对 | zishu 代理/中继的 header 注入链已有(line.headers);房间级新头字段桥暂不消费=无回归,后续可接 | **accept**(桥消费 defer) | 编译级;海外站播放探针 |
| 小窗/画中画/录制/账号波 | 详见主题表 | 上游自修/功能 | 旧 UI/内核/录制域 | 自洽 | fork 运行时绕过旧 UI;录制域与 zishu 有共享(core 侧)但本轮改动在 domains/presentation | **accept** | 编译级+全量测试 |
| bigo 修复波(91e2c75b3/2e84d68d3/3a960050b/21e981da5) | 匿名收紧后保播放/详情 | fork 迭代36 已修 passRoom/roomType/avatar 同题(bugfix 独立成立) | 上游同向修复+指纹/Cookie/口径增强 | 上游版本与 fork 补丁**同题不同码**;取上游后 fork 补丁退役 | bigo_api 冲突解决时逐 hunk 对比,确保上游版覆盖 fork 三点(null/int/http)则直接采用 | **accept(对比核验)** | bigo 详情/播放探针 |
| 身份翻转(niconico c873e005c/youtube fd530a918) | 房间即主播/频道即房间(上游 4.x) | 上游功能 | api 层 roomIdOf/频道化 | 解析层语义变化 | fork 直达识别已统一切上游 WebSearchRoomParser,自动跟随;两站为 fork 小众面 | **accept** | 直达矩阵探针(后续) |
| flame_barrage ^0.0.9 托管(7bb5afc70) | 撤回功能已发布 | — | pubspec 托管源 | fork 上轮适配(F:/flame_barrage 自补 retractWhere)可退役 | 若 0.0.9 缺 retractWhere 则回落本地路径(恢复条件) | **accept**(pub get+编译核验) | 全量测试(弹幕撤回用例) |
| 全仓去中文注释(af884cbf9) | 只留代码说不出的话 | — | 注释删除 | 触碰面大但非语义 | 与 fork 注释风格分歧:上游文件随上游;**fork 语义补丁行保留 fork 注释** | **accept**(冲突按语义侧取) | 编译级 |
| releases.json/AndroidManifest/firebase_email_auth/user_item(冲突) | 上游 CI 产物/注释清理/注释清理 | — | — | — | releases.json=**fork 值**(9858ddc6 更新);manifest=fork 已含 predictive-back+等价内容,上游仅删注释;firebase 两文件 fork 已删**不得复活**(AGENTS 口径) | **keep-fork / keep-deleted** | 确认合并树无 firebase 依赖与版本回退 |

## issue_and_bug_mapping

上游本波无对外 Issue 映射(其提交自述+M5/4.x 台账内部同步);fork 侧关联:①bigo passRoom/avatar 与 fork 迭代36 同根因(独立修复,合并后取上游版,fork 补丁退役);②过期签名 URL 与 fork 迭代39/41 同类能力(分属两条播放链,互不冲突);③上游自带 docs/ledger(7dc74dd14/59224e02f/57597ed28/eda8b4bde/fcc57f56c/438bfc7f6/da60297a8/38ef726b5/f01ef124a)随合并入库作语义索引。

## fork_feature_impact

- **zishu 播放链(迭代40/41)零波及**:flv_splice_relay.dart/playback_input_lease 核心未动;binder 冲突为注释级,取上游后核 `bindLiveInputForPlayback(recipe).createInput(CancelToken())` 签名。
- **弹幕引擎换代**:fork 9+2 家引擎→上游 17 家;桥/overlay 泛化消费不受影响;弹幕连接矩阵探针换上游版(bd42596ad 修复编译),真网络复跑背书。
- **fork 语义补丁保留面**(合并时逐一回植):acfun_site 外链死链修复(56b584b1d)、chzzk 目录/missevan catalogs/soop Accept-Language(合并33 回植,本轮仅 chzzk/missevan 弹幕路径冲突,site 文件大多自动合并已保留)、bigo liveStatus 对比核验。
- **不变量**:pubspec version 保持 fork 3.1.19+4108;firebase 保持删除;releases.json/更新源(github_mirror)保持 fork;.github 零入站。

## conflict_resolution(51 文件处置)

| 组 | 文件 | 处置 |
|---|---|---|
| 弹幕引擎/站点三件套 | shared/platforms 35 文件 | 取上游(引擎换代);acfun_site=上游版+回植外链修复;bigo_api=逐 hunk 对比后取上游;bigo_site=上游版+核 liveStatus |
| 注释级冲突(fork 侧仅合并33) | core/consts app_consts、core/index、fake_user_agent、hive_pref_util、tars get_cdn_token_ex_req、list_util、iptv 2、recorder 5、cookie_settings_controller、live_play_controller、record models | 取上游(注释清理+功能) |
| github_mirror(更新源) | core/release/github_mirror.dart | **取 fork**(发布镜像不变量;上游仅注释) |
| firebase(UD) | firebase_email_auth.dart、user_item.dart | **保持删除**(git rm) |
| 版本/资产 | releases.json | **取 fork** |
| 平台原生 | AndroidManifest.xml | **取 fork**(上游仅注释清理,fork 已含等价内容+predictive-back) |
| 契约 | live_input_playback_binder.dart、live_room.dart、live_site.dart | 取上游+桥编译核验 |
| 依赖 | pubspec.yaml 手工合并(fork 版本+zishu 宿主依赖+上游 flame_barrage^0.0.9/media_core 三包);pubspec.lock 由 pub get 再生 | 手工 |
| 探针 | danmaku_connection_matrix_probe_test.dart | 取上游(bd42596ad 修复版) |

## regression_plan / verification_plan

1. `flutter pub get`(flame_barrage 托管源可用性第一道验证,失败则回落 F:/flame_barrage 并记录)。
2. `flutter analyze`(基线:仅 integration_test 存量错误+已知存量 info;新入站问题逐一归类)。
3. 全量单测 `flutter test test/`(含弹幕协议/owned-input/ingest 胶水/settings maybe)。
4. `python tool/audit_repository.py` + `py -3.12 tool/validate_architecture.py --strict`(合并33 先例口径)。
5. `git diff --check`(上游尾随空白按两轮先例放行,fork 侧新改文件不得新增)。
6. 弹幕连接矩阵探针真网络复跑(上游版探针;映客/酷狗等端点级封锁≠平台级封锁口径见台账,失败按证据记录不阻断)。
7. 合并提交推送 origin 后核验远端 head;真机播放验收留待用户下次会话(douyu 租约/斗鱼弹幕优先)。
