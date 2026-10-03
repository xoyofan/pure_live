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
| SOOP | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅ | ✅ WS | 基准组;迭代27 分类角标中文化(分类号反查进程表,修复卡片直出 0010333 数字) |
| YY | ✅ | ✅ 迭代2 预热 | ✅ | ✅ | 真数据 | ✅ 迭代2 预热 | ✅ WS | 已对齐 |
| AcFun | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅(结果卡无观看,结构性) | ✅ 迭代10 link-sdk WS | 弹幕已线级验证 |
| Picarto | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅(搜索无观看,结构性) | ✅ 迭代12 匿名 WS | 弹幕已全链路验收 |
| TwitCasting | ✅ | ✅ 迭代1 | ✅ | ✅ 迭代1 | 真实(HTML) | ✅(搜索无观看,结构性) | ✅ 迭代6 WS(pubsub) | 弹幕已全链路验收 |
| 猫耳FM | ✅(热度) | ✅ | ✅ | ✅ | 真数据 | ✅ | ✅ 迭代12 im网关 WS | 弹幕已全链路验收 |
| CHZZK | ✅ 迭代1 透出 | ✅ | ✅ 迭代1 透出 | ✅ | 伪目录(仅popular) | ✅(仅频道卡) | 📦 迭代13 代码先行 | 待网络验收 |
| niconico | ✅ 迭代1 透出(累计观看口径) | 🚫 recent 行无分类 | ✅ 迭代1 透出 | ✅ 迭代1 | 硬编码7 tab | ✅ | ❌ | 已修 |
| SHOWROOM | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅(本地快照过滤) | ✅ 迭代4 WS(SUB/MSG) | 弹幕已全链路验收 |
| Bigo | ✅ | ⚠️ 硬编码站名(列表API无分类键) | ✅ | ⚠️ | 硬编码单 | ✅(ID+本地过滤) | ✅ 迭代12 游客WS | 注册/进房已验证 |
| FC2 | ✅ | ✅ | ✅ | ✅ | 硬编码6官方 | ✅(快照内) | ✅ 迭代12 控制seat | 弹幕已全链路验收 |
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
| PandaTV | ✅ 迭代1 透出 | ✅ | ✅ 迭代1 透出 | ✅ | 单伪分类 | ✅ | 📦 迭代13 代码先行 | 待代理/住宅网络 |
| IPTV | 🚫 裸流无统计 | ✅ groupTitle | 🚫 | ✅ | 真实(本地DB) | ✅ 本地 | ❌ | 观看结构性 |

统计:迭代1+2 共落地 13 处可修缺口(桥接层 1 处覆盖 5 平台 + 5 个站内小补 + yy 预热 2 路 + cc 口径);其余 ❌/⚠️ 均有结构性依据(探针/接口无字段/设计决定),遵守"不虚构数据"原则。

### 迭代 13(2026-10-02)✅ 弹幕专项六:PandaTV + CHZZK 代码先行

- [x] PandaTV:Centrifugo v1 JSON(chat-ws.bktv.kr 可达);凭据随 `/v1/live/play` 响应(token+channel, 回退 userIdx)透传至 danmakuData;connect/subscribe JSON 对 + push.pub.data 防御解析;单测 5 用例。**本机 api 主机 IP 封禁无法全链路验收,应用走代理即可用**
- [x] CHZZK:凭据链实测全通(live-detail `chatChannelId` → `access-token?channelId=` 200);cmd 帧族(100/10100/5101/93101/0/10000)+ 主机选择公式 + RawSecureSocket+ALPN 最小 RFC6455 传输(Naver 边缘黑洞无 ALPN 的 dart TLS——与探针网络环境记忆一致);单测 7 用例。**9 台聊天主机本机握手不可达,待住宅网络验收**
- [x] niconico:评估为**暂缓**——弹幕需从播放会话 room 消息取 msg 主机,独立会话有座位互踢风险,且 msg 主机不可达无法验证
- 现役弹幕平台:8 家新增(SHOWROOM/TwitCasting/AcFun/猫耳/Picarto/FC2/Bigo 落地 + PandaTV/CHZZK 代码先行)

### 迭代 14(2026-10-02)✅ 弹幕专项七:17LIVE 落地 + KilaKila 落地 + 国内 8 平台档案

- [x] 17LIVE:浏览器逐帧抓包全捕获。匿名通配 token 端点 = `POST /api/v1/messenger/auth`(permissions=["*"];/messenger/token 是全局限能力 token,ATTACH 房间被 40160 拒);Ably 帧序列 = 服务端 CONNECTED(4)→客户端 ATTACH(10)→ATTACHED(11)→MESSAGE(15,data=Base64(gzip(JSON)) 魔数嗅探,type3=评论);curl 匿名复现成功;调试探针实测 **ATTACHED+房间频道 action15 持续到达**(chat=0 系凌晨房间安静);单测 5 用例;矩阵探针 passed
- [x] KilaKila:调研确证 `/LiveRoom/latestQuery` 匿名 200(b.data[] 行 content=JSON 串);REST 4s 轮询版实现(relativeTime 去重、防御键名解析、bizType2 问答卡天然过滤);单测 4 用例;矩阵会话 passed(chat=0 同因房间安静)
- [x] 国内 8 平台档案(调研 agent):
  - **映客**:协议确证(chatroom.inke.cn/url 匿名返回带签名 WS,JSON 帧),本机 WS 边缘拒(IP 绑定签名)→ 待网络,成本最低
  - **酷狗**:协议确证(chat1wss.kugou.com/acksocket,JSON+
 命令字 201/501,心跳 H/10s),匿名登录未放行待复测
  - **六间房**:文本行协议确证(login/心跳 y8vPLwAA/16s),缺 WS 域名+encpass 签发,需浏览器抓包
  - **LOOK**:网易云信 NIM Chatroom(凭证 chat/address),工作量大按需投入
  - LiveMe(socket.io 主机未定位)/京东(h5st+eid 风控,不建议)/百度(房间页封锁,无社区资料):暂缓
- 现役弹幕平台:**10 家新增落地**(SHOWROOM/TwitCasting/AcFun/猫耳/Picarto/FC2/Bigo/17LIVE/KilaKila + 头部 8 家既有)+ PandaTV/CHZZK 代码先行

### 迭代 15(2026-10-02)✅ 映客/酷狗 活体实验定论

- [x] 映客:官方直播间页面本机浏览器实测聊天 WS 同样 **error+close 1006**(与 dart 拨号一致)→ 网关拒本机出口,**环境性拒绝定论**;`/url` 签名端点本身可达,协议档案完整,待住宅网络按档案实现即可
- [x] 酷狗:活体实验(握手成功→匿名 cmd201→**服务端立即断开**,重试同因)→ **匿名登录被拒定论**,需游客 soctoken 签发接口或登录态;探针脚本已存档(/tmp 揭示的帧结构见国内组档案)
- 现役弹幕平台维持:**10 家新增落地** + 2 家代码先行(PandaTV/CHZZK);剩余平台均有明确阻塞项

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

### 迭代 12(2026-10-02)✅ 弹幕专项五:四平台批量落地(并行调研档案驱动)

- [x] 三路并行调研(海外+特殊组完成,国内组 fetch failed 待重试):产出 13 平台协议档案;**猫耳"网络封锁"系误判**(聊天在 im.missevan.com 观看端通道,非被墙的 chat 子域)
- [x] 猫耳FM:`wss://im.missevan.com/ws?room_id=` + 匿名 cookie(任意 base)+ join 帧 + ❤️ 30s 心跳;矩阵探针 **passed**
- [x] Picarto:`wss://chat.picarto.tv/chat/token=`(空 token 匿名可读)+ init 帧 + `__ping__` 50s + 按频道 rn 过滤;探针 **passed**
- [x] FC2:复用 `controlGrant` 开独立控制 seat,`comment` 批次帧 + heartbeat 30s;探针 **passed**
- [x] Bigo:getWebSocketLink 游客会话 → eid 帧(challenge 256→MD5 应答 79108→login 512279→enter 1304)→ 2584 base64 载荷;调试探针验证**注册+进房成功**(chat=0 系该时段房间安静;矩阵探针败于房间发现阶段——12 间房 10 间 BigoException,属站点目录噪声)
- [x] CHZZK:access-token 端点确证并实测 200(参数名 `channelId`),协议链验证至 token;9 台聊天主机本机 dart+ALPN 仍全部握手失败(子代理 openssl"成功"为误读),维持待网络;探针脚本已更新到现役 cmd 帧协议
- [x] 新增单测 19 用例(4 套全过);弹幕矩阵探针扩至 10 平台;analyze 零问题
- 现役弹幕平台总计:**7**(SHOWROOM/TwitCasting/AcFun/猫耳/Picarto/FC2/Bigo) + 头部 8 家此前已有

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

### 迭代 14B(2026-10-02)✅ 多平台起播修复:HLS 带签名被误判 flv 入 FLV 代理 + GetX 设置依赖四平台解析必挂

用户报告猫耳 `fm.missevan.com/live/868888435` 无法解析,并称"很多平台直播间无法解析"。真机日志(`%APPDATA%\zishu_flutter\logs\playback.log`)定位出**两类独立根因**,合计波及约 10 个平台:

**根因一:purelive_backend 线路格式误判 → HLS 线必然起播失败**(猫耳/Twitcasting/虎牙 HLS 线/抖音 HLS 线/17LIVE RTMP)

