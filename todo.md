# TODO 迭代台账

> 当前焦点(2026-10-01 启动,多轮迭代):**首页房间卡的观看人数与分类展示按平台补齐**。
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
| AcFun | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅(结果卡无观看,结构性) | ❌ | 完整参照实现 |
| Picarto | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅(搜索无观看,结构性) | ❌ | 无缺口 |
| TwitCasting | ✅ | ✅ 迭代1 | ✅ | ✅ 迭代1 | 真实(HTML) | ✅(搜索无观看,结构性) | ❌ | 无缺口 |
| 猫耳FM | ✅(热度) | ✅ | ✅ | ✅ | 真数据 | ✅ | ❌(契约未验证) | 完整参照实现 |
| CHZZK | ✅ 迭代1 透出 | ✅ | ✅ 迭代1 透出 | ✅ | 伪目录(仅popular) | ✅(仅频道卡) | ❌ | 已修 |
| niconico | ✅ 迭代1 透出(累计观看口径) | 🚫 recent 行无分类 | ✅ 迭代1 透出 | ✅ 迭代1 | 硬编码7 tab | ✅ | ❌ | 已修 |
| SHOWROOM | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅(本地快照过滤) | ❌ | 无缺口 |
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
