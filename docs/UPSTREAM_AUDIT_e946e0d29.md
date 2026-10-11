# 上游审计 e946e0d29(2026-10-11)

- 上游冻结:`e946e0d29029a767ce81ad703d84acb648d63989`(liuchuancong/pure_live master)
- merge base:`d3ad68be12d43cca6e0b73bef4c29db502ca342c`(2026-10-07 已合并点)
- 入站范围:69 个提交(git rev-list;审计脚本按主题合并展示为 51 条)、122 个变更文件、48 高风险文件、1 删除源码文件、0 二进制。
- 机器证据:`local-artifacts/upstream-reviews/upstream-e946e0d29029.json`(不提交)。
- 合并口径(用户,2026-10-11):**解析与播放策略上的分歧无条件采用上游方案**。fork 侧保留:zishu UI(`lib/src`)、purelive_backend 注册桥、发布/工作流/更新源不变量,以及上游未提供替代实现的区域定制(如 huya getLiveList 的 zishu browse 对齐端点)。
- 阻断项处置:唯一 violation `workflow_default_true` 来自上游 141b4f9b6db8d61d04d0625f6ac7ef036ea3fb06 将发布工作流全平台输入 default 改 true,违反 fork「手动全平台工作流默认关闭、串行执行」不变量 → `build_pure_live_release.yml` 保留 fork 版,上游改动 drop,violation 随处置解除。

## semantic_change_ledger

### A. 返回键/全屏/PlayerBackScope 体系(accept;fork 旧 UI 与 zishu 均未触碰该批文件)

| 提交 | upstream intent / implementation | 处置 |
| --- | --- | --- |
| 33499909b1aab83e7dcc39ae1651586ca842cff4 | 返回键改走 PlayerBackScope:新增 `lib/core/player/presentation/player_back_scope.dart`(237 行,基于 AndroidPredictiveBackService 的 PRIORITY_OVERLAY 回调,按路由登记/解除并计数防误清),安卓返回先退全屏/画中画再退页面 | accept |
| d0247eebe5faad3c3fb30dd5269af3bdb39c1bd6 | 返回回调按路由登记/解除而非清空全局字段(修「自己人清掉自己人」) | accept |
| 23d0f23586edecad8e2fc55403fde9be177d3ac1 | revert 还原 android_predictive_back_service.dart(live_play 与多画面都在用) | accept |
| 8f9874e9480673c8ea91703e7f800e4cacd826d7 | 系统返回不再被拦截为系统画中画,统一为返回上级界面 | accept |
| 87c17c94369fbe4fd0a7592a04c379ab3f79da54 | 返回键两段语义:全屏先退全屏,非全屏退出页面 | accept |
| a3b7e56e1ecf1a04fed0b0b438e29bde97a4f43 | 全屏时 canPop=false,由 Flutter 自己保证「再按一次才退页面」 | accept |
| 8cf062eda796ac81a75bf1e7f39b0b4cd1ac1d2 | Navigator.pop() 替代 Get.back() 兼容性 | accept |
| 32b6c7ecffec9f0f9db5103769982df6054d244 | PlayerBackScope 的 presentationActive 恒为 false 修复(返回键真的接上) | accept |
| d133a943b9d126388c50de214bb4ac102cab4837 | 录像页自己离开路由 + 多画面挂上 PlayerBackScope | accept |
| 62af8d80e7335a8f1b343f590b68c65506010f52 | 快捷键搬到页面层,进全屏后空格/Esc/F 不再失灵 | accept |
| 523f84921073ed6b0b3a0f5d20c8dd8a34b73db | 房间快捷键焦点自持,全屏/画中画切换后 Space/Esc 不再失联 | accept |
| c7cf5463efbf5dc60446b3810c55b9f3ce9f175c | 房间键位收成一张可测的表,补 F 全屏切换 | accept |
| a4ee80b29b95cf299ac612c80a0209159d6c48b8 | 房间补 M 静音键(静音是切换,不是归零) | accept |
| 4d4363d78a884349b0c12a59739fdf4185273963 | 关闭画面弹幕不再连坐侧边栏与全局开关(multiview_danmaku_session) | accept |
| e3d45d3cd8eefee433666c43b5a6a14c2fd215a8 | 全屏状态窗口控制按钮(最小化/关闭,desktop_manager) | accept |

zishu(`lib/src`)经查不引用 player_back_scope/android_predictive_back_service/player_consts 等符号;zishu 播放链仅引用 fork 自有 `lib/core/player/core/playback_input_lease.dart`。本组对 zishu 运行时零影响,旧 UI(编译单元)保持上游新形态。

### B. 平台解析(huya 重构 + 11 站外链)——用户口径:无条件上游

| 提交 | upstream intent / implementation | 处置 |
| --- | --- | --- |
| ff98cd046d7ddba8c8af1f6c234c96f719b4807b | huya 对齐 dart_simple_live-dev:房间详情弃 `mp.huya.com/cache.php` 改抓房间页 HTML(TT_ROOM_DATA/stream 正则解析);isVip 判定(新增 huya_vip_room_id.dart 398 房白名单,字段当前 `unused_field`);WUP 请求随机 SDK UA(requestHuyaUA);SC 触发(headline 播报触发后台重拉)与排序(最新在前,pageSize 10→50);joinRoom 进房包 uid→topSid 修正;画质排除 4K/HDR、移除 sort 降序 | accept |
| 6295de272f6c43854c5021e3fd226d3ea25a28e5 | huya gid 四态兼容(Map/double/int/String,类目列表整页不再抛类型错)+ 端点实测探针 tool/probes/huya_danmaku_ws_probe_test.dart | accept |
| 3f1a464e9809ca7cf74819909ba10a56b84c956f | huya 画质修复(4K 排除落点) | accept |
| b982dca02347b6c4b38549a260866c39d8ab5da9 | 外部打开链接把房间号换回 liveroom.roomId + sanitizedExternalRoomId 守门,11 站恢复(acfun/bilibili/cc/douyu/huya/kuaishou/missevan/picarto/soop/twitcasting/twitch) | accept(fork 同位置空号守门与上游同义,上游 helper 更严,取上游) |

