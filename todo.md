# TODO 迭代台账

> 当前焦点(2026-10-01 启动,2026-10-02 转入弹幕专项,多轮迭代):
> 第一焦点**首页房间卡的观看人数与分类展示按平台补齐**已完成(迭代1-3);
> 第二焦点**弹幕接入**(第四节清单 ❌ 未接入平台)进行中,SHOWROOM+TwitCasting+AcFun 已全链路落地(迭代4-6、10)。
> 数据链路:UI 房间卡(`lib/src/features/browse/widgets/room_card.dart` 渲染 `audience`/`category` 徽标)
> ← `RoomSummary.online/category` ← `lib/src/shared/application/purelive_backend.dart`(裸映射 `room.watching`/`room.area`)
> ← 各平台 LiveSite(`lib/core/site/*`,经 `Sites.supportSites` 全量注册覆盖)。
> 上一轮"解析字段缺口"审计(分区/推荐/搜索/弹幕/播放)保留在本文件第四节。

## 一、审计口径

- UI 首页房间卡显示两枚徽标:观看人数(`audience`)、分类(`category`),数据源头是 `LiveRoom.watching` / `LiveRoom.area`。
- **关键缺口机制**:适配器层新口径字段 `onlineViewers`/`totalViewers`/`popularity`+`audienceMetricType` 已填,但 purelive_backend 只裸读 `watching` → "数据在手、UI 不显示"(chzzk/pandalive/seventeenlive/jdlive/niconico 属此类)。
- `LiveRoom.audienceValue()` 是模型层统一取值(popularity→totalViewers→onlineViewers→legacy watching,按 metric 类型回退,'0' 哨兵不当作测量值)。
- 判定:✅ 真实值 | ⚠️ 有值但语义不符(站名/国家码/派生标签) | ❌ 空或缺失(可修) | 🚫 结构性无(平台不公开该数据,非漏填)

## 二、全平台首页字段审计表(2026-10-01,34 平台;已含迭代1/2 修复后状态)

