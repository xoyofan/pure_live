# 解析 sidecar(Dart 单源架构)

解析逻辑的**唯一实现**是仓库里的 `lib/core`(Flutter app 与本服务共用同一份 Dart 源码)。本目录把它编译成独立可执行文件,由 streamingserver 以子进程方式驱动。

```
Flutter app ─────────进程内直接调用─────────┐
                                           ├──▶ lib/core(唯一解析实现)
streamingserver(Node) ──stdio JSON-RPC──▶ pure-live-sidecar.exe
web(React) ──HTTP/WS──▶ streamingserver
```

## 构建

```bash
node tool/sidecar/gen_runner_package_config.mjs   # 生成 hook-free package_config
cd tool/sidecar/runner
dart compile exe bin/main.dart -o ../../../build/sidecar/pure-live-sidecar.exe
```

Dart SDK 用仓库固定版本(`.fvmrc`);runner 目录只是编译壳(自带 package_config,绕开宿主 pubspec 的 native build hooks),不需要 `pub get`。

streamingserver 启动时自动探测 `build/sidecar/pure-live-sidecar.exe`(可用 `PARSER_SIDECAR_PATH` 覆盖)。**exe 缺失时对应平台的解析不可用**(路由返回 PLATFORM_UNSUPPORTED),弹幕 WS 与 /proxy 不受影响。

## 独立验证(不经 Node)

```bash
printf '{"id":1,"method":"health","params":{}}\n{"id":2,"method":"resolve","params":{"platform":"douyin","roomId":"<在播房间号>"}}\n' | ./build/sidecar/pure-live-sidecar.exe
```

协议:每行一个 JSON 请求 `{"id","method","params"}`,每行一个 JSON 响应 `{"id","ok","result"|"error"}`。方法:`health` / `resolve` / `qualities` / `playUrls`。

## 新增平台(五步)

1. 该平台的 `lib/core/site/<platform>/*` 做**去 Flutter/GetX 改造**(见下"约束");
2. `tool/sidecar/closure_inventory.mjs` 的 `start` 加上站点文件,重跑至 `BAD edges: 0`;
3. `bin/../lib/core/sidecar/sidecar_server.dart` 的 `_sites` 注册新平台;
4. `streamingserver/src/backends/dart_sidecar.ts` 的 `PLATFORM_NAMES` / `HEADER_POLICY` / `CDN_SUFFIXES` 各加一条(播放头策略照 `lib/player`→`core` 的 PlaybackHeaderResolver 对应分支移植);
5. 重编 exe,重启 server,用真实在播房间验证 resolve/qualities/play-urls。

## 解析代码约束(为通过 sidecar 编译)

- 禁止 import `common/index.dart` 等桶文件(会拖入整个 Flutter app)——用精确 import;
- 配置(cookie 等)一律走 `ParserConfig.instance`,日志走 `CoreLog`(持久化由宿主 `CoreLogRuntime` 决定),**不得直接引用 `SettingsService`/`Get.*`**;
- Flutter 专属符号(`debugPrint`/`@visibleForTesting`)分别换成 `CoreLog`/`package:meta`;
- 时间/数值/端点/重试参数**严格保持 Flutter 原版**,不做任何放宽;
- `tool/sidecar/closure_inventory.mjs` 是验收工具:`BAD edges` 必须为 0。

## 与 Flutter app 的关系

`lib/common/services/parser_runtime_binding.dart` 在 app 启动时把 GetX 的实现(cookie、代理、日志、音量)注册进上述注入点。app 行为不变;sidecar 进程不注册任何宿主,匿名运行。

## 弹幕

弹幕 WS(B 站)暂由 streamingserver 的 TS 实现(`src/danmaku/bilibili.ts`)承担,依赖 slimmed `backends/bilibili.ts` 的 wbi/buvid 设施。抖音弹幕为 M2。