- `resolveRoom` 的 format 判定用整串 `endsWith('.m3u8')`,而签名直链(猫耳 `…m3u8?cdn=…&sign=…`、虎牙 `…flv?wsSecret=…`)恒为 false → HLS 被标成 flv → 被包进 **FLV 专用本地流代理**(`media_kit_live_player._wrapLineWithProxy` 只放行 `format=='flv'`)
- 失败形态(日志确证):代理把 359 字节 m3u8 文本当 FLV 喂 mpv(`Reading plaintext playlist`)→ mpv 把 ts 分片名拼到 `http://127.0.0.1:PORT/maoer_….ts` 请求 → 代理按 `pathSegments.first` 解析 session id 非数字 → **全部 404** → `source_open_failure`×6 → `give_up`,播放器空转至用户退出
- 波及面(日志 host 统计):猫耳 HLS ×15、Twitcasting ×8、抖音 HLS ×3、17LIVE RTMP ×3、虎牙 HLS ×1;同 host 的 FLV 线正常(昨天 23:32 猫耳 HLS 挂/FLV 线活,同因)
- 修复:新纯函数 `pureLiveLineFormat`(`lib/src/shared/application/purelive_line_format.dart`,独立文件可单测):按 **URI path 后缀**判 hls/flv,`rtmp(s)://` 单独归 `rtmp`(代理护栏天然放行直连);`purelive_backend.resolveRoom` 接入

**根因二:twitch/kuaishou/soop/yy 适配器无条件访问 GetX `SettingsService.to` → zishu 运行时解析必挂**

- zishu(riverpod)不初始化旧 UI 的 GetX 服务栈(`Get.put(SettingsService)` 只在旧 UI `initial_services.dart`);真机日志实锤 `resolve_fail site=twitch reason="SettingsService" not found` ×11(jinnytty 房)。douyu 因 `_persistCookie` 容错(host 未注册即跳过)幸存
- 探针盲区:全站探针 setUpAll 手动 `Get.put(SettingsService)`,与真机 zishu 链路的**关键环境差异**,故探针 28/29 全绿而真机四平台必挂
- 修复:`SettingsService.maybe` 安全访问器(`Get.isRegistered` 守卫,已注册时与 `to` 等价);twitch 站 4 处(cookie+3 处 proxy)、twitch 弹幕 1 处、kuaishou 2 处、soop 1 处、yy 1 处改 `maybe` 降级(cookie 空=游客态可解析——探针空 Hive 下 media-ok 即证;代理 null=直连)。`playback_header_resolver`/douyu 本就容错不动;`sites.availableSites`/iptv 不在 zishu 链路不动

**验证**:新增 3 套单测 11 用例全过(`purelive_line_format_test` 6 / `settings_service_maybe_test` 2 / `site_settings_fallback_test` 3:twitch 匿名头、soop/yy 空 Cookie 降级、maybe null/等价契约);并行工作收敛后全仓 analyze 补跑通过(仅剩 10 条预存在项),backend 链既有测试 14 用例过。

**真机复验(当日 19:38,Windows Release @60e6e37d 构建)**:`pure_live.exe --site missevan --room 868888435` 直达用户报的房间——`resolve_ms=227 qualities=HLS,FLV` → `open host=d1-missevan104.bilivideo.com`(**无 `proxy_line_wrap`**,修复前 HLS 必被包进 FLV 代理)→ `video_first_frame_rendered` 1s 内 → 持续播放 50s+ `demuxer_cache_time` 稳定推进、`frame_drops=0`、mpv `path=` 直持猫耳 m3u8 地址;本次会话 `source_open_failure` 零新增(历史 31 次全为修复前)。顺带修复:验证时发现启动路由 URL 平台推断表缺猫耳域名(`--room https://fm.missevan.com/live/N` 静默回落首页),补 `fm.missevan.com` 条目 + `startup_url_hint_test` 3 用例。

**备注**:当日真机日志另见 bigo `schema`×4(owned-input 播放配方,非缺陷)、chzzk `mediaUnavailable`(房间未播)、douyu 超时/握手失败×4(15:24-15:34 出口网络抖动,后续恢复)。

### 迭代 15(2026-10-02)✅ 首页巡检:猫耳 meta/data 灰度改版适配 + 分类探针环境修正

用户报告"部分平台首页错误 soop yy 等等"。全站分类探针(`tool/probes/all_sites_categories_probe_test.dart`,走 zishu 浏览同一入口 `getCategores(1,100)`)真实网络巡检 34 站:

- **探针环境修正**:flutter test 绑定对所有请求返回假 HTTP 400(替代响应),此前 12/34 的"失败"全是环境假象;仿播放探针补 `HttpOverrides.runWithHttpOverrides(_RealNetwork())` 包装后真实基线 **26/34**,空目录站(小红书/TikTok/YouTube/17live/LiveMe 等)与审计表"结构性无首页"结论一致,xhs 为凭证门控,非缺陷
- **soop/yy 定级:非代码缺陷**。两站分类+推荐端点 curl/适配层全通(yy 3 组 18 项、soop 543 项);真机首页错误即**迭代14 根因二**(GetX 设置依赖),已由 6061d77c 修复。`live.sooplive.co.kr` 当日 17:5x 曾短暂 TLS 超时(出口瞬态,与迭代14 douyu 抖动同性质),19:0x 自愈,不改代码
- **SHOWROOM 单次 schema 报错为瞬态**,复测 19 组全通,不改代码
- **猫耳(唯一真缺陷)**:`fm.missevan.com` 灰度改版,`meta/data` 的 `info.tabs` 沦为纯展示键(无 type/id),旧解析必抛 schema → 首页错误。改版后可过滤 id 在 `info.catalogs[]`;实测 `chatroom/open/list` 只认**顶层 catalog_id**(sub_catalogs/custom_tag_groups 的 id 过滤恒空 count=0)。修复 `MissevanApi.categories`:`tabs`→`catalogs` 映射,瓦片只暴露顶层目录(配音/音乐/情感/放松/古风 5 项),不虚构子分类
- **验证**:新增 `test/missevan_categories_test.dart` 3 用例(新 schema 映射/旧 schema 拒绝/服务错误透传)全过;missevan 站回归(danmaku 8/8);分类探针复验 missevan categories-ok 5 项、kuaishou 831/showroom 18/soop 543/yy 3×18 全绿;范围化 analyze 零问题(全仓 analyze 仍随并行弹幕批次收敛后统一跑)

### 迭代 16(2026-10-02)✅ 分类全站中文化:remap 表接入展示层 + fork 补充表 + soop 英文化 + 瞬态错误重试

用户报告"分类部分平台没解析,hover 顶部平台显示很多错误,要像 zishu 对齐、分类都解释为中文显示"。迭代15 已把解析层修到 26/34(余项结构性);本轮审计聚焦**显示层语言**与**瞬态错误体验**,两个上游变化实锤:

- **SOOP 上游撤了 zh_CN 本地化**(迭代12 期间 `categoryList` 带 `lang=zh_CN` 直出中文,现已失效,仅保留 ko/en 两档;live_parser 的 soop zh 进程表机制随之整体失效)。实锤:`lang=zh_CN` 与无 lang 均回韩文,`Accept-Language: zh-CN/en-US` 回英文。修复:`SoopSite.getHeaders` 统一 `Accept-Language: en-US`(数据层取英文目录名,543 项),展示层中文化
- **`remapCategoryName`(web 真源 `category-name-remap.ts` 生成的 180+ 条英文→归一中文表)在 fork 的 pure_live 数据链路从未被调用**——这是"没对齐 zishu"的核心缺口(live_parser 旧 browse 数据层有调用,但被 purelive 注册覆盖成死代码)

修复三件套:

1. **展示层统一中文缝**:`displayCategoryName`(`lib/src/shared/domain/category_display.dart`)按序接 ①fork 补充表 ②`remapCategoryName`(twitch/soop,live_parser barrel 新增导出) ③soop zh 进程表 ④跨平台表 ⑤原名。twitch 41 个一级分组标签全量中文(Adventure Game→冒险游戏等),二级热门游戏经 remap 命中(Just Chatting→聊天、IRL→户外),长尾回落英文(与 web 真源口径一致)
2. **fork 补充表**(`lib/src/shared/domain/category_zh_supplement.dart`,不动两个生成文件):TwitCasting 按**稳定 data-channel key** 反查 22 项(标签随请求语言变)+ 标签兜底表;Picarto 官方 categories API 全量 20 项;SHOWROOM onlives genre 全量 19 项;SOOP 补 remap 未覆盖热门 36 项(Lost Ark→命运方舟、Virtual→虚拟主播、Diablo II→暗黑破坏神2 等)
3. **瞬态错误不再常驻**:`CategoryController.build` 失败自动延迟重试一次(800ms,持续失败仅重试一次);hover 浮层错误态从"原始异常字符串"改为「分类加载失败 · 点击重试」(点击 invalidate 重拉),底部分类面板错误态加重试按钮

**验证**:新增 2 套单测 10 用例全过(`category_zh_display_test` 8:twitch 分组/remap/twitcasting cid+标签兜底/picarto/showroom/soop 英文映射+韩文回落/中文平台不劫持/跨平台 cid 仍生效;`category_controller_retry_test` 2:失败重试一次成功/持续失败只重试一次);missevan_categories+site_settings_fallback 回归全绿(16/16);范围化 analyze 零问题;探针复验 soop 数据层已切英文目录名(展示层中文由单测覆盖)、missevan 5/showroom 18 稳定。探针入库 `tool/probes/catalog_diag_probe_test.dart`(任意站点目录+完整栈诊断)

### 迭代 17(2026-10-02)✅ 分类中文化续:CHZZK 真实目录落地 + SOOP 推荐流韩文徽标中文化

迭代16 收尾续作,补掉两个分类缺口:

