# Pure Live Streaming Server — API 契约 v1

本文件是 `streamingserver/`(Node 解析服务)与 `web/`(React 前端)之间的**唯一接口事实来源**。
两端实现若与本文冲突,以本文为准;需要变更契约时,先改本文再改实现。

## 1. 总体架构

```
┌──────────────┐  HTTP/WS (本契约)   ┌─────────────────────┐      ┌────────────┐
│  web/ React  │ ───────────────────▶│  streamingserver/   │ ───▶ │ 平台上游 API │
│  mpegts.js   │◀──── 弹幕 WS 帧 ─────│  Node 22 + TS (ESM) │      │ (虎牙/B站…) │
└──────────────┘   播放流经代理/直连  └─────────────────────┘      └────────────┘
                                     ResolverBackend 接口
                                     └─ TS 实现(M1)
                                     └─ C++ addon 实现(M3,预留)
```

- 服务端只做**解析与转发**:房间详情、播放地址+请求头、清晰度、弹幕流。不做业务 UI 状态。
- 服务端内部通过 `ResolverBackend` 接口对接各平台;M1 为纯 TS 实现,M3 可替换为 C++ addon(N-API),对 HTTP/WS 契约无影响。

## 2. 通用约定

| 项 | 约定 |
|---|---|
| Base URL | `http://127.0.0.1:8787/api/v1` |
| 编码 | UTF-8 JSON;时间戳一律 ISO-8601 UTC 字符串 |
| ID | 所有 roomId/userId 均为**字符串**(平台数字 ID 也用字符串) |
| 鉴权 | 可选 `X-Server-Token` 请求头;服务端未配置 token 时跳过校验 |
| CORS | 允许 `http://localhost:5173` 与 `http://127.0.0.1:5173` |
| 错误模型 | 非 2xx 一律 `{"error": {"code": "<错误码>", "message": "<人类可读>"}}` |

### 错误码

| HTTP | code | 含义 |
|---|---|---|
| 400 | `BAD_REQUEST` | 参数缺失/格式错误 |
| 401 | `UNAUTHORIZED` | token 校验失败 |
| 404 | `PLATFORM_UNSUPPORTED` | 平台未支持 |
| 404 | `ROOM_NOT_FOUND` | 房间不存在 |
| 410 | `ROOM_CLOSED` | 房间已下线/封禁 |
| 502 | `UPSTREAM_ERROR` | 平台上游返回异常 |
| 504 | `UPSTREAM_TIMEOUT` | 上游超时(默认 12s) |
| 500 | `INTERNAL` | 服务内部错误 |

## 3. 平台 ID

沿用 Flutter 端 `Sites` 的 ID 字符串。M1 支持:`bilibili`、`douyin`。
M2 逐步扩展:`huya`、`douyu`、`cc`、`soop`、`yy`、`twitch`、`iptv` 等。

## 4. REST 端点

### 4.1 `GET /health` (M1)

```json
{ "ok": true, "version": "1.0.0", "platforms": ["bilibili", "douyin"], "uptimeSec": 123 }
```

### 4.2 `GET /platforms` (M1)

```json
{ "platforms": [ { "id": "bilibili", "name": "BiliBili", "capabilities": ["resolve", "play-urls", "qualities", "danmaku"] } ] }
```

`capabilities` 取值:`resolve` | `play-urls` | `qualities` | `danmaku` | `search` | `directory`。

### 4.3 `POST /rooms/{platform}/resolve` (M1)

请求:`{ "roomId": "21452505" }`

响应(房间元数据;对齐 Flutter `LiveRoom` 语义):

```json
{
  "room": {
    "platform": "bilibili", "roomId": "21452505",
    "title": "直播间标题", "nick": "主播名",
    "avatar": "https://...", "cover": "https://...",
    "watching": "1.2万", "link": "https://live.bilibili.com/21452505",
    "status": true, "liveStatus": "live"
  }
}
```

`liveStatus` 取值:`live` | `offline` | `replay` | `banned` | `unknown`。
房间不在线时返回 200 + `liveStatus: "offline"`(不是错误)。

### 4.4 `GET /rooms/{platform}/qualities?roomId=` (M1)

```json
{ "qualities": [ { "selectionId": "原画", "label": "原画" }, { "selectionId": "高清", "label": "高清" } ] }
```