fork 侧 huya 定制(getLiveList 走 live.huya.com/liveHttpUI、LiveSiteWarmUp、pickHuyaIdentityLabel、ParserConfig cookie)上游未提供替代实现,保留;上游重写的 `_loadRoomDetail`/`parsePlayQualities`/`getRoomDetailForRefresh` fork 未动,干净套入。画质列表顺序由 sort 降序变为 API 原序(上游意图),zishu 画质菜单消费 getPlayQualites 的展示顺序随之变化,列入回归计划。

### C. i18n 大搬家 + 显示名 locale 化(accept;translations 手工融合)

| 提交 | upstream intent / implementation | 处置 |
| --- | --- | --- |
| 0e132cd3efd979522383afd6d19c0419c91088f8 | 85 组加载动画 nameZh/nameEn 列删除,搬进语言包(loading_style_* 键) | accept(fork 对 app_consts.dart 为纯空白改动,直接取上游再格式化) |
| e40bd2822020c1e73a92a26b5cbebc08307b051 | 播放预设名称与说明搬进语言包 | accept |
| e93587103821f81f37e7b58fe687c3395e17d580 | mpv 选项与超分名称搬进语言包 | accept |
| db54cb271c1180e0f5f7430d76b4a438c02fd1b | 随机壁纸 API 名称搬进语言包 | accept |
| b88105db019213afcc0286c9c8f8867147cd2f2 | 壁纸库源/分组名称搬进语言包 | accept |
| 3b13546b70e09c307e3d43d0855261c33ba12cf | 播放器手册文案搬进语言包 | accept |
| 24dc2bc2b2c8e1a75a1e0e1b9d21b318e2ba29f | 直播画质名经 locale 在显示缝解析(顺带删除旧 lib/domains/live/presentation/playback/widgets/layout/live_play_back_scope.dart,fork 未改过该文件) | accept |
| 83e06baf7c1d9d1c1bebd1b52f97507e58b5a5b | CJK 扫尾:最后一批硬编码界面文案 | accept |
| c703309336642c94bc8f5901dd84a9c69b35f4e | 紧凑小窗播放/退出标签随语言 | accept |
| 7c97e6237b94555bf7b17ac440a0dbf3972c9f5 | PureLiveScrollPhysics 加到多个 ListView(tool/check_listview_physics.py 守护) | accept |

### D. CI/发布/版本/依赖(fork 不变量优先)

| 提交 | upstream intent / implementation | 处置 |
| --- | --- | --- |
| 80141d545533b9b4c65ab4ae6344bb6775889869 | media_core 17 子包从本机绝对路径改 git 依赖,统一固定 40 位 ref `5b047145422758d983a3724e689d8aa4b7d06863`;Linux 打包补缺 | accept(fork 弃 path `../media_core` 改随上游 git ref;实测该 ref 已含 FloatingResizeHandle/resizeKeepsAspectRatio——正是 fork 当年删 floating resize 调用的根因,现恢复上游完整调用) |
| 141b4f9b6db8d61d04d0625f6ac7ef036ea3fb06 | 全平台默认并行打包 | drop(violation 来源;fork 默认关闭+串行) |
| 6a92a4dc0ba5b498d0d9c401932c968c90a5600d | CI Flutter SDK 改 latest stable,不再固定版本与哈希 | drop(工作流保 fork;本地构建走 .fvmrc + tool/flutterw.ps1 不受影响) |
| fab5cd495eddd7472bb016518af1009df2c9292b | Flutter SDK 版本校验读不到 version 文件(3.47 归档改布局) | drop(同上,工作流保 fork) |
| 366164108a9817b43ea02a5a6a2c3929454b7f1 | fastforge 0.6.0 → 0.6.12 | drop(工作流保 fork) |
| b6eb49f336f91fab2599b71c3dd93a9dfc7e73a6 | Android 构建关闭 Gradle configuration cache(仅 CI) | drop(工作流保 fork;fork CI 若现同症再单独引入) |
| 4bf28f0b6bff2e89f318e400fda014b86b1d8121 | 移除 FFmpeg native bundle 校验链路,精简发布 workflow | drop(工作流保 fork) |
| 85c8402d34a5658a4487d1b1fe12291956531332 | 注释掉代理设置以避免构建问题 | drop(工作流保 fork) |
| 2a44519087130b3f7e56c7c33241a1d79e5b1ae | 删除分层架构校验工作流 | drop-删除(fork 架构门禁 `.github/workflows/architecture.yml` 必须保留:`tool/validate_architecture.py --strict` 跑在 CI) |
| 4a0cf09fe4c4f51b71a86a3fae619f04a2c0571d | 删除签名/托管工作流 + lock 升级 | drop-删除(fork 10 条路由工作流按 docs/AGENT_WORKFLOW.md 全保留;lock 随 pubspec 重新解析) |
| 15681af0f8ea99dd351a28dcdfa339be758801fb | 版本号 3.1.18 + AppLinks 插件支持(app_links ^7.2.1) | adapt(依赖 accept 保持编译一致;版本号 fork 已在 3.1.19+4108 不回退) |
| 51baab5ffc9637484d6291a4da53399d616e1a4 | Linux 打包对齐 dart_simple_live,版本页提供 Linux 多格式下载(deb/zip getter) | accept(release_asset_urls.dart 无 repo 指向,fork 更新源不受影响) |
| 73aba047be0139af1d2577003d148b1f12e7dd07 / 31d4d96b59f87209e2364397296940c7f04a1d9f / 85e2154cd6bad10494e260bc246b79ef6e3ef2cd | version.json/releases.json 3.1.18→3.1.19 更新 | adapt(值已同步;文件保留 fork 版,不机械覆盖) |
| e3bb4142fca5ac17b292891f5b6cd235b53a52ce 等 releases.json [skip ci] 系列(2d13690958a41a4b750ed8954ac299db3b15dfe1、322c6547a2ea1b7c26e4f9090b8161f658d8906e、14a44907e78504e81887e98a193964878bc5110a、f4189f5627a2786b90b536bb512ebad279cc3fb4) | 上游发布索引自动更新 | drop(fork releases.json 保留) |