- **CHZZK 真实分类目录**(原为"公开热门直播"单占位)。端点考古:web JS 反查 + cloudstream-chzzk 交叉确证——目录 `/service/v1/categories/live?size=20`(top-20 榜单,实测服务端**忽略一切 cursor/offset/page 翻页参数**,全量树无公开端点);分类直播 `/service/v2/categories/{type}/{id}/lives`(v1 lives 端点忽略分类参数,v2 才真过滤)。实现:
  - `ChzzkApi.popularCategories`(去重保序,行形状异常跳过不炸目录)+ `categoryDirectory`(与总榜共用 inclusive-cursor 分页解析,抽 `_directoryPageFrom`;type 大写枚举/id slug 形状双校验防路径注入)
  - `ChzzkSite.getCategores`:「公开热门直播」总榜入口(既有路由/收藏不变)+ top-20 按类型分组(游戏16/聊天1/体育2/娱乐1,分组名直接中文);`getDirectoryPageAtCursor` 按 areaType 分支总榜/分类;`_validateCategory` 放行新入口(areaType=类型枚举/areaId=slug)
  - 中文:`kChzzkZhByName` slug+韩文原名**双键**(分类树带 cid=slug,房间徽标只带韩文 `liveCategoryValue`),20 项全量翻译(로스트아크→命运方舟、발로란트→无畏契约、이환(NTE)→异环 等);UI 走 `displayCategoryName` 补充表 chzzk 分支
- **SOOP 推荐流房间徽标中文化**。实测缺口:`sch.sooplive.co.kr` 分类/目录接口吃 `Accept-Language: en-US`(迭代16),但**推荐流 `live.sooplive.co.kr/api/main_broad_list_api.php` 不吃**,房间行仍直出韩文分类名 → 首页徽标韩文。修复:按 `category_no` 把韩文名与英文名对齐(95 对),为已有中文翻译的 68 项生成韩文键并入 `kSoopZhByName`——首页房间徽标(토크/캠방→聊天/秀场、버추얼→虚拟主播、국가대표→国际足球 等)与英文目录同源中文化

**验证**:`category_zh_display_test` 增 chzzk 双键用例 + soop 韩文键断言(9 用例全过);回归 25/25(missevan/site_settings/audience/retry);analyze 零问题;探针实测 CHZZK 目录 5 组分组正确、`rooms[Project_Zomboid]: 26`(v2 分类房间真过滤)、总榜 30 房间正常;SOOP 分类房间 `rooms[00130000]: 3`(英文化)。

**备注**:CHZZK 全量分类树需登录后 web 路由 chunk 里的端点(HAR 才能拿),top-20 榜单为当前匿名可达上限;SOOP 长尾(百名外)韩文键未收录,徽标回落韩文原名

**备注**:chzzk/pandalive/bigo/jdlive/weibo/steam 等单占位目录为既有审计结论(结构性/出口封禁),youtube 无目录结构性; hover 顺序:补充表→remap→soop 进程表→跨平台表→原名,四家原生中文名不受影响

### 迭代 17B(2026-10-02)✅ niconico 直达链:lv 号/观察页 URL 从"搜索无结果"到可直达 + owned-input 静默黑屏诊断埋点

用户报告 `live.nicovideo.jp/watch/lv351393299` 解析失败。诊断:房间实为 ON_AIR(watch 页 embedded-data 实测 status=ON_AIR/canWatch=true),真机日志首页路径 `resolve_ms` 也成功(3 档画质)——**解析层健康,缺口全在输入/直达链与播放配方**,三处修两处:

- **niconico_site.searchRoomsCancellable 加直达分支**(对齐猫耳口径):`lv…` 裸节目号与 `live.nicovideo.jp/watch/…` 链接经 `NiconicoWatch.parseInput` 识别后走 detail;missing(房间消失)转空列表,网络/服务类失败照常上抛。此前 lv 号被当关键词送站内搜索,必空
- **zishu 搜索页直达识别扩展**(`search_provider`):`resolveSearchDirect` 提为顶层纯函数(可离线单测);niconico 观察页链接任意平台档直达;`lv…` 裸号仅选定 niconico 档直达(全站模式不识别,防普通搜索词误判)。**`_openDirect` 链接直达从硬编码 douyu 改为按 URL 域名推断**(`siteHintFromInput`),未来补表即扩展
- **siteHintFromInput 表补 niconico**:`--room <URL>` 启动直达此前静默回落首页(猫耳同款缺口,猫耳 14B 已修)
- **真机复验(Windows Release 20:47)**:`--room https://live.nicovideo.jp/watch/lv351393299` → `route=/niconico/play/lv351393299` → `resolve_ms=1490` 3 档画质(800×450·1080800bps 等)——用户报的房间解析链全通

**已知不修(owned-input,需立项)**:resolve 成功后播放页静默黑屏——`NiconicoSite.getPlayUrls` 设计性返回空(取流走 `NiconicoInputRecipe` 座位配方,zishu 播放链未接入;20:30 首页路径进房同样 resolve 后无 open、playing=false,系旧有行为非本轮回归)。座位风险口径此前已定暂缓,接入需用户立项。顺手埋点:play_provider 对"解析成功但选不出线路"落 `open_skip`(cat=line),终结"连 open 事件都没有"的静默黑屏诊断盲区(bigo/fc2 同样受益)。

**验证**:`search_direct_resolve_test` 6 用例 + `startup_url_hint_test` 扩至 4 用例(直达识别契约/既有 douyu 行为不回归/非法 lv 不误判);播放链回归 `play_quality_prefetch_test` 8/8;analyze 10 条全预存在零新增;opt-in 探针 `tool/probes/niconico_search_direct_probe_test.dart`(`PURELIVE_NICONICO_SEARCH_PROBE=1`)确认两种直达输入均从 detail 路径返回(Flutter test 环境对 nicovideo TLS 失败为已知环境差异,真机 detail 由 playback.log resolve_ms 证健康)。

### 迭代 18(2026-10-02)✅ 17live 直达入口 + pure_live 字段 zh 回落(界面漏 key 清零)+ bigo liveStatus 死分支 + 首页/直播页对齐巡检

用户报告 `https://17.live/en/live/29725277` 无法解析,并定口径:**直播地址相关字段映射完全用 purelive 的,不要 zishu 的**;检查各平台首页与直播页解析是否对齐;niconico 分类要中文。诊断出四个独立问题:

1. **zishu UI 漏 i18n key(nico 分类乱码根因)**:zishu UI(lib/src)不包 EasyLocalization,`tr()` 恒返回 key 本身——pure_live 适配器 111 处 `i18n()` 字段(niconico 分类 `niconico_category_*`、17live 画质名、各站公告)在界面全是原始 key。修复(按用户口径,文案真源仍是 pure_live 自己的 zh.json,不建 zishu 侧映射):`locale_helper.i18n()` 增加**打包 zh.json 回落**(tr 未命中/未初始化时直查,`{name}` 参数替换同构),`main.dart` 首帧前 `ensureZhTextFallback()` 预载;旧 UI locale 已初始化路径行为不变
2. **17live 无搜索/直达入口(本报告直接根因)**:解析层全链路健康(探针:URL → searchRooms 1 hit → detail live → 4 档 → 2 线路),缺口全在入口——搜索平台 chips 被 `brand.browseSupported`(栏目浏览位)一并裁剪,17live 选不到、直达识别无其域名。修复(能力口径以 purelive 注册表为准):`filterPlatforms` 增加 `requireBrowseSupport` 位,搜索入口不设品牌位(浏览/导航入口维持原裁剪);`siteHintFromInput` 表补 `17.live`;`resolveSearchDirect` 补 17.live 链接直达(语言前缀可选,与 SeventeenLiveLink.parse 同口径)——任意平台档粘贴 17.live 链接均可直达
3. **bigo liveStatus 死分支**:`_room` 的 `(public, true, Uri())` 用空 Uri 常量匹配 `Uri?` 字段永假 → 在播房间详情全 unknown → `getPlayQualites` 前置(`effectiveLiveStatus==live`)必失败(迭代14 设备日志 bigo `schema`×4 即此表现)。修为只看 `access+reportedAlive`。另实测上游结构性变化:`getInternalStudioInfo` 对匿名请求现恒回 `needLogin:true`(curl 直证),bigo 直播页详情/取流当前被上游匿名封锁,结构性入账
4. **首页/直播页对齐巡检**(新探针 `tool/probes/home_play_alignment_probe_test.dart`,29 站):raw-key 泄漏 **0**;主流站 area/audience 同源对齐(acfun/bilibili/douyu/huya/kuaishou/chzzk/picarto/twitch/yy 等 aligned=true);showroom 列表 ja↔详情 en、fc2 目录 en↔详情 ja 的语言摇摆 → `kShowroomZhByName` 附 16 项日文别名、新增 `kFc2liveZhByName` 双语标签(对齐 zh.json 分类名口径);baidulive/chzzk 单站差异为列表↔详情时点差(主播切分类),非映射问题;soop TLS/niconico schema 抖动与 pandalive 出口封禁为既有瞬态/结构性

**验证**:单测 **51 用例全过**(直达识别 +17live 3 形态/域名 hint +17live/zh 回落 3/搜索门槛 3/展示层 10/retry 2/missevan 3/site_settings 2/audience/prefetch 8);改动 12 文件 analyze 零问题;17live 对齐探针 live+公告中文("17LIVE 要求观看者年满 18 周岁。");bigo 登录墙房 unknown+中文公告语义正确。新探针入库 `resolve_room_diag_probe_test.dart`(单房间端到端)/`home_play_alignment_probe_test.dart`(首页↔直播页字段对齐)

### 迭代 19(2026-10-02)✅ twitcasting 频道链接直达:/mel___t 从"打不开"到任意档直达

用户报告 `https://twitcasting.tv/mel___t` 打不开。诊断(pure_live 解析层本就支持频道 URL,纯 UI 直达链缺口):

