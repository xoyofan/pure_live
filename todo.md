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

## 二、全平台首页字段审计表(2026-10-01,34 平台)

| 平台 | 推荐观看 | 推荐分类 | 分类观看 | 分类分类 | 分类目录 | 搜索 | 弹幕 | 结论 |
|---|---|---|---|---|---|---|---|---|
| bilibili | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅ | ✅ WS | 基准组 |
| 斗鱼 | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅ | ✅ WS | 基准组 |
| 虎牙 | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅ | ✅ WS | 基准组 |
| 抖音 | ✅(或"1.2万"格式串) | ✅ | ✅ | ✅ | 真数据 | ✅ | ✅ WS | 基准组 |
| 快手 | ✅ | ✅ | ✅ | ✅ | 真数据 | ⚠️ 仅主播搜索,观看留空(上游#881) | ✅ HTTP轮询 | 搜索观看=结构性 |
| 网易CC | ✅ | ✅ | ✅ | ✅ | 真数据 | ⚠️ 搜索观看=粉丝数 | ❌ | 搜索口径待统一 |
| Twitch | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅ | ✅ IRC | 推荐=just-chatting 目录 |
| SOOP | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅ | ✅ WS | 基准组 |
| YY | ✅ | ⚠️ biz 映射未预热时回退代码 | ✅ | ✅ | 真数据 | ✅ | ✅ WS | 迭代2 预热 |
| AcFun | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅(结果卡无观看,结构性) | ❌ | 完整参照实现 |
| Picarto | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅(搜索无观看,结构性) | ❌ | 无缺口 |
| TwitCasting | ✅ | ❌ | ✅ | ❌ | 真实(HTML) | ✅(搜索无观看) | ❌ | 分类 area 迭代1 补 |
| 猫耳FM | ✅(热度) | ✅ | ✅ | ✅ | 真数据 | ✅ | ❌(契约未验证) | 完整参照实现 |
| CHZZK | ❌ onlineViewers 已设未透出 | ✅ | ❌ | ✅ | 伪目录(仅popular) | ✅(仅频道卡) | ❌ | 桥接层迭代1 修 |
| niconico | ❌ totalViewers 已设未透出 | ❌ | ❌ | ❌ | 硬编码7 tab | ✅(双缺) | ❌ | 迭代1 补 watching+分类area |
| SHOWROOM | ✅ | ✅ | ✅ | ✅ | 真数据 | ✅(本地快照过滤) | ❌ | 无缺口 |
| Bigo | ✅ | ⚠️ 硬编码站名 | ✅ | ⚠️ | 硬编码单 | ✅(ID+本地过滤) | ❌ | area 仅详情API有,结构性 |
| FC2 | ✅ | ✅ | ✅ | ✅ | 硬编码6官方 | ✅(快照内) | ❌ | 无缺口 |
| Steam | ✅ | ✅(游戏名) | ✅ | ✅ | 硬编码单 | ✅(单页本地) | ❌ | 无缺口 |
| 映客 | ❌ 未解析观看键 | ❌ | ❌ | ❌ | 真实(精选) | ✅(本地昵称) | ❌ | area 迭代1;观看键需探针 |
| KilaKila | ❌ watchNumber 已解析未透出 | ❌ | ❌ | ❌ | 硬编码2 | ✅ | ❌ | watching 迭代1 补 |
| LiveMe | ✅(heat) | ⚠️ 国家码 | 🚫 无分类 | 🚫 | 无 | ✅(观看结构性空) | ❌ | 无分类树,结构性 |
| 六间房 | ✅ | ✅ | ✅ | ✅ | 硬编码6 | ✅ | ❌ | 无缺口 |
| LOOK | ✅ | ⚠️ 视频/语音标签 | ✅ | ⚠️ | 硬编码2 | 伪搜索(本地过滤) | ❌ | 派生标签,可接受 |
| 17LIVE | ❌ liveViewerCount 已解析未透出 | ⚠️ 仅语音房标签 | 🚫 | 🚫 | 无 | ✅(仅第1页) | ❌ | 桥接层迭代1 修 |
| 京东直播 | ❌ pv 已进 totalViewers 未透出 | ⚠️ 硬编码站名 | ❌ | ⚠️ | 硬编码单 | 伪搜索 | ❌ | 桥接层迭代1 修 |
| 酷狗直播 | ✅ | ⚠️ 硬编码站名 | ✅ | ⚠️ | 真实(HTML) | ✅ | ❌ | 列表无分类键,结构性 |
| 百度直播 | ✅ | ✅ | ✅ | ✅ | 真实动态 | ⚠️ 仅精确房间ID | ❌ | 搜索结构性 |
| 微博 | ❌ 原始行未解析 | ❌ | ❌ | ❌ | 硬编码伪分类 | 半实现 | ❌ | 观看键需探针 |
| 小红书 | 🚫 恒空(无公开目录) | 🚫 | 🚫 | 🚫 | 🚫 | ⚠️ 仅精确链接 | ❌ | 结构性无首页 |
| TikTok | 🚫 恒空 | 🚫 | 🚫 | 🚫 | 🚫 | ⚠️ 仅精确查找 | ❌ | 结构性无首页 |
| YouTube | 🚫 恒空 | 🚫 | 🚫 | 🚫 | 🚫 | ⚠️ 仅精确解析 | ❌ | 结构性无首页 |
| PandaTV | ❌ onlineViewers 已设未透出 | ✅ | ❌ | ✅ | 单伪分类 | ✅ | ❌ | 桥接层迭代1 修 |
| IPTV | 🚫 裸流无统计 | ✅ groupTitle | 🚫 | ✅ | 真实(本地DB) | ✅ 本地 | ❌ | 观看结构性 |

统计:可直接修(数据在手)11 处 → 集中在桥接层取值 + 5 个站内小补;结构性无(🚫/硬编码站名类)不强行虚构。

## 三、修复计划(多轮迭代)

### 迭代 1(2026-10-01,本轮)✅ 已完成

- [x] `purelive_backend.dart`:房间列表/搜索卡的 `online` 由裸 `room.watching` 改为 `LiveRoom.audienceValue()` 统一取值 → 一处修复 CHZZK/PandaTV/17LIVE/京东/niconico 五家"数据在手未透出"(新文件 `purelive_audience.dart` 承载,便于单测)
- [x] `kilakila_site.dart`:`watchNumber`(已解析进 DTO)透出到 `watching`
- [x] `niconico_site.dart`:分类房间路径补 `area = category.areaName`
- [x] `twitcasting_site.dart`:分类房间路径补 `area = category.areaName`
- [x] `inke_api.dart`:分类房间路径补 `area = 分组名 channel_name`
- [x] 新增 audience 取值单元测试(`test/purelive_audience_test.dart`,8 用例全过;改动文件 analyze 零问题)
- [x] analyze + 测试通过 → 提交推送 → 勾选本清单

### 迭代 2(待迭代1落地后)

- [ ] YY:`getRecommendRooms` 前 biz→名称映射预热(未预热时推荐 area 显示为代码串)
- [ ] 探针:映客 `Live_top_pc` 原始行、微博 `pc_recommend/list.json` 原始行是否带观看数字段(需网络,落点 inke_api `_card` / weibo_api `parseDirectory`)
- [ ] CC 搜索卡观看口径(现=粉丝数)与列表统一或标注

### 迭代 3(定稿)

- [ ] 结构性缺口定稿记录:Bigo/酷狗/京东 area=站名(列表 API 无分类键)、LiveMe 无分类树、小红书/TikTok/YouTube 无公开首页目录(维持"精确链接进入"定位)、IPTV 无观看统计
- [ ] 弹幕缺口延续上一轮审计(第四节),不在本焦点内展开

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