### 4.5 `POST /rooms/{platform}/play-urls` (M1)

请求:

```json
{ "roomId": "21452505", "quality": "原画", "withHeaders": true }
```

响应:

```json
{
  "platform": "bilibili", "roomId": "21452505",
  "quality": "原画", "protocol": "flv",
  "urls": ["https://...flv"],
  "headers": { "user-agent": "...", "referer": "https://live.bilibili.com/21452505", "cookie": "..." },
  "expireAt": "2026-09-30T12:00:00Z",
  "sourceQueryPolicies": {}
}
```

- `headers`:拉流请求必须携带的请求头;浏览器无法自定义 UA/Referer,前端对受约束的流应改走 4.7 代理。
- `protocol`:`flv` | `hls` | `mp4` | `unknown`。
- `quality` 缺省时返回平台默认清晰度;`qualities` 不再重复返回(用 4.4)。

### 4.6 `GET /search/{platform}?keyword=&page=` (M2)

```json
{ "page": 1, "hasMore": true, "rooms": [ { "platform": "...", "roomId": "...", "title": "...", "nick": "...", "cover": "...", "watching": "...", "status": true, "liveStatus": "live" } ] }
```

### 4.7 `GET /proxy?u=<encodeURIComponent(播放地址)>&h=<base64url(JSON headers)>` (M1)

播放流转发:服务端携带 `h` 中的请求头向上游拉流,以管道方式透传(含重定向)。
仅允许 `http(s)`,且 host 必须属于该平台已知的 CDN 域(防滥用)。响应头透传 `content-type`。

### 4.8 `POST /rooms/{platform}/refresh-urls` (M2)

恢复/换线场景:请求同 4.5,服务端基于新会话重新解析,响应同 4.5。

## 5. 弹幕 WebSocket

`WS {base}/danmaku/stream?platform=bilibili&roomId=21452505`

服务端代连平台弹幕源,归一化后推送。文本帧,UTF-8 JSON,每帧一个对象:

服务端 → 客户端:

```json
{ "type": "chat",     "userName": "x", "userId": "123", "text": "666", "avatar": "https://...", "ts": "2026-09-30T12:00:00Z" }
{ "type": "online",   "kind": "popularity", "value": 12345, "ts": "..." }
{ "type": "superChat", "userName": "x", "userId": "123", "text": "...", "price": 30, "ts": "..." }
{ "type": "gift",     "userName": "x", "userId": "123", "giftName": "...", "count": 1, "ts": "..." }
{ "type": "status",   "state": "connecting|connected|reconnecting|closed|error", "message": "可选" }
{ "type": "pong" }
```

- `online.kind`:`popularity` | `onlineViewers` | `totalViewers`(对齐 Flutter `LiveAudienceMetricKind`)。
- 消息类型对齐 Flutter `LiveMessageType`:`chat` | `gift` | `online` | `superChat`。
- M1 至少实现 `chat` 与 `online`;`gift`/`superChat` 可后置。

客户端 → 服务端:`{ "type": "ping" }`(30s 间隔保活);服务端 60s 无 ping 可断开。
断线重连由**客户端**负责(指数退避);服务端对上游的重连自愈,并通过 `status` 帧告知。

## 6. 两端职责边界

| 关注点 | streamingserver | web |
|---|---|---|
| 平台解析(地址/头/清晰度/房间) | ✅ | ❌ 只调 API |
| 弹幕上游连接与归一化 | ✅ | ❌ 只消费 WS |
| 播放流请求头约束 | ✅ 提供 headers + 代理 | ❌ |
| 播放器/弹幕渲染/重连 | ❌ | ✅ |
| 多语言/主题/历史 | ❌ | ✅ |

## 7. 里程碑

- **M1(本轮并行实现)**:契约全部 M1 端点;bilibili + douyin 的 resolve/play-urls/qualities;proxy;bilibili 弹幕 WS;web 播放间(输入/URL 直达 → 房间页:播放器 + 弹幕 + 清晰度切换)。
- **M2**:huya/douyu 弹幕(TARS/签名)、search/directory 端点、web 首页发现流、更多平台。
- **M3**:C++ addon 替换 `ResolverBackend`、录制、鉴权强化。