### E. 播放器体验修复(accept;播放策略按口径无条件上游)

| 提交 | upstream intent / implementation | 处置 |
| --- | --- | --- |
| 30935111122c08dcbd315eaaabe4c4d5bcbad046 | 手机端直播间音量滑杆不再被隐藏的播放器增益砍半(新增 lib/core/player/kernel/open_volume.dart:beforeOpen 声明初始音量,修开屏炸音) | accept |
| 467977e3f0714c4070e8d6ceaf68d35158101333 | macOS 进直播间闪退、开屏炸音与设备同步直达选择页 | accept(macOS 为 community 平台;OpenVolume 机制共享) |
| 8cf4376915ef2caab09bad9736239eca115ab8bc | 手势层不再吞掉点击——直播间点视频区域重新能弹出控制栏 | accept |
| abd9eab61ac90aa0e88441a5770adefd66e51683 | 移动端全屏形状跟状态走、返回先退全屏、右上角按钮真正出现 | accept |
| 554d14e9adeaa840fedb2eabc143edb651eb156e | sheet body widget(fitting_sheet_body.dart)溢出修复配套 | accept |
| 79029cfb7d4283e9504620b49a8273cae8f6ee17 | 画中画窗口不再被裁圆角、不再留一圈底色 | accept |
| bb3c2c50718ca7429af249da8f8321557269c229 | 全屏刘海适配:系统隐藏状态栏后自己报 0,改用真实挖孔安全区 | accept |
| 9ffb4f133f7667cdd342bec273b846728e2ab005 | 控制栏按 viewPadding 自己让位——视频铺满,只有按钮避开猫耳朵 | accept |
| 05610aded6a941cce5ecf27afb6bfb6ffdda0581 | manifest 添加 windowLayoutInDisplayCutoutMode=shortEdges | accept |
| 60f2a69dbabb1e9f76f53eeccad94533030f82de | 竖屏全屏顶栏避开刘海——沉浸态系统报 0 时用状态栏高度兜底 | accept |
| 45289b01fc12403917691f98b46333fc74cb5a21 | 删掉自建刘海适配,改用 SafeArea | accept |
| aecc62c102c3a69e5d22c09f3887a632fb759e85 | 竖屏刘海适配:顶底控制栏让出安全区 | accept |
| 1256828ce703543e0edbcebe602ead65ebf2a55a | iOS 退出全屏后恢复竖屏 | accept(community 平台) |
| 94b154f92e284c492da7a30130a1e6ae58fab2b7 | 桌面全屏底部不再挂片单——与手机全屏一致 | accept |
| 8434bc1c0b1cc473c6e3db45f064d280ded4a8eb | 桌面全屏时控制按钮消失修复 | accept |
| e7a794c00736322513ad249c8202fefcc7f323ed | 每页数量选择持久化,不再每次进入回退默认 20(base_page_scroll_bone + 4 controller persistUserPageSize) | accept(fork 对 4 个 controller 为纯空白改动,取上游) |
| 0f2cda489f0f9c8786145e6345adcb24cb9f89ee | 播放内核一键配置入口 + Android 硬解兼容修复(player_kernel_service/player_preset/mpv_platform_profile/player_consts 瘦身) | accept(播放策略无条件上游) |
| bdce5600ab795d26f2de937536a5307175e341cb | chore(version) 3.1.18.4107 | adapt(fork 版本链路自管) |

### F. 纯 chore(releases.json/version.json 自动更新)

96890815f932996871a569f785c1be1ba0ec02bc、e946e0d29029a767ce81ad703d84acb648d63989 等 `chore: update releases.json [skip ci]` 系列均为发布索引自动更新,处置同 D 组末行:drop(fork releases.json 保留)。完整 40 位清单见附录。

## issue_and_bug_mapping

- 本批上游修复未关联公开 Issue 号(提交信息为自述);对 fork 的映射:
  - huya 房间详情端点弃用(cache.php 路径失效风险)→ fork **present**(zishu 播放页 huya 房间经 purelive_backend 走同一 LiveSite):上游修复直接受益。
  - huya 画质 4K/HDR 不可播 → fork present(解析层共享):上游排除策略直接受益。
  - huya 类目 gid 类型漂移致整页失败 → fork present:gid 四态兼容直接受益。
  - 外部打开链接房间号错误 → fork present(旧 UI 菜单;zishu 侧外部打开走同一 externalRoomTarget):上游修复直接受益。
  - 手机端音量砍半/开屏炸音 → fork 旧 UI present(zishu MediaKitLivePlayer 音量自管,不经过 open_volume,不受影响)。
  - 返回键/全屏/刘海/录像页系列 → fork 旧 UI present;zishu 运行时不经该层,upstream 修复不改变 zishu 行为。
  - 每页数量不持久化 → fork 旧 UI present;zishu browse 自有分页,不受影响。
- 无 fork 侧 already-fixed 冲突(唯一同义实现是 externalRoomTarget 空号守门,上游方案覆盖 fork 方案)。

## fork_feature_impact

- **运行时(zishu,lib/src)**:仅 B 组解析层生效(huya 房间详情/画质/外链)。zishu 画质菜单顺序随上游变为 API 原序。其余组(zishu 不引用)零影响。
- **旧 UI(lib/domains、lib/modules、lib/features,编译单元)**:全量随上游演进(PlayerBackScope、i18n、录像页、pagination 持久化、快捷键表),保持编译通过即可。
- **发布链路**:fork 10 条工作流 + 默认关闭/串行不变量保留;media_core 改 git ref 后 fork 构建不再依赖本机 `F:/media_core` 目录布局(CI 可复现)。
- **依赖**:新增 app_links ^7.2.1(编译一致性);media_core 从 path 改 git(固定 40 位 ref,符合供应链规则)。
- **版本**:pubspec 3.1.19+4108 与上游同值,version.json/releases.json 保留 fork 文件。