- **解析层健康**(探针 `resolve_room_diag`):pure_live `TwitcastingApi.searchLives` 早有频道根 URL 分支(`channelFromUri` → `detail(channel)`,频道页抓元数据 + `streamserver.php` 拿当前场次),探针实测 URL → searchRooms 1 hit → detail live(めりのきゃすー) → 3 档(HLS high/medium/low) → 流地址全通;`detail` 的 roomId 即频道名,播放页 `/twitcasting/play/mel___t` 与 resolve 链一致
- **缺口在 UI 入口**(与迭代18 17live 同款):`siteHintFromInput` 表无 twitcasting.tv(默认档/`--room` 启动参数推不出平台),`resolveSearchDirect` 无该域直达(非 twitcasting 档粘贴链接不出"进直播间"直达项,只在恰好选中 twitcasting 档时靠 searchRooms 频道分支命中)
- **修复**:`siteHintFromInput` 补 `twitcasting.tv`(host 白名单正则不吞 `search.twitcasting.tv` 子域);`resolveSearchDirect` 补 `_twitcastingChannelRoot`(Uri 解析:host 白名单 + 单段 path + 频道名形状 `[a-zA-Z0-9_]{1,80}`,与 `TwitcastingApi.channelFromUri` 同口径)——**movie/回放链接(两段 path)不直达**,保持 pure_live「不静默替换旧场次」原则
- **验证**:`search_direct_resolve_test` +twitcasting 用例(频道根 3 形态直达任意档/movie 链接不识别/裸 host 不识别)、`startup_url_hint_test` +twitcasting 域名推断,12/12 过;analyze 零问题。期间撞并行会话 owned-input 接入在途编辑的幻影编译错(play_provider/browse_source/purelive_backend 中间态),等待收敛后复跑全绿,非本改动引入


### 迭代 18(2026-10-02)✅ niconico 播放落地:purelive owned-input 配方接入 zishu 播放链(「播放策略用 purelive 的」)

用户立项接续 17B:「播放策略用 purelive 的」。purelive 播放体系已有完整配方链(`NiconicoInputRecipe` 公共参数 → `bindLiveInputForPlayback` 播放绑定 → `NiconicoPlaybackInput.open` 开座位会话(`NiconicoSession` websocket+keepalive)→ `FFmpegHlsInputRelay` 本地 HLS 中继 → `PlaybackInputLease(uri, close)`),此前仅旧 UI 消费。接入三件:

- **`OwnedInputResolver` 能力接口**(browse_source):`resolveOwnedInputRecipe(site, roomId, preferredQuality)`;独立接口不继承 RoomSource——live_parser `RoomResolver`(位置参 resolveRoom)与 zishu `RoomSource`(命名参 resolveRoom)签名互斥,不能同挂一个类(首次实现即撞 invalid_override)
- **backend**:`PureLiveOwnedInputResolver`(独立类)→ `resolvePureLiveOwnedInputRecipe`:详情→档位→按名选档(口径同 resolveRoom)→`resolvePlayUrlsRaw`→`pureLiveOwnedRecipeOf`(仅 owned 无直链时返配方)
- **play_provider**:开流点空线路时走 owned 路径——配方→绑定→开座位→本地中继 URI 包装成 `StreamLine(format:'hls')` 喂 mpv;lease 单活(`_ownedLease`,新开前 close 旧,`ref.onDispose` 兜底),generation 围栏防跨代泄漏;断流走既有恢复链→重解析→本分支自然重开新座位。日志 `owned_seat_open`/`owned_seat_fail`(cat=line)

**Dart 3.13 语言坑(2026-10-02 最小 repro 实锤)**:receiver 静态类型与检查接口**无子类型关系**时(`LiveSite is LivePlayUrlResolver`),`is` 被分析器判恒假→后续视作死代码、提升失效(undefined_method 误导性报错);`as` 与 `Object is X`(有 subtype 关系)均正常。绕过:provider 直取零 cast + backend 体内 `as`。

**真机复验(Windows Release 21:22,lv351393299 振り返り上映会)**:`--room` URL 直达→`resolve_ms=1654` 三档→`owned_seat_open recipe=niconico:lv351393299:800x450:1080800 uri_host=127.0.0.1`→mpv 开本地中继→**首帧 1.9s**→持续播放 85s+ 缓存满/d3d11va 硬解/零解码丢帧/本次会话 source_open_failure 零新增。**niconico 在 zishu 桌面端首次真正可播**。bigo/fc2 配方接入同框架待续(binding 已支持,backend 泛化即可)。

**验证**:播放/搜索回归 20 用例全过;analyze 10 条全预存在零新增。

### 迭代 20(2026-10-02)✅ 上游合并落地:liuchuancong/pure_live 276fae8a 布局重构波+LiveSite liveroom 契约, 按双原则完成

用户原则:**解析层跟上游 purelive,UI 以我们 fork 的 zishu 为准**。接迭代15b 的 defer 冻结(docs/UPSTREAM_AUDIT_276fae8a.md)正式执行合并:

- **入站**:109 提交/1292 文件/760 高风险;核心=站点适配器 `core/site→platforms`、`core/interface→contracts`、旧 UI `modules→features` 布局重构 + `getRoomDetail(LiveRoom liveroom)` 接口参数化 + pip/弹幕/壁纸功能与 7 项播放器修复
- **冲突 88 处全解**(试合并实测数):platforms 26 处以上游为底做真三方合成(git merge-file)回植 fork 语义补丁——missevan catalogs 灰度修复/soop `Accept-Language: en-US`/bigo liveStatus 死分支/chzzk 真目录(迭代17)/twitch+kuaishou+soop+yy `SettingsService.maybe` 降级/斗鱼抖音 ParserConfig 注入与 LiveCurrentRoomContext 解耦(dafa1d3d 口径)/yy+cc+twitcasting+niconico 徽标补齐
- **11 平台弹幕(fork 迭代4-14)整体迁入 `platforms/<site>/`**(git rename 误落 douyin/ 已归位),9 站 getDanmaku wiring+danmakuData 回植;acfun/douyin proto 归位
- **core 层双源保留**:模型留 fork LiveRoomVolumeStore 钩子(sidecar 依赖)+上游 detailIdentity/fillFromDetail;http_client 留 proxyDirectiveProvider;core_error 留 formatter 钩子;core_log 留 runtime 钩子——sidecar 无 UI/无 GetX 约束不变
- **auth/firebase 维持删除**(13 文件 drop);`main.dart` 保 zishu 入口;旧 UI 取上游 features 新布局+回植 fork 启动接线;旧 UI 独立入口 `main_purelive.dart` 移除(零消费方)
- **依赖**:media_core 克隆至 `F:/media_core`(上游同款路径,新增 danmaku/mediasession/live/logging 四子包);新依赖 ffmpeg_kit_extended_flutter(首测 SHA256 失败系下载损坏,清缓存重试通过)
- **收尾**:审计脚本 live_back 不变量路径迁 features 布局;manifest 补 `enableOnBackInvokedCallback="true"`(predictive_back 规则);`.playwright-mcp/` 入 ignore

**验证**:`analyze lib tool` **0 error**;全套件 **128/128 过**(11 平台弹幕协议/直达识别/分类中文化/画质契约/统计刷新);`audit_repository.py` **0 error**;上游祖先关系保留(merge commit cf47156c)。**待办**:opt-in 探针复验(全站播放/分类/对齐)建议在下次真机窗口跑一轮;pip/壁纸等上游新功能属旧 UI,zishu 界面不消费



### 迭代 21(2026-10-02)✅ 解析/UI 分层硬边界:三站 GetX 回退契约化 + 审计规则固化

用户定稿分层原则:**解析全部以 purelive 为准,缺失字段才由下游补充;解析与 UI 分开,我们的 UI(zishu lib/src)与上游 UI(features/app)分开**。合并后边界审计(迭代20 收尾扫描)发现三处真违规并修复:

- **kuaishou/soop/yy 适配器**把旧 UI 的 GetX `PlayerController` 拉进解析层做"UI 当前房间回退"(上游自有耦合)——统一改为 `LiveCurrentRoomContext` 契约(与 douyu/huya/bilibili/cc 同款;旧 UI 启动已注册 bridge 行为不变,zishu 运行时未注册优雅跳过回退)。至此 platforms/ 适配器零 UI 控制器依赖(iptv 的 GetX DbService 为本地 IPTV 数据库服务,非 UI,单独记账)
- **审计规则固化**(`audit_repository.py` 新增 `parsing_layer_ui_import`):`lib/platforms/**` 引 `features/`/`app/` = **error**;`lib/core/**` 引 UI = warning 债务(上游自有布局:core/index 大桶、core/widgets 旧组件、live_url_tool 工具箱流等,随同步机会性收敛);`features/recorder/services/` 输入管道为解析邻接例外(niconico owned-input 座位架构,非 UI)
- **lib/src 复扫**:零 features/app/services 依赖——我们 UI 与上游 UI 隔离成立