| 平台 | 推荐观看 | 推荐分类 | 分类观看 | 分类分类 | 分类目录 | 搜索 | 弹幕 | 结论 |
|---|---|---|---|---|---|---|---|---|
| bilibili | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅ | ✅ WS | 基准组 |
| 斗鱼 | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅ | ✅ WS | 基准组 |
| 虎牙 | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅ | ✅ WS | 基准组 |
| 抖音 | ✅(或"1.2万"格式串) | ✅ | ✅ | ✅ | 真数据 | ✅ | ✅ WS | 基准组 |
| 快手 | ✅ | ✅ | ✅ | ✅ | 真数据 | ⚠️ 仅主播搜索,观看留空(上游#881,结构性) | ✅ HTTP轮询 | 无可修缺口 |
| 网易CC | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅ 迭代2:观看徽标不再显示粉丝数(接口无观看数) | ❌ | 口径已修 |
| Twitch | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅ | ✅ IRC | 推荐=just-chatting 目录 |
| SOOP | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅ | ✅ WS | 基准组 |
| YY | ✅ | ✅ 迭代2 预热 | ✅ | ✅ | 真数据 | ✅ 迭代2 预热 | ✅ WS | 已对齐 |
| AcFun | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅(结果卡无观看,结构性) | ✅ 迭代10 link-sdk WS | 弹幕已线级验证 |
| Picarto | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅(搜索无观看,结构性) | ❌ | 无缺口 |
| TwitCasting | ✅ | ✅ 迭代1 | ✅ | ✅ 迭代1 | 真实(HTML) | ✅(搜索无观看,结构性) | ✅ 迭代6 WS(pubsub) | 弹幕已全链路验收 |
| 猫耳FM | ✅(热度) | ✅ | ✅ | ✅ | 真数据 | ✅ | ❌(契约未验证) | 完整参照实现 |
| CHZZK | ✅ 迭代1 透出 | ✅ | ✅ 迭代1 透出 | ✅ | 伪目录(仅popular) | ✅(仅频道卡) | ❌ | 已修 |
| niconico | ✅ 迭代1 透出(累计观看口径) | 🚫 recent 行无分类 | ✅ 迭代1 透出 | ✅ 迭代1 | 硬编码7 tab | ✅ | ❌ | 已修 |
| SHOWROOM | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅(本地快照过滤) | ✅ 迭代4 WS(SUB/MSG) | 弹幕已全链路验收 |
| Bigo | ✅ | ⚠️ 硬编码站名(列表API无分类键) | ✅ | ⚠️ | 硬编码单 | ✅(ID+本地过滤) | ❌ | 结构性 |
| FC2 | ✅ | ✅ | ✅ | ✅ | 硬编码6官方 | ✅(快照内) | ❌ | 无缺口 |
| Steam | ✅ | ✅(游戏名) | ✅ | ✅ | 硬编码单 | ✅(单页本地) | ❌ | 无缺口 |
| 映客 | 🚫 探针:行无观看键 | ❌ 推荐行无分组名 | 🚫 | ✅ 迭代1(分组名) | 真实(精选) | ✅(本地昵称) | ❌ | 观看数结构性无 |
| KilaKila | ✅ 迭代1(watchNumber) | ❌ 接口无分类 | ✅ 迭代1 | ❌ | 硬编码2 | ✅ | ❌ | 分类结构性无 |
| LiveMe | ✅(heat) | ⚠️ 国家码(无分类树) | 🚫 无分类 | 🚫 | 无 | ✅(观看结构性空) | ❌ | 结构性 |
| 六间房 | ✅ | ✅ | ✅ | ✅ | 硬编码6 | ✅ | ❌ | 无缺口 |
| LOOK | ✅ | ⚠️ 视频/语音派生标签 | ✅ | ⚠️ | 硬编码2 | 伪搜索(本地过滤) | ❌ | 可接受 |
| 17LIVE | ✅ 迭代1 透出 | ⚠️ 仅语音房标签 | 🚫 无分类 | 🚫 | 无 | ✅(仅第1页) | ❌ | 已修 |
| 京东直播 | ✅ 迭代1 透出(pv累计口径) | ⚠️ 硬编码站名 | ✅ 迭代1 透出 | ⚠️ | 硬编码单 | 伪搜索 | ❌ | 已修 |
| 酷狗直播 | ✅ | ⚠️ 站名(列表无分类键) | ✅ | ⚠️ | 真实(HTML) | ✅ | ❌ | 结构性 |
| 百度直播 | ✅ | ✅ | ✅ | ✅ | 真实动态 | ⚠️ 仅精确房间ID(结构性) | ❌ | 无缺口 |
| 微博 | 🚫 探针:行无观看键 | 🚫 无分类 | 🚫 | 🚫 | 硬编码伪分类 | 半实现 | ❌ | 结构性 |
| 小红书 | 🚫 恒空(无公开目录) | 🚫 | 🚫 | 🚫 | 🚫 | ⚠️ 仅精确链接 | ❌ | 结构性无首页 |
| TikTok | 🚫 恒空 | 🚫 | 🚫 | 🚫 | 🚫 | ⚠️ 仅精确查找 | ❌ | 结构性无首页 |
| YouTube | 🚫 恒空 | 🚫 | 🚫 | 🚫 | 🚫 | ⚠️ 仅精确解析 | ❌ | 结构性无首页 |
| PandaTV | ✅ 迭代1 透出 | ✅ | ✅ 迭代1 透出 | ✅ | 单伪分类 | ✅ | ❌ | 已修 |
| IPTV | 🚫 裸流无统计 | ✅ groupTitle | 🚫 | ✅ | 真实(本地DB) | ✅ 本地 | ❌ | 观看结构性 |

统计:迭代1+2 共落地 13 处可修缺口(桥接层 1 处覆盖 5 平台 + 5 个站内小补 + yy 预热 2 路 + cc 口径);其余 ❌/⚠️ 均有结构性依据(探针/接口无字段/设计决定),遵守"不虚构数据"原则。

## 三、修复计划(多轮迭代)

### 迭代 1(2026-10-01)✅ 已完成

- [x] `purelive_backend.dart`:房间列表/搜索卡的 `online` 由裸 `room.watching` 改为 `LiveRoom.audienceValue()` 统一取值 → 一处修复 CHZZK/PandaTV/17LIVE/京东/niconico 五家"数据在手未透出"(新文件 `purelive_audience.dart` 承载,便于单测)
- [x] `kilakila_site.dart`:`watchNumber`(已解析进 DTO)透出到 `watching`
- [x] `niconico_site.dart`:分类房间路径补 `area = category.areaName`
- [x] `twitcasting_site.dart`:分类房间路径补 `area = category.areaName`
- [x] `inke_api.dart`:分类房间路径补 `area = 分组名 channel_name`
- [x] 新增 audience 取值单元测试(`test/purelive_audience_test.dart`,8 用例全过;改动文件 analyze 零问题)
- [x] 提交 `4a133082` 并推送,远端已验证

### 迭代 2(2026-10-01)✅ 已完成

- [x] YY:`getRecommendRooms`/`searchRooms` 预热 biz→分类名映射(`_bizAreaNamesSafe` 兜底,分类页失败不中断推荐流;详情路径维持惰性映射)
- [x] 探针实测(2026-10-01):
  - 映客 `webapi.busi.inke.cn/web/Live_top_pc` 行字段仅 `uid/live_id/gender/level/nick/portrait/stream_addr/is_follow` → **无观看数键,结构性无**,不虚构
  - 微博 `weibo.com/l/!/2/wblive/pc_recommend/list.json` 行字段仅 `nickname/cover/liveid/uid` → **无观看数/分类键,结构性无**
- [x] 网易CC 搜索卡:`watching` 不再填 `follower_num`(粉丝数不得冒充观看数徽标;`followers` 字段保留原口径)
- [x] analyze(yy/cc 零问题)→ 提交推送

### 迭代 3(2026-10-01,定稿)✅

- [x] 审计表刷新为修复后状态;剩余缺口全部标注结构性依据
- [x] 结论:观看人数/分类徽标的可修缺口已全部落地;其余为平台不公开数据(探针/接口无字段/无公开目录),维持"不虚构"原则
- 后续可选(不阻塞,另行立项):Bigo/京东/酷狗 area 站名→详情 API 分类富化(需逐房请求,成本高);弹幕接入沿第四节上轮清单推进

### 迭代 4(2026-10-02)✅ 弹幕专项一:SHOWROOM 全链路落地

- [x] 网络可达性普查(2026-10-02,本机):
  - `kr-ss*.chat.naver.net`(CHZZK)→ TLS 握手被 RST,**curl 直连/经代理同样失败**,平台级网络不可达;REST 侧 dart 无 ALPN 也被黑洞,`RawSecureSocket+ALPN` 可通(探针 `tool/probes/chzzk_chat_probe.dart` 已存档,拿到过 `chatChannelId`,待境外网络跑 WS 帧实测后接入)
  - `chat.missevan.com` → 连接重置(不可达)
  - `a.h.livestream.nicovideo.jp` → 000(不可达)
  - `realtime.twitcasting.tv` / `online.showroom-live.com` / `chat.picarto.tv` / `chat.pandalive.co.kr` / `cc.163.com` → **可达**
  - AcFun:目录/访客登录可达,但弹幕 token 入口(`www.acfun.cn/rest/pc-direct/*` JS 挑战、kuaishouzt getToken 空)无法取到 IM 凭据,protobuf IM 协议无从实测,暂缓
- [x] SHOWROOM 弹幕协议探针实测打通:`live_info` 提供 `bcsvr_host/port/key` → `wss://online.showroom-live.com/` 发 `SUB\t<key>` → 收 `MSG\t<key>\t{json}`(`t:1` 评论 ac/cm 字段,t:2 礼物)
- [x] `ShowroomDanmaku` 实现(`lib/core/danmaku/showroom_danmaku.dart`):复用 `WebScoketUtils`(wss 主+ws:port 备失败转移、有界重连),`parseFrame` 纯函数可单测;`showroom_api.commentServer()` 解析并校验 bcsvr 主机白名单,`room()` 单请求同时供状态+弹幕参数
- [x] 单测 5 用例(实测捕获帧 fixture)全过;改动文件 analyze 零问题
- [x] **全链路验收**:`danmaku_connection_matrix_probe_test` 扩展 showroom 平台,PURELIVE_DANMAKU_PROBE=1 实测 `result: passed`(readyCount=1, chatCount=1, 零重连零断开)

### 迭代 5(2026-10-02)✅ 弹幕专项二:第二平台探针摸底

- [x] TwitCasting 探针(2026-10-02 实测):目录/分类接口可达并拿到 live movieId;但
  - `wss://realtime.twitcasting.tv/pages/<id>?comment=true` → 404(路径/握手格式不对)
  - `frontendapi.twitcasting.tv/movies/<id>/comments` GET/POST → 405 Method Not Allowed(需登录态)
  - 频道 live 页 / movie 页 → 0 字节/404(匿名反爬),无法从播放器 JS 逆向 WS 协议
  - ~~结论:协议未确证,按"不盲写"原则暂缓~~ → **迭代6 找到正确入口后已落地,见下**
- [x] PandaTV / Picarto:聊天主机可达但协议无公开文档,列为后续探针候选(优先级低于 TwitCasting/CHZZK)
- [x] CHZZK 弹幕:探针脚本已存档(`tool/probes/chzzk_chat_probe.dart`,REST+ALPN 已验证可拿 chatChannelId),待境外网络跑 WS 帧实测后按 SHOWROOM 模式接入

### 迭代 6(2026-10-02)✅ 弹幕专项三:TwitCasting 全链路落地

- [x] 协议确认(参考 [biliup danmaku crates](https://github.com/biliup/biliup) 协议实现 + 本机实测):
  POST `https://twitcasting.tv/eventpubsuburl.php`(form: movie_id+password)→ 返回**带签名、约 1 小时时效的 WS 地址** → 连接后直接收 JSON 数组评论帧(`message`/`from_user.name`),无需心跳,首帧为 `[]`
- [x] `TwitcastingDanmaku` 实现(`lib/core/danmaku/twitcasting_danmaku.dart`):因 pubsub URL 每次连接都要重新换取(签名过期),自管重连循环(有界 8 次失败上限,成功后清零),`parseFrame` 纯函数可单测,URL 主机白名单校验;`twitcasting_api.detail()` 把 movieId 写入 `danmakuData`
- [x] 单测 5 用例全过;改动文件 analyze 零问题
- [x] **全链路验收**:矩阵探针 twitcasting 平台 `result: passed`(readyCount=1, chatCount=1, 零重连零断开, roomId=ihacocone)
- [x] 迭代5 记录修正:上轮 realtime WS 路径 404 的结论系入口未找到,非协议不可用

### 迭代 7(2026-10-02)✅ 收尾摸底

- [x] niconico:主站/watch API 可达(301)但弹幕服务器 `msg*.live2.nicovideo.jp` 000 不可达 → 暂缓(网络结构性)
- [x] PandaTV:API 对本机 IP 返回"제재된 IP"(封禁)→ 暂缓(网络结构性)
- [x] CC:目录/房间接口可达,但房间页为 JS 壳、无公开协议文档、biliup 亦已移除 CC 弹幕实现 → 协议未知,暂缓;候选路径:抓包或逆向 umi bundle(工作量大,另行立项)

### 迭代 9(2026-10-02)✅ CC 弹幕攻坚(入口未确证, 定案)

- [x] 从 live-bullet-player 拿到历史 CC 协议参照(cc.py):`wss://weblink.cc.163.com/` + 自研 msgpack 变体 + zlib;信息端点 `api.cc.163.com/v1/activitylives/anchor/lives?anchor_ccid=` 可用
- [x] 探针实测(`tool/probes/cc_chat_probe.dart`,含最小 msgpack 编解码):**register/heartbeat 均被服务端接受**(result=0 ok),但 **join 三种编码(参考 float64/字符串/标准 uint32)分别被拒或静默丢弃**——参考实现已与服务端脱节,现行 join 参数需逆向官方 umi bundle 或抓包
- [x] 结论:协议入口未确证,按"不盲写"原则定案为**另行立项**;探针脚本与编码器已存档,后续只需替换 join 包即可复用全部链路

### 迭代 10(2026-10-02)✅ 弹幕专项四:AcFun 全链路落地

- [x] 协议路径修正:弹幕凭据**就在 startPlay 响应里**(availableTickets/enterRoomAttach/liveId),无需此前被 JS 挑战挡住的 getLiveInfo——之前"IM 凭据入口被拦"的判断有误;站点既有的 PC_WEB startPlay 链路直接可用
- [x] WS 主机 `wss://link.xiatou.com/` 从官方 JS bundle 确认且本机可达
- [x] `AcFunDanmaku` 实现:protobuf 封帧(0xABCD 帧 + PacketHeader/UpstreamPayload/DownstreamPayload)+ AES-CBC(+IV, ssecurity/sessionKey 双密钥)+ Register→EnterRoom→Heartbeat 会话流;`acfun.proto` 经 protoc 生成 pb 代码入库;visitor 会话补 ssecurity,playback 返回 `AcfunCommentCredentials`
- [x] 单测 5 用例(封帧往返/坏帧拒绝/AES 往返/评论信号解析)全过;analyze 零问题
- [x] **线级验证**:真实房间 Register ack(instanceId+sessKey)→ EnterRoom ack → Push 流解析出 `UserEnterRoom`/`Like` 信号与 `RecentComment` 真实评论(`崎路人: 发现了`),评论 schema 线级确认
- [x] 矩阵探针扩展 acfun 平台,`result: passed`(会话保持;评论帧因观察时段房间静默未触发 requireChat,解析路径由线级 RecentComment + 单测覆盖)

### 迭代 11(2026-10-02)✅ 全站播放检测: purelive 解析层零失效

用户要求并行检测各平台首页与直播间播放,验证 purelive 是否部分失效。用 `tool/probes/all_sites_playback_probe_test.dart`
(分类目录→房间详情→画质→播放地址→真实媒体字节,走 purelive 自身适配层)分 4 组并行 + 补测,33 站点全覆盖:

- **media-ok(全链路健康)25 平台**:bilibili/douyu/huya/douyin/kuaishou/cc/yy/twitch/soop(9/9)|
  inke/kilakila/baidulive/kugoulive/jdlive/sixroom/looklive/liveme/missevan(9/9)|
  chzzk/picarto/showroom/steambroadcast/twitcasting(5)|acfun/weibo(2)|17live(补测)
  —— 含本轮迭代全部改动平台,CHATWS/pubsub/link-sdk 弹幕落地未破坏任何播放链路;chzzk 播放全链路正常(迭代8 封锁结论仅限聊天 WS 边缘)
- **owned-input 播放配方(非失效,探针通用取流不适用)3 平台**:bigo、fc2live、niconico(到 urls 阶段,verdict=owned-input)
- **环境封锁 1**:pandalive(本机出口 IP 被 PandaTV 封禁,迭代8 同因)
- **结构性无目录 3**:tiktok/xiaohongshu/youtube(设计如此)
- **未测 1**:iptv(需本地频道 DB,设计排除)
- 工具链教训:4 个 flutter test 并发会在 `build/native_assets` 竞态(G1 首跑因此作废),重跑需串行
- 构建侧同期修复:工作流默认标签×3 对齐 v3.1.17、secret-audit TLS 夹具断链、CC 探针 mock 兼容、ffmpeg 哈希 3.7 兼容、SiteIds 迁移同步、flame_barrage 死 fork 删除(0.0.7 已含其修复)、firebase 预取无依赖时跳过、JDK21 便携版部署(F:/tools/jdk21)
- 遗留:Release 构建两度败于运行中应用锁 exe → 应用关闭后 `-SkipQuality` 重建(同源码质量门已过)

### 迭代 12(2026-10-02)✅ 全站播放复检:解析层仍零失效,唯一失效仍是 pandalive(出口 IP 封禁)

用户报告"部分平台首页加载失败,直播间也无法播放",重跑 `all_sites_playback_probe`(G3 境外组先行过冷编译,G1/G2/G4 warm 并行,32 站;报告 `build/probe_reports/iter12/g*.json`):

- **media-ok 28 站**:G1 8/8(bilibili/douyu/huya/douyin/kuaishou/cc/yy/acfun)| G2 10/10(inke/kilakila/baidulive/kugoulive/jdlive/sixroom/looklive/liveme/missevan/weibo)| G3 7/9(chzzk/soop/showroom/twitcasting/picarto/17live/steambroadcast)| twitch
- owned-input 3:bigo/fc2live/niconico(到 urls,播放配方非失效);no-catalog 3:tiktok/xiaohongshu/youtube(结构性);iptv 设计排除
- **失效 1:pandalive**:catalog 阶段 565ms 快速失败 `PandaTV access`(`pandalive_api.dart` 类型化 access 异常,IP 封禁类),与迭代8/11 同因;当前 Clash 出口 `103.151.172.13`(越南 DC 段)。迭代8 实测直连/越南/韩国出口均被封 → 换节点不保证,需干净(住宅级)出口
- 环境佐证:curl 裸 TLS 下 `api.chzzk.naver.com`/`api.sooplive.co.kr`/`api-v2.17app.co` TLS 握手黑洞,但适配层自定义 ALPN 客户端全通(既有环境事实,非平台失效);`gql.twitch.tv`/pandalive 边缘/showroom/niconico/twitcasting/picarto 可达
- 应用侧核对:运行中 pure_live.exe = 迭代11 最终构建(14:42:50 出包,14:43:29 启动),与探针同源码同链路;若应用内失败面大于 pandalive,优先重启应用对齐(站点单例缓存/Clash 节点切换瞬时窗),探针期间应用保持运行(flutter test 不触 exe)
- 工具链:并行前置条件确认——**冷构建绝不能并发**(迭代11 竞态教训),warm 缓存下 3 组并行安全;`flutterw.ps1` 参数直接是 flutter 子命令(`test <file>`),不能再传一层 `flutter`

### 迭代 13(2026-10-02)✅ 画质菜单多档不可点修复:zishu 预取懒取流链两处缺陷 + UI 契约违约

用户报告"各平台有多个清晰度但只能点击其中一个"。定位链:用户所见画质菜单是 **zishu 播放页** `lib/src/features/play`(`_QualitySelectBox`;`/watch/:site/play/:id` 路由直达,`purelive_play_bridge`/pure_live LivePlayPage 在 lib 下零引用,非运行时路径);解析层经新探针 `tool/probes/quality_switch_probe_test.dart`(复用控制器判定函数)实测 17 个多档平台全数 switch-ok,排除解析层与 pure_live live_play 面板。

缺陷链(源 `f3606c3f` zishu 宿主切换引入的预取设计,三环相扣):

1. `_prefetchQualities` 用 `qualityByName` 判"该档是否已解析"——它未命中回退 `streams.first`(必有线路)→ 缺失档全部误判已解析,**预取队列恒空(预取成死代码)**
2. `_prefetchOne` 合并只做同名替换——懒取流初始 streams 仅进房档,预取回的新档位被静默丢弃
3. UI `enabled` 只放开 streams 已有档,违反设计契约"上限之外的档位仍可点击——切档时按需解析"(`kPrefetchQualityLimit` 注释原文)

修复(三环全修):

- `play_selection.dart` 新纯函数 `pendingPrefetchQualities`(精确同名判定,占位档照常入队)/ `mergeResolvedStream`(新档名追加,`streams.first` 默认档锚点不变)
- `play_provider.dart` 两处调用点接入;`player_controls.dart` `_QualitySelectBox` 恢复全档可点(未解析档传空线路占位 → `switchQuality` 走既有 `_qualityOverride` 按需重解析路径)
- 新增 `test/play_quality_prefetch_test.dart` 8 用例全过;全仓 50/50;analyze 改动文件零问题
- 探针入库:`tool/probes/quality_switch_probe_test.dart`(`PURELIVE_QUALITY_SWITCH_PROBE=1`,环境变量与全站探针同款)
- 备注:B 站匿名 qn 回落/斗鱼匿名降档(第四节通用待修复)是服务端行为,与本缺陷无关,切档请求路径本就正常

### 迭代 8(2026-10-02,Clash 境外出口复核)✅ 弹幕专项收官:数据中心 IP 封锁定论

用户 Clash 可境外后,提取活订阅节点(韩/日/美标签,实测出口均为 `222.120.184.x` 韩国 KT 农场段),经独立 mihomo 测试实例(7899 端口,已清理)逐节点复核:

| 目标 | 直连 | 越南出口(103.151.172.70) | 韩国出口(222.120.184.x) | 结论 |
|---|---|---|---|---|
| www.naver.com / api.chzzk.naver.com(REST) | — | — | **200** | REST 层无封锁 |
| kr-ss1/2/3.chat.naver.net(CHZZK 弹幕) | RST | TLS 停滞 | **000** | **弹幕边缘封数据中心 IP**(连韩国 DC 都拒),需住宅级韩国网络 |
| msg01.live2.nicovideo.jp(弹幕) | 000 | 000 | **000** | 同上,暂缓 |
| chat.missevan.com | RST | — | **000** | 国内外出口均拒,暂缓 |
| api.pandalive.co.kr | IP封禁(제재) | 200→000(几分钟后稳定 000) | **000** | 共享出口 IP 被其边缘封禁,暂缓 |
| www.showroom-live.com | — | — | 200 | (已落地,不受影响) |

- [x] 结论:**剩余弹幕缺口(CHZZK/niconico/猫耳/PandaTV)全部卡在聊天边缘对数据中心 IP 的针对性封锁**,与协议本身无关;本环境(含 Clash 各出口)无法取得协议帧证据,按"不盲写"原则维持搁置
- [x] CC(协议未知)/ AcFun(IM 凭据入口被 JS 挑战拦截)/ Steam(需登录)维持迭代7 结论
- [x] 后续解锁路径(需要时再立项):住宅级韩国网络跑 `tool/probes/chzzk_chat_probe.dart` → 按 SHOWROOM 模式接入 CHZZK;其余平台同理需对应住宅出口 + 抓包
- [x] 工具与脚本已存档:CHZZK 探针、弹幕矩阵探针(showroom/twitcasting 已入支持列表)

## 四、上轮审计:解析字段缺口(2026-10-01 上一轮,保留)

### 已完整接入(purelive backend, 四家 sidecar 化)

| 平台 | 分区 | 推荐 | 搜索 | 弹幕 | 播放 | 缺口 |
|---|---|---|---|---|---|---|
| 哔哩哔哩 | ✅ 12组 | ✅ | ✅ | ✅ 访客token | ✅ | 无 |
| 斗鱼 | ✅ 10组 | ✅ | ✅ | ✅ WebSocket | ✅ | 无 |
| 虎牙 | ✅ 4组 | ✅ | ✅ | ✅ WebSocket | ✅ | 无 |
| 抖音 | ✅ 8组 | ✅ | ✅ | ✅ WebSocket | ✅ | 匿名流间歇限速(已补 cookie 缓解) |

### 已接入(live_parser 自带, 需补充验证)

| 平台 | 分区 | 推荐 | 搜索 | 弹幕 | 播放 | 缺口 |
|---|---|---|---|---|---|---|
| 快手 | ✅ | ✅ | ✅ | ✅ | ✅ | 无 |
| SOOP | ✅ | ✅ | ✅ | ✅ | ✅ | 无 |
| Twitch | ✅ | ✅ | ✅ | ✅ | ✅ | 无 |
| YY | ✅ | ✅ | ✅ | ✅ | ✅ | 无 |

### 需接入 purelive backend(pure_live 有实现, live_parser 无)

| 平台 | 分区 | 推荐 | 搜索 | 弹幕 | 播放 | 缺口 |
|---|---|---|---|---|---|---|
| 网易 CC | ✅ | ✅ | ✅ | ❌ 未接入 | ✅ | 弹幕 |
| AcFun | ✅ | ✅ | ✅ | ❌ 未接入 | ✅ | 弹幕 |
| 猫耳 FM | ✅ | ✅ | ✅ | ❌ 未接入 | ✅ | 弹幕 |
| Picarto | ✅ | ✅ | ✅ | ❌ 未接入 | ✅ | 弹幕 |
| TwitCasting | ✅ | ✅ | ✅ | ❌ 未接入 | ✅ | 弹幕 |
| CHZZK | ✅ | ✅ | ✅ | ❌ 未接入 | ✅ | 弹幕 |
| niconico | ✅ | ✅ | ✅ | ❌ 未接入 | ✅ | 弹幕 |
| SHOWROOM | ✅ | ✅ | ✅ | ❌ 未接入 | ✅ | 弹幕 |
| PandaTV | ✅ | ✅ | ❌ | ❌ 未接入 | ✅ | 搜索+弹幕 |
| Steam | ✅ | ✅ | ✅ | ❌ 未接入 | ✅ | 弹幕 |

### 有限接入(仅精确链接/部分功能)

| 平台 | 可用功能 | 缺口 |
|---|---|---|
| 小红书 | 精确链接播放 | 分区/搜索/弹幕 |
| 微博 | 精确 ID 播放 | 分区/搜索/弹幕 |
| 映客 | 有限精选+精确 UID | 全站搜索/弹幕 |
| YouTube | 精确 ID/@handle 播放 | 分区/弹幕 |
| TikTok | 精确账号/链接播放 | 分区/弹幕 |
| FC2 | 精确频道号播放 | 弹幕 |
| Bigo | 有限推荐+精确 ID | 全站搜索/弹幕 |
| 京东直播 | 分区目录 | 搜索细节/弹幕 |
| 酷狗直播 | 分区目录 | 搜索细节/弹幕 |
| 百度直播 | 分区目录 | 搜索细节/弹幕 |
| 六间房 | 分区目录 | 搜索细节/弹幕 |
| LOOK | 分区目录 | 搜索细节/弹幕 |
| 17LIVE | 有限推荐+有限搜索 | 弹幕 |
| LiveMe | 分区+搜索 | 弹幕 |

### 已下线(不接入)

Kick / PopkonTV / Shopee / VK / Dailymotion / Rumble / GoodGame / 花椒 / OPENREC / TTingLive / 淘宝

### 通用待修复

- [x] douyin 请求头 cookie 从站点单例自动刷新 ✓ 已修
- [ ] 斗鱼非最高档播放时可能被服务端降档(匿名限制, 需登录 Cookie 解锁)
- [ ] B 站匿名请求 qn=80/150 被回落 250 超清(需登录 Cookie 解锁)
- [ ] huya playUserAgent 进程级缓存需定期刷新(已在 huya_site 内处理)