## quality_assessment

- PlayerBackScope 设计良好:路由计数防误清、dispose 判定自有回调、按路由登记解除;桌面/非 Android 走 Flutter PopScope 通道,平台分叉正确。
- huya 网页抓取对齐 dart_simple_live 参考实现,降级路径(allowUiFallback + CurrentLiveRoom)保留;正则解析 `var TT_ROOM_DATA = ` 硬编码 JS 形态,为参考实现既有风险,随上游。
- OpenVolume 的 pending 语义(读不清费、逐源覆盖)有多画面隔离考虑,配套测试随行。
- i18n 搬家调用面大(en/zh +417 键),由上游新增 7 个测试文件守护(loading/quality/wallpaper/mpv/preset/guide/keyboard),fork 全量接收。
- 上游 CI 系列改动质量与本 fork 发布安全模型冲突(default true/并行/latest stable),drop 处置,不评价其上游语境优劣。

## disposition

汇总(按文件类别,逐文件见 file_review 附录):

- accept:lib/core 解析/播放/分页/窗口/质量标签/i18n 调用侧、lib/domains、lib/features、lib/shared/platforms、tests、tooling、android/linux/windows 原生、.github/actions/get-version。
- adapt:pubspec.yaml(media_core git ref + app_links + 保留 fork live_parser/speech2yz path 与版本号)、pubspec.lock(重解析)、assets/translations/*(上游 417 新键 + fork 24 行键文案并存)、assets/version.json(值同步、文件保留)。
- drop:.github/workflows 全部上游改动(10 个删除恢复 fork 版;build_pure_live_release 保 fork 版)、assets/releases.json(保 fork 版)。

## conflict_resolution

37 个双方共改文件的处置:

| 文件 | 处置 |
| --- | --- |
| .github/workflows/feature-build.yml、publish-staged-release.yml、stage-hosted-artifacts.yml | 上游删除 vs fork 改默认标签 v3.1.17:恢复 fork 版(含 fork 标签值) |
| android/app/src/main/AndroidManifest.xml | 融合:保留 fork application 的 enableOnBackInvokedCallback=true 与注释 + 上游 activity 的 windowLayoutInDisplayCutoutMode=shortEdges |
| assets/releases.json、assets/version.json | 保 fork 版 |
| assets/translations/en.json、zh.json | 手工融合:fork 24 行键值改动 + 上游 417 新键 |
| lib/core/consts/app_consts.dart、lib/core/index.dart、lib/core/widgets/index.dart | fork 为纯空白改动 → 取上游,再按 fork 格式化规则整理 |
| lib/core/pagination/*.dart(4 个 controller) | fork 为纯空白改动 → 取上游(persistUserPageSize) |
| lib/core/player/kernel/floating_playback.dart、mpv_option_labels.dart、mpv_platform_profile.dart、player_preset.dart | fork 语义改动仅 floating resize API 移除(根因是本地克隆旧版无符号;上游 git ref 5b04714 已含该 API)→ 按口径取上游完整版 |
| lib/domains/account/.../user_detail_main_page.dart、sign_in_page.dart | 保 fork 版(firebase 移除);上游 i18n/physics 改动中仍适用的行手工套入(firebase 相关行除外) |
| lib/domains/live/.../live_play_menu_button.dart | 融合 import 区:fork live_url_tool + 上游 windows_multi_instance_launcher/known_room_link_dialog |
| lib/shared/platforms/(11 站 site + huya_danmaku、huya_site) | externalRoomTarget/huya 全按上游;fork 的 getLiveList/WarmUp/身份标签/ParserConfig cookie 定制保留 |
| linux/flutter/generated_plugins.cmake | 取上游(app_links 插件注册,flutter 生成物) |
| pubspec.yaml、pubspec.lock | 见 disposition adapt;lock 以 `flutter pub get`(固定 SDK)重新解析 |

## regression_plan

- 受影响确定性测试(上游新增,全量接收):`test/core/i18n_bundle_test.dart`、`test/core/release/release_asset_urls_test.dart`、`test/core/utils/live_quality_display_test.dart`、`test/core/widgets/fitting_sheet_body_test.dart`、`test/domains/live/video_key_bindings_test.dart`、`test/domains/wallpaper/wallpaper_catalog_labels_test.dart`、`test/features/settings/player_guide_labels_test.dart`,以及仓库既有 huya/平台解析测试(huya gid 四态、画质排除 4K/HDR、外链 sanitize)。
- zishu 运行时面:huya 房间进入(网页抓取路径)、画质菜单(API 原序)、外部打开链接;非 huya 平台解析回归(B站/斗鱼/抖音等 purelive_backend 供流探针,沿用 tool/probes 既有探针)。
- 编译面:旧 UI 大改后全仓 analyze 一次(本修复轮计划内 Dart 编辑收敛后)。
- 失败回滚点:merge commit 单点回滚;media_core git ref 若解析失败回退 fork path 依赖(../media_core 本地克隆仍在)。

## verification_plan

1. 复核脚本文档门禁已通过(audit_document_valid=true、high_risk_approved=true;2026-10-11 证据 JSON)。`workflow_default_true` 与入站 trailing whitespace 为政策硬阻断(人工批准不覆盖),处置为该批行不随合并进入仓库;合并完成后以新 HEAD 复跑 `review_upstream_update.ps1`(此时入站范围应为 0)出证闭环。
2. 真实 merge(保留上游祖先关系),按 conflict_resolution 表解冲突。
3. 固定 SDK `flutter pub get` 重解析 lock;dart format 仅本批冲突解决触及的 Dart 文件。
4. `python tool/audit_repository.py` 全仓复核 + `git diff --check`。
5. 受影响测试全量跑(flutter test 上述文件 + 既有平台解析测试)。
6. 架构门禁 `tool/validate_architecture.py --strict`(architecture.yml 已恢复)。
7. 合并提交推送 origin/master 并核验远端 head;本轮不做 release(源同步与发布分离)。

## file_review

| 文件 | 状态 | 类别 | 处置 |
| --- | --- | --- | --- |
| .github/actions/get-version/action.yml | A | repository_metadata | accept(上游 composite action,fork 无害) |
| .github/workflows/architecture.yml | D | workflows_and_release | drop-删除(fork 架构门禁 CI 保留) |
| .github/workflows/audit-upstream.yml | D | workflows_and_release | drop-删除(fork 审计入口保留) |
| .github/workflows/build-ios-unsigned.yml | D | workflows_and_release | drop-删除(fork 托管路由保留) |
| .github/workflows/build-native-ffmpeg-apple.yml | D | workflows_and_release | drop-删除(fork 签名链路保留) |
| .github/workflows/build_pure_live_release.yml | M | workflows_and_release | drop-改动(保 fork:默认关闭+串行) |
| .github/workflows/feature-build.yml | D | workflows_and_release | drop-删除(fork 主托管回退保留) |
| .github/workflows/local-signed-android.yml | D | workflows_and_release | drop-删除(fork 自托管回退保留) |
| .github/workflows/publish-signed-android.yml | D | workflows_and_release | drop-删除(fork 发布验证保留) |
| .github/workflows/publish-staged-release.yml | D | workflows_and_release | drop-删除(fork 协调发布保留) |
| .github/workflows/sign-staged-android.yml | D | workflows_and_release | drop-删除(fork 签名保留) |
| .github/workflows/stage-hosted-artifacts.yml | D | workflows_and_release | drop-删除(fork 草稿挂资产保留) |
| android/app/src/main/AndroidManifest.xml | M | android_native | adapt(保 fork enableOnBackInvokedCallback + 上游 cutoutMode) |
| android/app/src/main/kotlin/com/mystyle/pure_live/MainActivity.kt | M | android_native | accept |
| android/gradle/wrapper/gradle-wrapper.properties | M | android_native | accept |
| assets/releases.json | M | workflows_and_release | drop-改动(保 fork 发布索引) |
| assets/translations/en.json | M | translations_and_assets | adapt(上游 417 新键 + fork 键文案并存) |
| assets/translations/zh.json | M | translations_and_assets | adapt(上游 417 新键 + fork 键文案并存) |
| assets/version.json | M | workflows_and_release | adapt(值已同步 3.1.19,保 fork 文件) |
| lib/core/config/theme_settings_controller.dart | M | platform_interfaces | accept |
| lib/core/consts/app_consts.dart | M | platform_interfaces | accept(fork 侧纯空白改动,取上游 i18n 瘦身版) |
| lib/core/index.dart | M | platform_interfaces | accept(fork 侧纯空白改动,取上游) |
| lib/core/pagination/base_page_scroll_bone.dart | M | platform_interfaces | accept |
| lib/core/pagination/local_reactive_page_controller.dart | M | platform_interfaces | accept(fork 纯空白,取上游 persistUserPageSize) |
| lib/core/pagination/server_all_page_controller.dart | M | platform_interfaces | accept(fork 纯空白,取上游 persistUserPageSize) |
| lib/core/pagination/server_fixed_page_controller.dart | M | platform_interfaces | accept(fork 纯空白,取上游 persistUserPageSize) |
| lib/core/pagination/server_remote_page_controller.dart | M | platform_interfaces | accept(fork 纯空白,取上游 persistUserPageSize) |
| lib/core/platform/desktop_manager.dart | M | platform_interfaces | accept |
| lib/core/player/kernel/floating_playback.dart | M | platform_interfaces | accept(取上游完整 resize 调用;media_core git ref 已含 API) |
| lib/core/player/kernel/media_kit_live_properties.dart | M | platform_interfaces | accept |
| lib/core/player/kernel/mpv_option_labels.dart | M | platform_interfaces | accept(取上游 i18n 版;fork 仅格式差异) |
| lib/core/player/kernel/mpv_platform_profile.dart | M | platform_interfaces | accept(取上游;fork 仅格式差异) |
| lib/core/player/kernel/open_volume.dart | A | platform_interfaces | accept |
| lib/core/player/kernel/player_consts.dart | M | platform_interfaces | accept |
| lib/core/player/kernel/player_kernel_service.dart | M | platform_interfaces | accept |
| lib/core/player/kernel/player_preset.dart | M | platform_interfaces | accept(取上游;fork 仅格式差异) |
| lib/core/player/presentation/android_predictive_back_service.dart | R059 | platform_interfaces | accept |
| lib/core/player/presentation/fullscreen_window.dart | M | platform_interfaces | accept |
| lib/core/player/presentation/player_back_scope.dart | A | platform_interfaces | accept |
| lib/core/player/presentation/player_ui_controller.dart | M | platform_interfaces | accept |
| lib/core/player/super_resolution.dart | M | platform_interfaces | accept |
| lib/core/release/release_asset_urls.dart | M | platform_interfaces | accept |
| lib/core/utils/live_quality_label.dart | M | platform_interfaces | accept |
| lib/core/widgets/fitting_sheet_body.dart | A | platform_interfaces | accept |
| lib/core/widgets/index.dart | M | platform_interfaces | accept(fork 侧纯空白改动,取上游 export) |
| lib/domains/account/presentation/account/bilibili/qr_login_controller.dart | M | other_application_source | accept |
| lib/domains/account/presentation/account/bilibili/web_login_controller.dart | M | other_application_source | accept |
| lib/domains/account/presentation/auth/components/user_detail_main_page.dart | M | other_application_source | adapt(保 fork firebase 移除;上游 physics 行套入) |
| lib/domains/account/presentation/auth/sign_in_page.dart | M | other_application_source | adapt(保 fork firebase 移除;上游 i18n 行酌情套入) |
| lib/domains/live/domain/live_player_facade.dart | M | other_application_source | accept |
| lib/domains/live/presentation/multiview/danmaku/multiview_danmaku_session.dart | M | other_application_source | accept |
| lib/domains/live/presentation/multiview/models/multiview_models.dart | M | other_application_source | accept |
| lib/domains/live/presentation/multiview/multiview_controller.dart | M | other_application_source | accept |
| lib/domains/live/presentation/multiview/multiview_page.dart | M | other_application_source | accept |
| lib/domains/live/presentation/multiview/widgets/multiview_room_picker.dart | M | other_application_source | accept |
| lib/domains/live/presentation/pagination/live_directory_controller.dart | M | other_application_source | accept |
| lib/domains/live/presentation/playback/controllers/live_play_controller.dart | M | other_application_source | accept |
| lib/domains/live/presentation/playback/pages/live_play_page.dart | M | other_application_source | accept |
| lib/domains/live/presentation/playback/widgets/button/live_play_menu_button.dart | M | other_application_source | adapt(融合 import:fork live_url_tool + 上游新 import) |
| lib/domains/live/presentation/playback/widgets/keyboard/video_keyboard.dart | M | other_application_source | accept |
| lib/domains/live/presentation/playback/widgets/layout/live_play_back_scope.dart | D | other_application_source | accept |
| lib/domains/live/presentation/playback/widgets/video_player/video_controller.dart | M | other_application_source | accept |
| lib/domains/live/presentation/playback/widgets/video_player/video_controller_panel.dart | M | other_application_source | accept |
| lib/domains/live/presentation/tags/tag_management_controller.dart | M | other_application_source | accept |
| lib/domains/recorder/presentation/pages/local_player/local_video_player_controller.dart | M | other_application_source | accept |
| lib/domains/recorder/presentation/pages/local_player/local_video_player_page.dart | M | other_application_source | accept |
| lib/domains/recorder/presentation/pages/recorder/recorder_controller.dart | M | other_application_source | accept |
| lib/domains/recorder/presentation/pages/recorder/recorder_page.dart | M | other_application_source | accept |
| lib/domains/wallpaper/domain/wallpaper_api_catalog.dart | M | other_application_source | accept |
| lib/domains/wallpaper/domain/wallpaper_catalog.dart | M | other_application_source | accept |
| lib/domains/wallpaper/presentation/wallpaper_api_group_page.dart | M | other_application_source | accept |
| lib/domains/wallpaper/presentation/wallpaper_api_page.dart | M | other_application_source | accept |
| lib/domains/wallpaper/presentation/wallpaper_gallery_page.dart | M | other_application_source | accept |
| lib/domains/wallpaper/presentation/wallpaper_items_page.dart | M | other_application_source | accept |
| lib/domains/wallpaper/presentation/wallpaper_library_page.dart | M | other_application_source | accept |
| lib/domains/wallpaper/presentation/wallpaper_page.dart | M | other_application_source | accept |
| lib/domains/wallpaper/presentation/wallpaper_preview_page.dart | M | other_application_source | accept |
| lib/features/backup/backup_section_picker.dart | M | other_application_source | accept |
| lib/features/remote_receiver/remote_sync_page.dart | M | other_application_source | accept |
| lib/features/remote_receiver/remote_sync_service.dart | M | other_application_source | accept |
| lib/features/settings/pages/loading_style_settings_page.dart | M | other_application_source | accept |
| lib/features/settings/pages/mpv_option_page.dart | M | other_application_source | accept |
| lib/features/settings/pages/player_guide_page.dart | M | other_application_source | accept |
| lib/features/settings/pages/player_kernel_settings_page.dart | M | other_application_source | accept |
| lib/features/settings/pages/player_preset_page.dart | M | other_application_source | accept |
| lib/features/settings/pages/player_super_resolution_page.dart | M | other_application_source | accept |
| lib/features/settings/pages/theme_settings_page.dart | M | other_application_source | accept |
| lib/features/toolbox/toolbox_page.dart | M | other_application_source | accept |
| lib/features/version/version_controller.dart | M | other_application_source | accept |
| lib/features/version/version_page.dart | M | other_application_source | accept |
| lib/features/web_dav/web_dav_page.dart | M | other_application_source | accept |
| lib/shared/platforms/acfun/acfun_site.dart | M | other_application_source | accept |
| lib/shared/platforms/bilibili/bilibili_site.dart | M | other_application_source | accept |
| lib/shared/platforms/cc/cc_site.dart | M | other_application_source | accept |
| lib/shared/platforms/douyu/douyu_site.dart | M | other_application_source | accept |
| lib/shared/platforms/huya/huya_danmaku.dart | M | other_application_source | accept |
| lib/shared/platforms/huya/huya_request_params.dart | M | other_application_source | accept |
| lib/shared/platforms/huya/huya_site.dart | M | other_application_source | accept |
| lib/shared/platforms/huya/huya_utils.dart | M | other_application_source | accept |
| lib/shared/platforms/huya/huya_vip_room_id.dart | A | other_application_source | accept |
| lib/shared/platforms/kuaishou/kuaishou_site.dart | M | other_application_source | accept |
| lib/shared/platforms/missevan/missevan_site.dart | M | other_application_source | accept |
| lib/shared/platforms/picarto/picarto_site.dart | M | other_application_source | accept |
| lib/shared/platforms/soop/soop_site.dart | M | other_application_source | accept |
| lib/shared/platforms/twitcasting/twitcasting_site.dart | M | other_application_source | accept |
| lib/shared/platforms/twitch/twitch_site.dart | M | other_application_source | accept |
| linux/flutter/generated_plugin_registrant.cc | M | linux_native | accept |
| linux/flutter/generated_plugins.cmake | M | linux_native | accept(flutter 生成物,随 app_links) |
| linux/packaging/deb/make_config.yaml | A | linux_native | accept |
| pubspec.lock | M | dependencies_and_vendored | adapt(随 pubspec 以固定 SDK 重解析) |
| pubspec.yaml | M | dependencies_and_vendored | adapt(media_core 取上游 git ref;app_links accept;fork live_parser/speech2zh path 与版本号保留;上游 BOM 去除) |
| test/core/i18n_bundle_test.dart | M | tests | accept |
| test/core/release/release_asset_urls_test.dart | A | tests | accept |
| test/core/utils/live_quality_display_test.dart | A | tests | accept |
| test/core/widgets/fitting_sheet_body_test.dart | A | tests | accept |
| test/domains/live/video_key_bindings_test.dart | A | tests | accept |
| test/domains/wallpaper/wallpaper_catalog_labels_test.dart | A | tests | accept |
| test/features/settings/player_guide_labels_test.dart | A | tests | accept |
| tool/check_listview_physics.py | A | tooling_and_policy | accept |
| tool/prefetch_linux_native.sh | A | tooling_and_policy | accept |
| tool/probes/huya_danmaku_ws_probe_test.dart | A | tooling_and_policy | accept |
| windows/packaging/msix/make_config.yaml | M | windows_native | accept |

## 附录:入站提交全量清单(69 个真实 40 位 SHA)

- 62af8d80e7335a8f1b343f590b68c65506010f52 fix(recorder): 快捷键搬到页面层 —— 进全屏后空格/Esc/F 不再失灵
- 523f84921073cacd32ec11c15f3f02f402373c51 fix(live): 房间快捷键的焦点自己持有 —— 全屏/画中画切换后 Space/Esc 不再失联
- c7cf5463efbf5dc60446b3810c55b9f3ce9f175c feat(live): 房间键位收成一张可测的表，并补上 F 全屏切换
- a4ee80b29b95cf299ac612c80a0209159d6c48b8 feat(live): 房间补上 M 静音键 —— 静音是切换，不是归零
- e40bd2822020034147945006a9a2327e7be80650 refactor(i18n): 播放预设的名称与说明搬进语言包
- 0f2cda489f0f9c8786145e6345adcb24cb9f89ee feat(settings): 播放内核补上一键配置入口，Android 另有硬解兼容修复
- 0e132cd3efd979522383afd6d19c0419c91088f8 refactor(i18n): 加载动画名称搬进语言包 —— 85 组 nameZh/nameEn 列删除
- e93587103821f81f37e7b58fe687c3395e17d580 refactor(i18n): mpv option and super-resolution names move to the locale bundles
- b88105db01924b7fc72838659c62c50725811d55 refactor(i18n): wallpaper library source and group names move to the locale bundles
- db54cb271c11580b53cee3ede9352142aba718a7 refactor(i18n): random wallpaper API names move to the locale bundles
- 8cf4376915ef2caab09bad9736239eca115ab8bc fix(player): 手势层不再吞掉点击 —— 直播间点视频区域重新能弹出控制栏
- 3b13546b70e00c1f0a4fe88ef6e4b027524d87c2 refactor(i18n): player manual wording moves to the locale bundles
- abd9eab61ac90aa0e88441a5770adefd66e51683 fix(recorder): 移动端全屏形状跟状态走、返回先退全屏、右上角按钮真正出现
- 24dc2bc2b2c836d12bc0f3bf38f762ca8eb8987e refactor(i18n): live quality names resolve through the locale at the display seam
- 33499909b1aab83e7dcc39ae1651586ca842cff4 fix(player): 返回键改走 PlayerBackScope —— 安卓返回终于能先退全屏
- c703309334647a0cc1b9f4d44ee5113d2f7db85a fix(i18n): the live compact window's play and exit labels follow the language
- 83e06baf7c1d63adad302fffec95c5c27feba1b3 refactor(i18n): last hardcoded interface strings found by the CJK sweep
- 7c97e6237b94a28c3e28cc8ae4d8933cee94bec2 fix: 添加 PureLiveScrollPhysics 到多个 ListView 以改善滚动体验
- aecc62c102c3a69e5d22c09f3887a632fb759e85 fix(player): 竖屏刘海适配 —— 顶底控制栏让出安全区，不再被状态栏和手势条压住
- 32b6c7ecffec60d468dab5116f5b3b93e60aa7c6 fix(recorder): 返回键真的接上了 —— PlayerBackScope 的 presentationActive 之前恒为 false
- 554d14e9adeaa840fedb2eabc143edb651eb156e fix(recorder): ship the sheet body widget the overflow fix calls
- bb3c2c50718ca7429af249da8f8321557269c229 fix(player): 全屏刘海适配 —— 系统隐藏状态栏后自己报 0，改用真实挖孔安全区
- 79029cfb7d4283e9504620b49a8273cae8f6ee17 fix(recorder): 画中画窗口不再被裁圆角、也不再留一圈底色
- 45289b01fc12403917691f98b46333fc74cb5a21 refactor(player): 删掉自建刘海适配，改用 SafeArea
- 9ffb4f133f7667cdd342bec273b846728e2ab005 fix(player): 控制栏按 viewPadding 自己让位 —— 视频铺满，只有按钮避开猫耳朵
- 05610aded6a941cce5ecf27afb6bfb6ffdda0581 fix(manifest): 添加 windowLayoutInDisplayCutoutMode 属性以支持刘海屏适配
- 60f2a69dbabb1e9f76f53eeccad94533030f82de fix(live): 竖屏全屏的顶栏避开刘海 —— 沉浸态系统报 0 时用状态栏高度兜底
- 8cf062eda796bb331d6ffdf679949a0092f86825 fix: 更新导航返回逻辑，使用 Navigator.pop() 替代 Get.back()，确保更好的兼容性
- 87c17c94369fbe4fd0a7592a04c379ab3f79da54 fix(recorder): 返回键只做两段语义 —— 全屏先退全屏，非全屏退出页面
- d0247eebe5faad3c3fb30dd5269af3bdb39c1bd6 fix(core): 返回回调不再被自己人清掉 —— 按路由登记/解除，而不是清空全局字段
- a3b7e56e1ecf3b6d2020cfb63eab741fcc103ace fix(recorder): 全屏时让 canPop 为 false —— 由 Flutter 自己保证"再按一次才退页面"
- 23d0f23586edecad8e2fc55403fde9be177d3ac1 revert(core): 还原 android_predictive_back_service.dart —— live_play 与多画面都在用它
- d133a943b9d126388c50de214bb4ac102cab4837 fix(player): 录像页自己离开路由 + 多画面挂上 PlayerBackScope
- 94b154f92e284c492da7a30130a1e6ae58fab2b7 fix(recorder): 桌面全屏底部不再挂片单 —— 与手机全屏一致，只剩画面
- 8434bc1c0b1cc473c6e3db45f064d280ded4a8eb fix(local_video_player): 修复桌面全屏时按钮消失的问题 —— 确保在全屏模式下仍然显示必要的控制按钮
- 80141d545533b9b4c65ab4ae6344bb6775889869 build(deps,ci): media_core 改 git 依赖；补上 Linux 打包真正缺的两件事
- bdce5600ab795d26f2de937536a5307175e341cb chore(version): 更新版本号至 3.1.18.4107
- 2a4451908713472ea566b4bf9dda5eda963169d6 chore(workflow): 删除分层架构校验工作流文件
- fab5cd495eddd7472bb016518af1009df2c9292b fix(ci): Flutter SDK 版本校验读不到 version 文件 —— 3.47 的归档已改布局
- 4a0cf09fe4c4f51b71a86a3fae619f04a2c0571d Remove outdated GitHub workflows for signing Android APKs and staging hosted artifacts; update dependencies in pubspec.lock to latest versions.
- 51baab5ffc96c83df915ef0b7334052be85585f2 build(linux): 参考 dart_simple_live 同步 Linux 打包，版本页提供 Linux 多格式下载
- 141b4f9b6db8d61d04d0625f6ac7ef036ea3fb06 ci(release): 全平台默认并行打包
- 6a92a4dc0ba5b498d0d9c401932c968c90a5600d ci(release): Flutter SDK 改用最新 stable，不再在仓库内固定版本与哈希
- 73aba047be0139af1d2577003d148b1f12e7dd07 更新 version.json
- 4bf28f0b6bff2e89f318e400fda014b86b1d8121 ci(release): 移除 FFmpeg native bundle 校验链路，精简发布 workflow
- 15681af0f8ea99dd351a28dcdfa339be758801fb ci(release): 更新版本号至 3.1.18，添加 AppLinks 插件支持
- 366164108a9890fef09b22e3d040051ae17183e1 ci(release): fastforge 0.6.0 → 0.6.12
- b6eb49f336f91fab2599b71c3dd93a9dfc7e73a6 fix(ci): Android 构建关闭 Gradle configuration cache(仅 CI)
- 85c8402d34a5658a4487d1b1fe12291956531332 chore: 注释掉代理设置以避免构建问题
- e3bb4142fca5ac17b292891f5b6cd235b53a52ce chore: update releases.json for v3.1.18 [skip ci]
- 322c6547a2ea1b7c26e4f9090b8161f658d8906e chore: update releases.json [skip ci]
- 467977e3f0714c4070e8d6ceaf68d35158101333 fix(player,sync): macOS 进直播间闪退、开屏炸音与设备同步直达选择页
- 2d13690958a41a4b750ed8954ac299db3b15dfe1 chore: update releases.json for v3.1.18 [skip ci]
- 14a44907e78504e81887e98a193964878bc5110a chore: update releases.json [skip ci]
- e7a794c00736322513ad249c8202fefcc7f323ed fix(pagination): 每页数量选择持久化,不再每次进入回退默认 20
- 1256828ce703543e0edbcebe602ead65ebf2a55a fix(player): iOS 退出全屏后恢复竖屏
- 30935111122c08dcbd315eaaabe4c4d5bcbad046 fix(player): 手机端直播间音量滑杆不再被隐藏的播放器增益砍半
- e3d45d3cd8eefee433666c43b5a6a14c2fd215a8 fix(window): 添加全屏状态下的窗口控制按钮以支持最小化和关闭功能
- 4d4363d78a884349b0c12a59739fdf4185273963 fix(danmaku): 关闭画面弹幕不再连坐侧边栏与全局开关
- 6295de272f6c43854c5021e3fd226d3ea25a28e5 sync(huya): 对齐 dart_simple_live —— gid 四态兼容 + 端点实测探针
- ff98cd046d7ddba8c8af1f6c234c96f719b4807b sync(huya): 对齐 dart_simple_live-dev —— isVip/4K、随机 UA、SC 触发与排序
- 8f9874e9480673c8ea91703e7f800e4cacd826d7 fix(player): 系统返回不再被拦截为系统画中画 —— 统一为返回上级界面
- b982dca02347b6c4b38549a260866c39d8ab5da9 fix(platforms): 外部打开链接把房间号换回 liveroom.roomId —— 11 个站点恢复
- 3f1a464e9809ca7cf74819909ba10a56b84c956f fix huya 画质
- 85e2154cd6bad10494e260bc246b79ef6e3ef2cd add new version
- 31d4d96b59f87209e2364397296940c7f04a1d9f Update version.json
- f4189f5627a2786b90b536bb512ebad279cc3fb4 chore: update releases.json for v3.1.19 [skip ci]
- 96890815f932996871a569f785c1be1ba0ec02bc chore: update releases.json [skip ci]
- e946e0d29029a767ce81ad703d84acb648d63989 chore: update releases.json [skip ci]