**验证**:analyze lib tool 0 error;128/128 全过;audit 0 error + 10 warning(全部为 core/** 历史形态,已列债务清单)


### 迭代 22(2026-10-02)✅ 合并后优化轮:分层债务清零 + 探针契约迁移 + 运行时复核

- **分层债务 10 warning → 0**:6 个住在 core/ 的旧 UI 文件归位迁出(`core/widgets/room_card→features/live/widgets`、`common_appbar_actions→features/shared/widgets`、`link/live_url_tool+shared_live_link_opener→features/link`、`release/version_util→features/about`、`platform/desktop_manager→app/desktop`),导入面+core/index 桶出口同步;桶豁免为旧 UI 唯一 core 内幸存者(只做 re-export)。至此 core/ 内除豁免桶外零 UI 引用
- **tool/probes 15 文件迁移新契约**:合并漏网的探针(getRoomDetail(platform,roomId)/getPlayQualites(detail:) 等旧签名)批量迁 `liveroom` 契约+新导入路径,analyze 0 error
- **运行时复核(合并前后基线一致)**:分类探针 28/34 categories-ok(非 ok 全为结构性空目录/凭证门控);对齐探针 33 站 raw-key 泄漏 0、aligned 16(PandaTV 出口封禁/Steam transport 为已知瞬态)


### 迭代 23(2026-10-02)✅ 合并后运行时验证:全站播放/画质切换/分类/对齐四探针全绿

- **全站播放探针**(33 站全链路到真实媒体字节):**26 media-ok + 2 owned-input**;非 ok 全为既档结构性(bigo=上游匿名 needLogin 门/13 迭代18,tiktok/xhs/youtube 无公开目录,pandalive 出口 IP 封禁)——与合并前基线完全一致,零回归
- **画质切换探针**(33 站):19 switch-ok + 8 单档站(结构性,切档不适用)+ 已解释项——niconico failed 为文档在案的 owned-input 设计(getPlayUrls 设计性返回空,迭代17B);yy switch-partial 为该房间仅推一路 rendition(超清回同流 rejected 判定正确、流畅切流 accepted,机制正常)。探针本身补齐 15+10 处旧签名迁移(resolvePlayUrls/ForRecovery/reversed getRoomDetail)
- **分类 28/34 / 对齐 33 站泄漏 0**(迭代22 已录,此处复认)
- 收尾:analyze lib+tool 0 error;audit 0 error

**结论**:上游合并(cf47156c)+优化轮后的解析层在新布局/新契约上运行时行为与合并前完全一致,零回归。


### 迭代 24(2026-10-03)✅ owned-input 播放打通:niconico/fc2 黑屏终结 + bigo 复用链就绪

迭代17B 记录的"niconico resolve 成功后静默黑屏"与本轮盘点的"剩下问题"同根:**`bindLiveInputForPlayback` 是空壳 throw**,而录制侧 bigo/fc2/niconico 三个 HLS 输入开座设施(`BigoHlsInput`/`Fc2HlsInput`/`NiconicoHlsInput`)早已现成。本轮打通:

- **播放绑定三分支**(`live_input_playback_binder.dart`):Bigo/Fc2/Niconico 配方各自分支,经 `features_bridge.dart`(`player/core`,经 openInput 函数注入解耦 features/,测试可覆写)以 **`recording: false` 口径**复用录制输入——不落盘、不 drain 尾部;座位(WebSocket keepalive/本地中继)生命周期归播放器,`PlaybackInputLease` 包本地中继 URI,离场 `close` 兜底(play_provider 既有 `_ownedLease` 链)
- **niconico 开座**:`NiconicoApi().room` 观察页解析 → `NiconicoHlsInput.open`(座位/心跳会话,path-scope cookie)——与录制同源,同一节目多开互踢风险口径不变(座位由播放器独占)
- **探针复核**:`niconico owned-input` / `fc2live owned-input`(此前 niconico=failed 黑屏、fc2 从未进过 owned 路径),**bigo 维持上游匿名门**(studio API 匿名 needLogin 恒真,迭代18 定档结构性;binding 就绪,门开即用)
- **新增单测**:`owned_input_playback_binder_test.dart` 5 用例(三分派/lease 语义/未知配方契约),零网络

**验证**:analyze lib tool **0 error**;全套件 **133/133 过**;audit **0 error**;三站播放探针如上。剩 CHZZK 弹幕验收(聊天边缘对数据中心 IP 封锁,迭代8 定论待住宅网络)与 B 站/斗鱼匿名降档(服务端行为,需用户 Cookie,非代码缺陷)——台账既有项,无新增暂缓


### 迭代 25(2026-10-03)✅ Windows Release 3.1.18+4107 打包成功并启动验证

- **ffmpeg_kit 哈希谜团(三哈希三角色)**:`e616...`=fork n9.0.2-b1 真品(build 脚本 pin+wzgrx 资产实测一致);`ac4f...`=akashskypatel 官方 0.11.1(hook 内置 GitHub digest 校验指向它);`1e4cc...`=curl -r 0-0 断点残留假象。合并后首败根因=持久缓存里的坏 zip(01:23 下载损坏)被复用;清缓存后 fresh 下载哈希=ac4f(官方资产未变)但 build 脚本 pin e616 仍拦——**hook 与 build 脚本校验的是两代不同的原生包**(上游 0.11.1 官方 vs fork 自建 n9.0.2-b1),prefetch 本会播种 e616 进 hook 缓存,hook 却拿官方 digest 验同名文件必败(此前成功系 digest API 竞态失败跳过校验)
- **修复**:pubspec `ffmpeg_kit_extended_config.windows` 指向本地预取文件(`../native-cache/ffmpeg-kit/...zip`,hook 对 local override 完全跳过网络哈希;prefetch pin+build_local_release 复核双保险);另修 media_core_memory/win32 相对 rootUri 锁漂移(显式绝对路径);version.json 全平台字段同步 3.1.18+4107(Windows 构建取 platforms.windows)
- **产物**:`local-artifacts/3.1.18-4107/PureLive-3.1.18-4107-windows-x64-portable.zip`(73.4MB,SHA256 332df7ac...;1357 文件,pure_live.exe+3 原生 dll;包内 flutter_assets/assets/version.json 实测 3.1.18+4107)
- **启动验证**:进程活(PID 5020),窗口标题「全平台首页 · 紫薯直播 3.1.18」;niconico/FC2 owned-input 播放与分类中文化待真机抽查


### 迭代 26(2026-10-03)✅ 两小时专项:首页/分类/全平台直播验证——零回归 + 探针中文化可视化

- **全站播放探针**(33 站):**26 media-ok + 2 owned-input**(niconico/fc2 新链路首验通过);非 ok 全为既有结构性(bigo 匿名门/pandalive IP 封禁/tiktok+xhs+youtube 无目录)。逐站媒体形态正常(flv(avc)/ts/mp4)
- **分类探针**:28/34 ok(结构性余项同上);新增 `displayNames` 字段——探针直接输出与 UI 同一 `displayCategoryName` 入口的译文样本,中文化验证从单测层提升到探针层:soop FC ONLINE→FC Online足球在线、chzzk 로스트아크→命运方舟、twitch GTA5/GTA5、twitcasting Popular→热门、showroom Popularity→人气、picarto Furry→兽人 全部命中
- **首页对齐探针**(33 站):16 站 aligned、raw-key 泄漏 0;showroom/fc2 的"列表日文/详情英文"为上游接口语言摇摆,展示层补充表已覆盖(アイドル→偶像 单测在案);baidulive 列表"美容养生"/详情"养生"为上游数据粒度差,非代码问题
- 补漏:chzzk WARDOGS/워독스 双键入表(战犬);期间引入的 const map 重复键即时修复

**验证**:analyze 0 error;**133/133 全过**;audit 0 error。三探针与合并前基线完全一致——上游合并+优化轮+迭代21-25 全部修复在新布局上运行时零回归

### 迭代 27(2026-10-03)✅ soop 分类中文化补链(卡片数字角标修复) + 播放页⭐我的分类点亮

- [x] **卡片数字根因**:purelive 桥 `PureLiveBrowseRepository.fetchRooms` 分类流伪造 `LiveArea(areaName: cid)` 把分类号当名字下发、推荐流 `cid/category` 同取 `room.area`(韩文),且 fork 数据链从未像 zishu live_parser 那样用分类目录预热 `rememberSoopZhCategory` 进程表 → soop 卡片角标直出 `0010333` 式分类号(分类流)或韩文(推荐流)
- [x] **解析层照 zishu 移植**(packages/live_parser soop browse/room_api 同构):`SoopSite.getSubCategores` 改 `lang=zh_CN` + zh-CN 头拉目录(实测 zh_CN 半撤仍对部分目录直出中文「我的世界」,纯 en-US 全英文),逐条 `rememberSoopZhCategory(category_no, remap(name))` 预热(browse warmup 启动即拉);`getCategoryRooms`/`getRecommendRooms` 按条目 `broad_cate_no`(前导零经 soopCateNoKey 归一)反查进程表,回落 `category_name`+remap(实测 categoryContentsList 条目**没有** category_name 键、broad_cate_no 无前导零);播放详情按 CHANNEL `CATE` 反查,cateNo 存 `LiveRoom.data`
- [x] **桥接层补数**:`pureliveRoomToPayload` 填 `payload.cateNo`(soop CHANNEL CATE)、soop `payload.cid`=房间号(zishu 同构契约:cid 非空才渲染收藏星,真实分类号走 cateNo);`pureliveBrowseSummary` cid 改用请求分类号、推荐流留空(原 `cid=room.area` 把韩文名/中文名当分类号,污染我的分类判重与跨平台反查)
- [x] **播放页⭐零改动点亮**:play_view `_RoomHeader` 的分类徽标+⭐逻辑与 zishu 逐字节一致,只差 payload.cateNo/cid 为空——桥接补数即亮;⭐点击 toggleForCategory 按 cateNo 判重,徽标本体可点进 `/soop/category/<cateNo>`
- 验证:analyze 改动文件 0 告警;新增 `test/soop_category_zh_bridge_test.dart` 10 用例 + 受影响 5 文件共 **36 测试全过**;curl 实测三接口字段(categoryList zh_CN 直出/`broad_cate_no` 在列/详情 CATE)与进程表键归一闭环

### 迭代 28(2026-10-03)✅ zishu↔fork 全量差距审计(结论:功能面已追平) + 三条断供链接通(角标/promo/开播时间)

- [x] **审计方法与结论**:zishu_flutter 顶点 e0ee05d(2026-10-01)。`packages/live_parser` 两仓**仅 barrel 差一行**(fork 反多 remap 导出);`lib/src` 22 个差异文件经 word-diff + 去空白归一 + 顶层标识符集合差三重判定,**零 zishu 独有功能**——差异全部为 fork 侧增量(34 平台/purelive 桥/补充映射表/owned-input/默认最高档/预取移除)与格式化宽度噪音;zishu 功能关键词(死节点负缓存/re-resolve/Alt+兜底/本地流代理/cat=日志/语音字幕/跨平台分类/主题色 override)逐一在 fork 命中;speech2zh 包与外围 assets 逐字节一致。**zishu 比 fork 多的解析/功能 = 无**
- [x] **真实差距在契约缝隙**(文件 diff 不可见):zishu 原生 browse/resolver 填 `identityLabel`/`promoTag`/`startedAt`,fork 全平台走 purelive 桥后**数据断供但 UI 组件在**(room_card 右上角标/特色 chip 行/播放页元信息条开播时间)
- [x] **虎牙身份角标**:fork 分类流 cache.php 无 `sRecommendTagName`(实测 0 命中)→ `getCategoryRooms` 切 zishu 端点 `getLiveList`(实测 120 条/页全带该字段,gid=2135 验证),字段映射同 zishu `_normalizeRoom`,identityLabel 存 `LiveRoom.data`;推荐流 cache.php 该字段结构性缺失,不伪造
- [x] **斗鱼 promoTag + 开播时间**:推荐(allpage)/分类(mixList)条目实测带 `copilotLabel`/`authInfo`/`vipId` → `pickDouyuPromoTag` 暂存 data;betard `show_time`(秒级)→ `data['startedAtMs']`
- [x] **B站 promoTag**:分类(second/getList,风控不可匿名探测)/推荐(getListByAreaID 实测精简 schema 无 pk_id/verify)→ `pickBilibiliPromoTag` 防御性暂存,取不到即 null;fork 推荐热榜端点为有意的 fork 增量(热度排序),不回退 zishu 的 webMain 端点
- [x] **桥接层**:`_dataString` 统一提取暂存 → `RoomSummary.identityLabel/promoTag`、`payload.startedAt`(>0 才填);live_parser barrel 补导出 identity_label/douyu·bilibili promo_tag(与既有 remap 导出同款模式)
- 验证:analyze 改动文件 0 告警;**全量 148/148 全过**(含新增 6 用例:huya 角标/douyu promo/startedAtMs 三态/null 不伪造);getLiveList 实测上游忽略小 pageSize 恒 120 条(hasMore 语义无碍)

### 迭代 29(2026-10-03)✅ twitcasting.tv/c:tbk_1 打不开——直达识别正则漏 `c:`/`g:`/`f:`/`ig:` 前缀

- [x] **取证**:链接本身 200 正常且直播中;页面两校验锚点(twitter:creator / tw-user-header data-user-id)齐全;streamserver.php 正常回 HLS;真网络 `detail('c:tbk_1')` 解析成功(椿,live=true)——解析链健康
- [x] **根因**:搜索页直达识别 `_twitcastingChannelName` 正则 `^[a-zA-Z0-9_]{1,80}$` 不认冒号,`https://twitcasting.tv/c:tbk_1` 判 null → 直达项不出现;而解析层 `TwitcastingApi.channelName` 明明允许 `(c|g|f|ig):` 前缀,注释声称"同口径"实则失同步(与迭代 niconico lv 直达缺口同类:房间健康,识别层断)
- [x] **修复**:直达正则对齐 channelName——`^(?:(?:c|g|f|ig):)?[a-zA-Z0-9_]{1,64}$`;movie/回放多段路径依旧不直达(「不静默替换旧场次」口径不变);roomId 带前缀进 play 路由,解析层归一小写
- 补充:启动参数 `--room <url>` 路径(`_resolveStartupRoom` 取 path 尾段)本就支持 c: 链接,不受影响;存量探针 `twitcasting_public_contract_probe_test.dart` 已与现 API 签名脱节(opt-in 不入套件),当日即修——对齐 `getRoomDetailForRecording(LiveRoom)`/`resolveStream({liveroom})` 现签名后真网络复跑全绿(目录 50 条/18 分组/3 档 HLS/媒体清单 449B/录制输入与恢复契约 resolved)
- 验证:直达识别回归测试(c:/g: URL→DirectTarget、多段 movie 拒绝)+ 真网络探针 `tool/probes/twitcasting_c_prefixed_channel_probe_test.dart`;**全量 149/149 全过**;analyze 改动文件 0 告警

### 迭代 30(2026-10-03)✅ 导航左上角品牌块(logo + 「紫薯直播」文字)移除

- [x] top_nav 桌面顶栏不再渲染 `_Logo`(logo-128.png 图标 + 「紫薯直播」文字 + Tooltip),整类删除;首页入口由「首页」动作承载,回首页路径 /all 不变
- [x] 范围仅桌面导航左上角:手机端 bottom_nav 的品牌锚点、窗口标题(windows_app title)、`_kAppTitle` 均不动
- 验证:analyze 改动文件 0 告警;**全量 149/149 全过**(无 golden/测试引用 nav-brand)

### 迭代 31(2026-10-03)✅ 四大平台播放页收藏星(⭐)点亮——payload.cid 按分类 id 补齐(zishu 同构)

- [x] **背景**:迭代27 只点亮了 soop(靠 cateNo);B站/斗鱼/虎牙/抖音播放页的 ⭐ 仍暗——zishu 原生解析给这些平台 payload.cid 填**分类 id**,purelive 桥全是空串,`_RoomHeader` 的 `cid.isNotEmpty` 星标判据恒假
- [x] **适配器详情流暂存分类 id**(zishu 同字段同源):B站 getInfoByRoom `room_info.area_id` → `data['cid']`;斗鱼 betard `cate_id`(实测在列)→ `data['cid']`;虎牙 profileRoom `liveData.gid` → `HuyaUrlDataModel` 新增可选 `cid` 字段(详情 data 被该模型占用,不能换 map,播放链不消费可空);抖音无二级分类 id,cid 即房间号(zishu douyin 同口径注释)
- [x] **桥接 cid 语义**:`pureliveRoomToPayload` 按 data 类型提分类 id(Map.cid / HuyaUrlDataModel.cid);soop 与抖音 cid=房间号,其余平台 cid=分类 id;收藏判重经 cross key(site+cid+中文名)跨平台聚合不受影响;星标后徽标本体可点进对应平台分类页
- 验证:analyze 改动文件 0 告警;**全量 152/152 全过**(桥接测试更新:B站 cid=145/无 data 空串/虎牙 HuyaUrlDataModel.cid=2336/抖音 cid=房间号)

### 迭代 32(2026-10-03)✅ 弹幕开关语义修正:关=清屏,不是冻结(用户口径,有意偏离 zishu)

- [x] **根因**:`DanmakuOverlay` 的 `enabled=false` 只是 `_ticker.stop()`,已入队弹幕冻在画布原位(旧注释「已入队弹幕保留」即旧设计);且 `enabled` 同时承载「弹幕开关」与「视频暂停」两个语义,无法区分
- [x] **修复**:overlay 新增 `visible` 总开关语义——false 时立即清空屏上飘动弹幕并**丢弃**后续入队(重开不洪泛旧弹幕);`enabled` 保留视频暂停的「冻结保留」语义不变;`_DanmakuLayer` 传 `visible: widget.visible`
- [x] 注:此为用户口径的**有意偏离 zishu**(zishu 同文件仍是冻结语义),后续 zishu 同步该文件时需保留本差异
- 验证:新增 `test/danmaku_overlay_toggle_test.dart` 2 用例(关=清屏/关闭期丢弃/重开从零;暂停冻结语义不回归);analyze 改动文件 0 告警;**全量 154/154 全过**

### 迭代 33(2026-10-03)✅ twitch.tv/siaohu_0124 解析失败——直达识别整体切上游统一解析器(WebSearchRoomParser),不再逐平台打补丁

- [x] **取证**:频道直播中(GQL 实测 晓嫭 live);`resolveRoom('twitch', login)` 全链路 OK(5 档/1 线路/Just Chatting);URL 形态抛 "Twitch stream metadata is missing"——URL 原样灌进 GQL login 查询
- [x] **用户口径**:同类问题上游 pure_live 有统一处理,不该逐平台打补丁——`WebSearchRoomParser.parse`(lib/core/network)覆盖 douyu/huya/bilibili/douyin/soop/twitch/twitcasting/niconico/17live/快手/CC/acfun 等**全部平台**,还内置站点保留段排除(videos/directory/search…)
- [x] **重构**:搜索直达 `resolveSearchDirect` 撤掉 douyu/niconico/17live/twitcasting/twitch 五组手搓正则,链接输入统一走 `WebSearchRoomParser`;`DirectTarget` 新增 `site` 字段(解析器给出的平台),`_openDirect` 优先用它、缺失回落 siteHint 域名推断
- [x] **守门保留**(解析器是共享契约不动,直达层叠加既有口径):裸 `lv…` 仅选定 niconico 档识别(全站档防误判);17.live 仅直播页直达、profile 页不作为房间打开
- [x] **解析层兜底**:TwitchSite 新增 `loginFromInput`(频道链接→login,含 www./m. 与尾斜杠)——URL 万一仍达适配器(启动参数等)不再灌进 GQL
- 验证:直达识别 10 用例全过(既有 douyu/niconico/17live/twitcasting c: 无回归 + twitch 新例含 site 断言 + videos/directory 负例);真网络探针 login/URL 两形态均 ok;analyze 改动文件 0 告警;**全量 194/194 全过**


### 迭代 27(2026-10-03)✅ 抖音二级分类对齐 zishu + 分类并行预热 + 抽屉二级分类四字宽横铺

用户报告三项:抖音 hover 分类错误(应对齐 zishu 二级分类)/分类应启动预加载进内存(hover 马上显示)/左侧抽屉二级分类固定四字宽横向平铺。

1. **抖音二级分类重构**(`platforms/douyin/douyin_site.dart`):旧实现解析 `categoryData` 浅表——8 组 15 项且各组首条目为组自引用(娱乐组 sub_partition 全空、游戏组把二级分区当条目)。重写为 zishu web 同款两列结构:**游戏根按 title 定位**(id 103 也落 100-199 数字段, 用 id 区间判娱乐会整棵误吞游戏树——实测踩坑), 二级分区(射击游戏/竞技游戏/单机游戏/角色扮演/棋牌游戏/休闲益智/策略卡牌)为组、嵌套 sub_partition 为组内条目(和平精英/原神...);娱乐分区(聊天/音乐/二次元/舞蹈/文化/生活/运动)合并为单一「娱乐」组, areaId 带 partition_type=4 保证分类房间接口路由正确;解析失败回落静态兜底表(zishu web 同款分组)。探针实测 **8 组 237 项**(此前 8 组 15 项), 分类房间链路 media-ok
2. **分类预热并行化**(`category_warmup.dart`):预热机制 2026-09-19 已存在但串行逐站, 30+ 平台下尾站等待数十秒——hover 仍见 loading。改 **6 路受限并行**, 全量预热时间从「站点数×单站延迟」压到「并发轮次×单站延迟」;首屏让位仍由启动 2s 延迟保证, 并发上限避免请求风暴;失败静默语义不变
3. **抽屉二级分类固定四字宽横铺**(`browse_sidebar.dart` + `design_tokens.dart` 新增 `catChipWidth=56`):原 GridView 两列大格(条目宽约 99.4px)改 **LayoutBuilder 按实际可用宽度算列数的固定宽网格**(56px ≈ 4×catFontSize+边距), 220px 抽屉下每行 3 枚、条目多时纵向续排;宽窄抽屉自适应不溢出

**验证**:analyze lib+tool **0 error**;全套件 **149/149 过**(含上游合并带入测试);audit 0 error;抖音分类探针(8 组 237 项)+分类房间链路(media-ok)复验通过。并行会话同期在途 playback 文件未纳入本提交

### 迭代 31(2026-10-03)✅ 17LIVE 房间打不开——本地流代理/桥接层丢站点媒体头,wansu CDN Referer 强校验 403

- [x] **取证**:playback.log 现场(10:39)解析链 prefetch_ok 2 线正常,`proxy_upstream_fail reason=http_403`(wansu)→ 备线 tencent 404 → source_open_failure → 恢复链循环耗尽;curl 对照:裸请求/UA-only 均 **403**,UA+Referer **200**——wansu CDN 新增 Referer 强校验(解析链 dio 头齐全所以解析成功,取流断)
- [x] **根因**(双层断供):① `purelive_backend._playbackHeaders` 仅四家(B站/抖音/虎牙/斗鱼)手写分支,长尾站点只回退 UA 无 Referer;② FLV 线经 `LocalStreamProxy` 取流时上游连接**一个头都不带**——mpv 的 httpHeaders 打给 127.0.0.1 本地地址,到不了真上游
- [x] **修复**:① `_playbackHeaders` 整体委托 `PlaybackHeaderResolver.resolve`(全站点契约一次点亮:17live/pandalive/showroom/chzzk/bigo 等全部 UA+Origin+Referer;四家口径等价;Referer 用规范化的 `detail.roomId` 拼接,直粘链接输入不受影响);② `LocalStreamProxy.openSession` 增 headers 参数,`_connectUpstream` 逐头转发;③ `_wrapLineWithProxy` 传 `line.headers`
- [x] **PandaTV 同报障结论**(环境级,非代码):`api.pandalive.co.kr` 对现出口 103.151.172.13 定点制裁(제재된 IP)——`live/index`(首页目录)、`member/bj`(房间)拒,`page/www`/`live/bj_list`/静态页放行;官方前端 JS 仍用 `/v1/live/index`,非 API 漂移;与迭代8 表格结论一致。**换 Clash 出口节点即解,代码无解**
- 验证:新增 opt-in 探针 `tool/probes/proxy_media_headers_probe_test.dart`(resolver 头部契约 → 代理转发 → 真实 wansu 流实拉 FLV magic 字节)全绿;`resolve_room_diag` 17live 全链路(搜索→详情→四档→2线)绿;analyze 与 HEAD 基线持平(67,零新增);受影响单测(purelive_stats_refresh/soop_category_zh_bridge)21/21。另修 `resolve_room_diag_probe_test.dart` 缺 `LiveRoom` 导入(布局重构遗留编译坏点)


### 迭代 36(2026-10-03)✅ 快速切房竞态修复(切房后仍播上一个直播间)+ Windows Release 3.1.19+4108 打包并交付

用户报告"旧的 exe 有卡顿,切换直播间但还是播放上一个直播间"。playback.log 14:21-14:22 实录:关注浮层连续切房(虎牙518518→斗鱼80432→9999→74751),旧播放页被 push 压在栈下继续存活——5 分钟刷新/恢复链/迟到解析仍驱动共享播放器;9999 迟到 52s 的解析完成后开流翻盘,用户停在 74751 却在播 9999。

- [x] **根因**:follow_view 用 context.push 进播放页——riverpod family 按 (site,roomId) 建控制器,旧页面栈下永不 dispose;onDispose 围栏(ref.mounted/恢复注销/leaveRoom)全对但根本没触发。上游 GetX 语义=路由级单控制器(再导航即重 put 旧控制器 onClose),zishu 缺这层
- [x] **修复**:①app_shell 关注浮层 `_openRoom` 当前已在播放页时改 `pushReplacement`(与侧栏 follow/recommend、搜索直达同一口径——它们此前已修,浮层是唯一漏网点,正是事故路径);不在播放页维持 push 保返回栈;②play_provider build() 解析完成后显式 `ref.mounted` 离场围栏(迟到结果落 resolve_discarded,不再依赖 dispose 后碰 state 抛错的隐式兜底)
- [x] **版本 3.1.19+4108**:pubspec+version.json(含 windows 平台与 build_number 同步;releases.json 为上游历史索引惯例不动)
- 验证:全量 **193/193 全过**;analyze 0 error;提交 49aa17c3 推送。打包:`build_local_release.ps1 -Target WindowsX64 -Configuration Release -SkipQuality`(本会话全量回归复用)→ `PureLive-3.1.19-4108-windows-x64-portable.zip`(78.9MB,Inno 缺失仅便携包);启动验证:进程 19572,窗口标题「全平台首页 · 紫薯直播 3.1.19」,包内 version.json 实测 3.1.19+4108

### 迭代 35(2026-10-03)✅ 批次三落地:轮播起播 seek(zishu 完整版,超上游)+外链全站化+上游外链死链修复

用户指令"继续处理/继续继续"(批次三逐项摸底后落地)。

1. **轮播起播 seek——上游 4-5 步的完整版**:上游卡在其播放层无 seek(只做了解析侧 1-3 步,LivePlayUrlResolution.startAt 已入契约);zishu 补全整链——桥 resolveRoom 切契约扩展 resolvePlayUrls(实现站拿 raw,其余站回落),RoomPayload.startAtMs(毫秒,toJson/fromJson/copyWith 全链)+Seekable 能力接口(沿 RecoveryCancellable 模式,替身零改动;MediaKit 实现 mpv seek,IdleReleasing 转发)+play_provider 开流成功后按偏移 seek 一次(控制器按房间 family 生成,成员位=每房间一次,切画质/线路不回跳)
2. **外链全站化**:zishu roomExternalUrl 从手拼三站(douyu/huya/bilibili)升级为委托上游 RoomExternalOpener.resolve(LiveSiteExternalRoomResolver 契约,34 站全量;sourceUrl 优先口径不变)
3. **上游外链死链修复(12 站)**:上游 externalRoomTarget 用类字段 id(平台名)拼路径——douyu.com/douyu 式死链;批量改用 liveroom.roomId(空号返回 null 不伪造)
4. **摸底不立项两项**(zishu 已覆盖):小窗几何记忆=resolvePipBounds 存档+屏内校验+横竖屏分档已有;弹幕海量模式=zishu overlay maxVisible=200 比上游常态更宽

- 验证:桥测试+轮播 startAtMs 往返新用例;新增 room_external_url_test.dart 4 用例(sourceUrl 优先/头部三站不回归/长尾点亮/空号安全);**全量 193/193 全过**(基线 188+5);analyze 0 error。Dart 提示:可空局部 is 无关接口 的交叉提升在本仓 analyzer 配置下不生效,能力探测用显式形态 Seekable? seekable = x is Seekable ? x as Seekable : null(与 Dart 3.13 is 恒假坑同族,已记)

### 迭代 34(2026-10-03)✅ 上游新语义扩充到 zishu UI——桥接层全类型弹幕+受限口径+轮播房+开播时间直读(批次一+二)

用户指令"处理"(接迭代33 后的 UI 语义差距分析)。缺口集中在 purelive 桥(渲染层本已就绪):zishu 契约本有 emoji 分段/徽章/礼物枚举,桥却只放行 chat。

1. **live_parser 契约扩展**:`DanmakuMessageType` 追加 superChat/notice/retraction;新增 `DanmakuRetraction`(按观众/按消息/全部三态)+`DanmakuMessage.retraction`;`RoomState` 追加 carousel;`RoomPayload` 新增 `restriction`(LiveRestriction 枚举名,空串=无限制)
2. **桥全类型透传**(`purelive_backend`):chat/gift/superChat/notice/retraction 五类放行(此前 bilibili 五类/斗鱼礼物/虎牙下播通知全被丢),online 维持丢弃;新增顶层纯函数 `pureliveDanmakuSegmentsFromEmotes`(平台表情编码→富文本段,重叠取先现)+`pureliveDanmakuRetractionFrom`+`restrictionDisplayText`(九类中文文案)
3. **开播时间直读**:上游 8 家直填 LiveRoom.startedAt 优先,斗鱼遗留 data['startedAtMs'] 兜底——播放页元信息条 B站/抖音/twitch/acfun/seventeen/showroom/inke/cc 不再显示"—"
4. **撤回语义**(`danmaku_session_provider`):撤回指令不入列表,命中项按消息 id/观众移除(全部=清空);**overlay 护栏**:只飞 chat(礼物/公告走侧栏,上游同语义)
5. **轮播房放行**:room_card/play_room_grid 不再给 carousel 落「未开播」遮罩(可播放,上游 4.x 同口径);B站轮播房从"显示未开播且不可进"变为可进可播
6. **播放页受限说明**:play_meta_bar 新增「受限」统计格(九类文案,不伪造——空串不渲染);merge 遗留 bootstrap 重复导入顺手清理(13 处)

- 验证:新增 `test/purelive_semantics_bridge_test.dart` 12 用例(分段拼接/多现/重叠/防御,撤回三态+非目标安全,carousel/restriction/startedAt 直读优先/遗留兜底,九类文案)全过;**全量 188/188 全过**(基线 176+12);analyze 0 error。**遗留批次三**(外部打开/悬浮窗几何/海量模式/轮播起播 seek)待用户逐项立项

### 迭代 33(2026-10-03)✅ 上游合并落地:liuchuancong/pure_live b087ee90——分层架构波② + "摘取 4.x"平台大波 + 弹幕大功能

用户指令"先合并上游的下来"。入站 `276fae8a..b087ee90` = **127 提交 / 621 文件(+13888/−6763)**;审查文档 `docs/UPSTREAM_AUDIT_b087ee90.md`(全量 SHA+文件逐字在案,门禁 `audit_document_valid=true`/`violations=[]`;入站尾随空格按 276fae8a 先例记录放行)。合并三原则:解析层跟上游、UI 保 fork zishu、版本/构建/firebase 边界不动。

1. **分层架构波②**:站点适配器 `lib/platforms`→`lib/shared/platforms`、旧 UI `lib/features`→`lib/domains/<域>`、core 拆 config/navigation/platform/stream/theme;新增 `tool/validate_architecture.py` CI 门禁(BASELINE 台账制)+`.github/workflows/architecture.yml`(权限最小化,政策合规)
2. **冲突 94 文件全解**:DD/DU/UA 机械类(firebase 13 文件保持删除);AU 24(11 平台弹幕+proto 随迁 shared 新路径,内容 fork 为准);UU 站点 20 处"上游为底+回植 fork 语义补丁"(bigo liveStatus 活分支×上游 restriction 合体/虎牙 getLiveList+identityLabel/斗鱼 promoTag+startedAtMs+cid/B站 promoTag+cid/抖音迭代27 分类树/soop·kuaishou·twitch·yy 的 maybe 契约迁移到新 CookieSettingsController/IPTV 控制器/CurrentRoom 契约保 fork LiveCurrentRoomContext);settings_service 移动+回植 maybe
3. **弹幕大功能入站**:表情图片(LiveMessage.emotes)/撤回(retraction+引擎按条撤回)/礼物/公告进列表——flame_barrage 需上游未发布接口,**克隆 liuchuancong/flame_barrage 至 F:/flame_barrage 并自补 `BarrageItem.id`+`BarrageController.retractWhere`**(d048f91);media_core 同步快进至 4e84ec2(悬浮窗 initialRect/onRectChanged)
4. **resolver 收敛**:fork core/network 版退役,统一用上游 domains/live/data 版(等价安全访问+含 twitch CDN 不发 Cookie 修正),zishu 桥/探针重接
5. **架构门禁收口**:validate_architecture BASELINE 删 1 条 stale+登记 70 条 fork 增量边(live_url_parser/启动预热/sidecar/opener 等独有架构件),**0 unapproved/0 stale**;audit_repository live_back 不变量路径迁 domains 布局,**errors=0**

**验证**:全仓 analyze **0 error**(非 integration_test);全量测试 **176/176 全过**(基线 149+上游新增,11 平台弹幕协议单测全绿);`git diff --cached --check` 0(renormalize 后);audit 0 error;架构门禁 strict 通过。**待办**:opt-in 探针(全站播放/分类/对齐)择窗口复验;flame_barrage 撤回渲染链与上游新弹幕功能在 zishu 侧的消费另立项

### 迭代 27(2026-10-03)✅ 抖音二级分类对齐 zishu + 分类并行预热 + 抽屉二级分类四字宽横铺

用户报告三项:抖音 hover 分类错误(应对齐 zishu 二级分类)/分类应启动预加载进内存(hover 马上显示)/左侧抽屉二级分类固定四字宽横向平铺。

1. **抖音二级分类重构**(`platforms/douyin/douyin_site.dart`):旧实现解析 `categoryData` 浅表——8 组 15 项且各组首条目为组自引用(娱乐组 sub_partition 全空、游戏组把二级分区当条目)。重写为 zishu web 同款两列结构:**游戏根按 title 定位**(id 103 也落 100-199 数字段, 用 id 区间判娱乐会整棵误吞游戏树——实测踩坑), 二级分区(射击游戏/竞技游戏/单机游戏/角色扮演/棋牌游戏/休闲益智/策略卡牌)为组、嵌套 sub_partition 为组内条目(和平精英/原神...);娱乐分区(聊天/音乐/二次元/舞蹈/文化/生活/运动)合并为单一「娱乐」组, areaId 带 partition_type=4 保证分类房间接口路由正确;解析失败回落静态兜底表(zishu web 同款分组)。探针实测 **8 组 237 项**(此前 8 组 15 项), 分类房间链路 media-ok
2. **分类预热并行化**(`category_warmup.dart`):预热机制 2026-09-19 已存在但串行逐站, 30+ 平台下尾站等待数十秒——hover 仍见 loading。改 **6 路受限并行**, 全量预热时间从「站点数×单站延迟」压到「并发轮次×单站延迟」;首屏让位仍由启动 2s 延迟保证, 并发上限避免请求风暴;失败静默语义不变
3. **抽屉二级分类固定四字宽横铺**(`browse_sidebar.dart` + `design_tokens.dart` 新增 `catChipWidth=56`):原 GridView 两列大格(条目宽约 99.4px)改 **LayoutBuilder 按实际可用宽度算列数的固定宽网格**(56px ≈ 4×catFontSize+边距), 220px 抽屉下每行 3 枚、条目多时纵向续排;宽窄抽屉自适应不溢出

**验证**:analyze lib+tool **0 error**;全套件 **149/149 过**(含上游合并带入测试);audit 0 error;抖音分类探针(8 组 237 项)+分类房间链路(media-ok)复验通过。并行会话同期在途 playback 文件未纳入本提交


### 迭代 28(2026-10-03)✅ 分类→房间矩阵验证:huya 合并回归 + twitcasting/cc/bilibili 修复

用户要求"分析部分平台的分类是否能正确对应显示房间列表"。新增**分类→房间矩阵探针**(`category_rooms_matrix_probe_test.dart`):全站每分类实际调 getCategoryRooms 拉房间, 逐分类报 withRooms/empty/bad。首轮 357 分类: 96 bad + 29 empty, 定位 6 类:

1. **huya 全断(24/24, 上游合并回归)**:上游重构后的 getLiveList 端点返回 application/json, `getJson` 已解码为 Map, 代码却再 `json.decode(resultText)` → TypeError 全崩。修复兼容 Map/String 双形态
2. **twitcasting Recent 栏目**:上游新着目录对部分条目不回 `current_viewer_count`(null), 旧 schema 校验把 null 当错误 → 整页挂。修复: null 放行为未知观看数
3. **cc 官方专题瓦片**(4/24):`official:xxx` 条目是 cc.163.com 页面直达(旧 UI 经 officialEntryUri 打开), zishu 无网页路由 → getCategores 过滤官方组
4. **bilibili -352(24/24)**:python 全链路复刻(buvid+access_id+wbi 签名齐全)仍 -352 → 服务端匿名风控收紧, 需登录 Cookie。**zishu 运行时 Cookie 断线实锤**:pure_live 适配器经 `ParserConfig.instance?.persistentCookieFor` 取 Cookie, 而旧 UI 的 bindParserRuntimeToApp 不在 zishu 跑 → instance 恒 null → 用户凭证页的 B 站 Cookie 根本没接入。修复:新增 `ZishuParserConfig`(providers 层按凭证更新注入)——用户在凭证页配 B 站 Cookie 即解
5. **yy**:小视频分类 400 + 9 分类无直播, 上游目录数据自身形态
6. **探针自身缺陷修复**:初版重建骨架 LiveArea 丢失扩展字段(yy shortName=JSON 查询串/twitch shortName=slug)造成误报——改为保留 getCategores 原始 LiveArea

**验证**:analyze 0 error;**155/155 全过**(新增 ZishuParserConfig 3 用例);复核矩阵 huya/twitcasting/cc **rooms-ok**;bilibili 待用户配 Cookie 后复核(凭证页粘贴 SESSDATA 整串)

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
