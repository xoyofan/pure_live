# 上游同步审查 — 2026-10-07 冻结并合并(处置 accept,双原则)

<!-- policy-markers: whole-diff-classification; merge-base-incoming-range; repository-audit-required; semantic-change-ledger; fork-feature-impact; disposition-required; bug-provenance-required -->

- 上游远端:`https://github.com/liuchuancong/pure_live.git`(既有 `upstream`)
- 上游完整 SHA:`d3ad68be12d43cca6e0b73bef4c29db502ca342c`(证据 `local-artifacts/upstream-reviews/upstream-d3ad68be12d4.json`)
- 审查基线(fork HEAD):`5bb652bd8`(HLS 取流判定对齐上游)
- merge base:`e1b5055bd004e0c525c5677f009e0de067d4017a`(上一轮合并点,docs/UPSTREAM_AUDIT_e1b5055bd.md)
- 入站范围:`e1b5055bd..d3ad68be1` = **52 提交 / 56 文件(+5931/−2111)**
- 门禁脚本实测:`violations=[]`,`diff_check_passed=true`(本波上游自身卫生干净,无需放行条款)
- 试合并实测:**仅 5 个未合并文件**(releases.json/翻译×2/video_controller_panel/其余自动合并);douyu_site、floating_playback 等自动合并面作语义复核
- 结论:**本轮合并**(处置 accept);双原则不变——解析层跟上游,zishu UI 与发布不变量保 fork

## file_review / whole-diff-classification

| 主题 | 代表提交 | 类别 |
|---|---|---|
| **录像播放页 UI 重做 + 共用播放器层抽取**(~40 条):短视频式布局/选集抽屉/倍速/±10s/PiP 整页替换/小窗进度条与收起/竖屏记忆/进度落盘/小屏兼容/主题跟随 | d8dc94af5/555c0bbd3/61b88e04c/c63bdb371/14810ff27/4a621afd9/5c18b0fae/12e246c39/982f3721b… | 旧 UI 域功能+修复(fork 运行时绕过,编译单元) |
| **斗鱼/虎牙 UA 同步**(a858550bb):UA 升 7100004/2.40.0;斗鱼 ws CDN 线(expire=300&fcdn=ws)补 `expire=0`(simple_live 同款,按默认时长签发) | a858550bb | 解析层语义(fork 受益) |
| **直播 cache-pause 根因修复**(98f20b533):远端渐进式流(FLV 等)force-seekable/cache-pause 双 no | 98f20b533 | 上游内核属性(fork zishu 侧已有同款 `cache-pause=no`,media_kit_live_player.dart:357,无需跟进;force-seekable fork 保留 yes=轮播起播偏移依赖) |
| 小窗弹幕会话根因修复+补投递队列/竖屏分别记忆、超分挂载逗号串修复、状态栏通知显示房间名、播放起始时间元数据、弹幕设置页、Obx/异常吞掉等杂项 | 42829bb43/0b26d0d8f/a25facd94/9fed7d973/db351a6d6/00eeb72fe/7ef95314e/81f9e23dc/5763928fa | 功能+修复 |
| force-seekable 一加一 revert(b62805959→ced13040b)净零;releases.json CI;注释/i18n 杂务 | — | 净零/不变量 |

## semantic_change_ledger(逐主题)

| commit/file | upstream intent | issue_and_bug_mapping | implementation | quality_assessment | fork_feature_impact | disposition | regression_plan |
|---|---|---|---|---|---|---|---|
| a858550bb douyu/huya UA+ws 补丁 | UA 老化预防;ws CDN 5 分钟断流规避 | simple_live 同款补丁 | douyu_site 取流后判 expire=300&fcdn=ws 追加 expire=0;huya UA 常量升级 | **与租约机制交互已核**:expire=0 在两侧租约语义中均=无自报寿命(上游 `_expireSeconds` 与 fork FlvSpliceRelay.appliesTo 同判 >0)→ ws 线不走拼接中继/预刷新,回落既有事后恢复链;原画 FLV 线(expire=300)不受影响 | 斗鱼主看链路解析新鲜度提升 | **accept** | 斗鱼播放探针/真机 |
| 98f20b533 cache-pause | 修"播两秒停缓冲再续" | 上游自修 | liveProgressive(FLV 等远端渐进)双 no | fork zishu 侧已等价(cache-pause=no);上游内核文件属编译单元 | 无(fork 不跑上游内核) | **accept** | 编译级 |
| 录像页 UI 重做波(~40) | 对齐参考业务 | 上游内部 | domains/recorder+共用播放器层抽取 | 自洽 | fork 运行时绕过;共用层抽取触碰 lib/core/player 与 domains/live presentation(冲突面已收) | **accept** | 编译级+全量测试 |
| 小窗弹幕/超分/通知等杂项 | 见主题表 | 上游自修 | 局部 | floating_playback.dart 自动合并后**仍引用未发布 media_core API(FloatingResizeHandle)**——复核时再剥一次(上轮 adapt 复现) | 编译单元 | **accept(含再 adapt)** | analyze |
| releases.json | CI 产物 | — | — | — | fork 值保持 | **keep-fork** | — |
| 翻译 en/zh | 上游补键 | — | — | — | fork 的 local_player_*/sixroom_chat_notice 键保留,两set 并存 | **手工合并(两set 并存)** | i18n 键集测试 |

## issue_and_bug_mapping

上游本波无对外 Issue;fork 侧关联:①98f20b533 与 fork 既有 zishu 修复同根因(fork 已修,上游补齐内核侧);②斗鱼 ws expire=0 与 fork 迭代39/41 租约链的交互见上表(语义一致,无冲突)。

## fork_feature_impact

- zishu 播放链(迭代41 租约中继/对齐上游 HLS 判定)零波及:flv_splice_relay/playback_manifest_probe/live_stream_ingest 均未入站。
- douyu_site 自动合并:fork 租约元数据(_leaseRefreshLead/getPlayUrlRefreshAt)与上游 ws 补丁无文本冲突,合并后 grep 复核。
- floating_playback:上游仍带 FloatingResizeHandle,合并后剥离(同上轮)。

## conflict_resolution(5 文件)

| 文件 | 处置 |
|---|---|
| assets/releases.json | 取 fork(发布资产不变量) |
| assets/translations/zh.json / en.json | 手工合并:上游新键 + fork local_player_*/sixroom_chat_notice 键并存 |
| lib/domains/live/presentation/playback/widgets/video_player/video_controller_panel.dart | 取上游(fork 侧无新语义,merge-33 遗留注释) |

## regression_plan / verification_plan

1. analyze(integration_test 存量除外 0 error);2. 全量单测;3. 架构门禁 --strict;4. audit_repository;5. git diff --check(证据已 true);6. floating_playback FloatingResizeHandle 复查剥离;7. douyu_site 租约元数据 grep 复核;8. 推送 origin 验证远端。

## 附表A 入站提交全量清单

- `d3ad68be12d43cca6e0b73bef4c29db502ca342c fix(recorder): 复查三处 —— Esc 只退出全屏、桌面加载态不再吞掉画面、去掉重复 PiP 分支`
- `12121396628c568ca328c1cb73a6662c42272f11 refactor(recorder): 播放页去掉中文注释，硬编码文案改走 i18n`
- `cf50b0157c1b96b4e3e73eba265c6b3c9eb54bf1 feat(recorder): 窄窗口的右上角入口收进设置面板，并去掉面板里的小窗播放`
- `16bf5ea121de2cd455f4da4c5fc6c3f3a81768ea fix(recorder): 全屏的返回语义与横竖屏形状，对齐直播间`
- `a182c0b29703bf55071d321cb5f7d7c6c63b5c36 fix(recorder): 播放器快捷键挂到页面自己的 Focus —— 重建后空格/Esc/f 失效的根因`
- `6a3ab101654c8c05e3fd187a68cf32c4ca241c13 fix(video_controller): 优化全屏状态下的按钮显示逻辑 —— 修复小窗口模式下的全屏按钮显示问题`
- `98f20b5339970e3630273b034e1e1bcb46a82a76 fix(player): 远端渐进式流禁 cache-pause —— 直播先播两秒停缓冲再续播的根因`
- `2eba60f4b73c5bab153d824b46abc4fc4875b120 fix(player): 紧凑窗口的横竖屏按"里面这个播放器"判断 —— 录像不再借用直播的方向`
- `5bcd5f3c20753f069b71dc4f52fcff7ab373d605 fix(recorder): 小屏不再显示音量滑条 —— 那 100px 就是控制行溢出 50 像素的原因`
- `a858550bb8753f47bc279a4e45f5cb2707cf5937 sync(huya,douyu): 对齐 simple_live —— UA 升至 7100004/2.40.0,斗鱼 ws 线 expire=0 补丁;修测试导入分号`
- `4b8e60b6300e91ec2d19fb69bb3fc5eb9448684f fix(recorder): 关掉小窗也落一次进度 —— 在小窗里看的那段不再丢`
- `83e5673b3bfefc5e1b6ec2c26cd29aa500e3762e feat(recorder): 仅音频 / 截图 / 画中画移到画面右上角常驻`
- `7ef95314e9474601eee7e3956a4eb651091e021b feat: add danmaku settings page and related functionality`
- `4a621afd90a6f21283868a1fa5162c72b4fdf313 fix(recorder): 短片不再被当成"已看完" —— 展开小窗后接着播，而不是从头`
- `7161050a68987b7c995479347efae7d2fa7a5be9 fix(recorder): 录像画中画自带黑底 —— 透明 Scaffold 把浅色主题透成白边`
- `af8929839a01b820635025eaa09a2a6ac3dfe6b8 fix(player): 紧凑进度条自带 Material —— 小窗那层裸 Overlay 里 Slider 直接抛异常`
- `cc2af0daf53dcd654de288677a2280992a4c07f3 feat(player): 小窗控制层无操作 5 秒后收起`
- `0bdad884cf5358eecac2bf107a051213a2e9d6d9 fix(recorder): 全屏里的画中画与退出恢复 —— 状态跟驱动，紧凑窗口加进度条`
- `14810ff277c21e184769b7591cad459e36ba1ec2 feat(player): 紧凑窗口用可拖进度条 —— 小窗里也要能改播放位置`
- `5c18b0fae0895ebe9090e53bb52b523337391848 feat(recorder): 录像播放页兼容小屏 —— 窄窗口改成画面在上、列表在下`
- `982f3721b638e68d9abaedf18a008eea6b1665b0 fix(recorder): 小窗点"回到页面"接着播 —— 展开前先把当前位置落盘`
- `12e246c3971d09aa558fcd1c5257b80be89801e4 fix(player): 录像的小窗/画中画对齐直播间 —— 角标、时长、压在画面上的标题栏`
- `80d4fed2936c2ec08f0794191e2b63f93fafb80b test(player): 列表选项钉成逐条 append —— 上一版逗号串写法被运行日志证伪`
- `9fed7d9734474820d2eb6ef50ef354c9103eb4ac fix(player): 超分挂载不再交逗号串 —— 整串被 mpv 当成一个 shader 路径, 直播全线判播放失败`
- `57ae47320d1d692703a80db2b41705095f218855 fix(recorder): 桌面画中画整页替换 —— AppBar 等页面 chrome 不留在缩小的窗口里`
- `ce5c026b11c0a460e73fd4f531862be83d889bfb feat(recorder): 底栏加±10s跳转,返回键跟随floatPlay设置转小窗,打开即播`
- `322e28669aca333a3e9a7f396103250ab3a31324 fix(recorder): 底栏去掉重复的画中画/小窗,AppBar 去掉重复的打开目录`
- `c9d2a41a81c83475ab8c639af020962e9ac5e353 feat(recorder): 适应宽度/PiP/小窗移到底部控件行,全屏改一键切换且只渲染视频区,关库英文溢出菜单`
- `f1dd6cfb4ff110617c7decff2d6f24f9a06a9997 fix(recorder): 进入录像播放先暂停直播间 —— 消除后台声音与画面残留`
- `3fba7b878f9f7accfe360c8b17a43c42c6956829 fix(recorder): 控制条跟随主题色,全屏走直播式横屏,PiP整页替换,小窗位置记忆并入直播配置`
- `4e4e478ca0b8272bcfc19af97b2435e5b990f99e chore: update releases.json [skip ci]`
- `81f9e23dcddf11ec0bc5d4fc43e70ae1650f06e6 fix(recorder): 面板标题去掉无观察对象的 Obx —— ObxError 连带撑爆 Column`
- `c63bdb371c652fafd24804e82af1aa46a660979c feat(recorder): 小窗与画中画对齐直播样式 —— 全边缩放/记忆位置/控件层,桌面PiP复刻overlay`
- `5763928faf3ee00bbb4a2337243329ac1fa252b3 fix(recorder): 吞掉内核操作被取代的取消异常 —— 音量手势/拖进度不再冒未处理异常`
- `9a0a08d372840109b7a70246a2badd61808ada50 fix(player): 亮度HUD默认隐藏,录像页小加载态+选集图标,直播全屏栏让出刘海与手势区`
- `994fa563f353b234c3839609a0dcff59b7816a60 fix(recorder): 关掉库顶栏消除双层标题,页面顶栏补状态栏安全区`
- `2b751a7e094255f4a456791c9ae00bd799ec4c89 style(recorder): 面板恢复快捷按钮行,选集条改悬浮样式,设置抽屉分组卡片化`
- `61b88e04c87e4b3a2eec420cc9ce4e27afb37304 feat(recorder): 录像播放页顶部栏改倍速+三点,bottomsheet 设置与选集分离 —— 对齐参考业务`
- `d8dc94af59274fa888ee0a062070aa2de4635c24 feat(recorder): 录像播放页改短视频式布局 —— 上下文面板+全屏胶囊+选集抽屉,弹幕/PiP/小窗沿用共用层`
- `8e0da21510dd319a2c0476c5511a621ee487826a fix(recorder): RxList 默认初始值是 const []，录屏列表改成长度可变的`
- `8570b1bb1190d461fe09d9bf9b708d7ef534b4b6 docs(ledger): 记录共用播放器层抽取与录像页改造`
- `555c0bbd39d2ec31cdc03667b7ec4efa67b74dcd refactor(player): 抽出共用播放器层，录像页改用直播那套控制与手势`
- `796823afd53e22b5fd7b14643c19eaf9bd2bd6f6 ﻿feat(recorder): 重做录像播放页 UI，并让录像能交给小窗播放`
- `ced13040bbab017b8e854b72835544626d356ad6 Revert "fix(player): force-seekable no for live streams without a declared start"`
- `b62805959ad78e94c7e3391899f1a0edb3549353 fix(player): force-seekable no for live streams without a declared start`
- `db351a6d60ddecff369db0ca7a73cefd0c2b722c ﻿fix(notification): 播放直播时状态栏通知显示房间名，而不是流地址文件名`
- `00eeb72fe7160232b1ae5087a1de6b16182f5808 feat(playback): 添加播放开始时间和相关元数据支持 feat(drawables): 添加媒体控制图标（播放、暂停、停止、快进、快退、上一曲、下一曲）`
- `f1d795302ba78429bbc01ca6e2940748e7b4899c ﻿fix(i18n): 打开直播间时的提示不再说"远端聊天尚待接入"`
- `2cfbf8d3eaae43a76c804228f4bde8f12005f1d8 ﻿chore(floating): 移除小窗的临时诊断读数与计数`
- `42829bb434f42ce2e7b8b1a7f7cbac6952c00db0 ﻿fix(floating): 小窗弹幕会话不再被作废（真正的根因）`
- `a25facd943564f75b8517f22ef5d565a3c10e69c ﻿feat(floating): 小窗按直播流方向（竖屏/横屏）分别记忆尺寸与位置，并兼容竖屏直播`
- `0b26d0d8f6b6efc879195e03c2e002ab977439e4 ﻿fix(floating): 小窗弹幕补投递队列 + 临时诊断读数`

## 附表B 入站文件全量清单

- `android/app/src/main/res/drawable/ic_media_forward.xml`
- `android/app/src/main/res/drawable/ic_media_next.xml`
- `android/app/src/main/res/drawable/ic_media_pause.xml`
- `android/app/src/main/res/drawable/ic_media_play.xml`
- `android/app/src/main/res/drawable/ic_media_previous.xml`
- `android/app/src/main/res/drawable/ic_media_rewind.xml`
- `android/app/src/main/res/drawable/ic_media_stop.xml`
- `assets/releases.json`
- `assets/translations/en.json`
- `assets/translations/zh.json`
- `docs/PLATFORM_SYNC_LEDGER_4X.md`
- `lib/app/bootstrap/initial_services.dart`
- `lib/app/router/navigation_observer.dart`
- `lib/core/config/float_window_geometry.dart`
- `lib/core/platform/desktop_manager.dart`
- `lib/core/player/core/playback_source_hints.dart`
- `lib/core/player/kernel/floating_handle_keeper.dart`
- `lib/core/player/kernel/floating_playback.dart`
- `lib/core/player/kernel/media_kit_live_properties.dart`
- `lib/core/player/kernel/player_kernel_service.dart`
- `lib/core/player/presentation/compact_playback_progress.dart`
- `lib/core/player/presentation/danmaku/danmaku_settings_content.dart`
- `lib/core/player/presentation/danmaku/danmaku_surface_settings.dart`
- `lib/core/player/presentation/danmaku/danmaku_viewing_preset.dart`
- `lib/core/player/presentation/danmaku/player_danmaku_actions.dart`
- `lib/core/player/presentation/danmaku/player_danmaku_surface.dart`
- `lib/core/player/presentation/kernel_floating_window_presenter.dart`
- `lib/core/player/presentation/player_presentation_actions.dart`
- `lib/core/player/presentation/player_ui_controller.dart`
- `lib/core/player/presentation/windows_pip_driver.dart`
- `lib/core/player/super_resolution.dart`
- `lib/domains/live/domain/live_player_facade.dart`
- `lib/domains/live/domain/playback_source_refresh.dart`
- `lib/domains/live/presentation/multiview/danmaku/multiview_danmaku_settings_source.dart`
- `lib/domains/live/presentation/playback/controllers/danmaku_controller.dart`
- `lib/domains/live/presentation/playback/controllers/live_play_controller.dart`
- `lib/domains/live/presentation/playback/pages/danmaku_settings_page.dart`
- `lib/domains/live/presentation/playback/widgets/danmaku/compact_danmaku_overlay.dart`
- `lib/domains/live/presentation/playback/widgets/danmaku/danmaku_settings_source.dart`
- `lib/domains/live/presentation/playback/widgets/danmaku/danmaku_viewing_preset.dart`
- `lib/domains/live/presentation/playback/widgets/danmaku/portrait_danmaku_policy.dart`
- `lib/domains/live/presentation/playback/widgets/local_interaction/local_interaction_controller.dart`
- `lib/domains/live/presentation/playback/widgets/video_player/video_controller.dart`
- `lib/domains/live/presentation/playback/widgets/video_player/video_controller_panel.dart`
- `lib/domains/recorder/presentation/pages/local_player/local_video_player_controller.dart`
- `lib/domains/recorder/presentation/pages/local_player/local_video_player_page.dart`
- `lib/domains/recorder/presentation/pages/local_player/recording_danmaku_track.dart`
- `lib/domains/recorder/presentation/pages/local_player/recording_resume.dart`
- `lib/shared/platforms/douyu/douyu_site.dart`
- `lib/shared/platforms/huya/huya_request_params.dart`
- `test/core/config/float_window_geometry_test.dart`
- `test/core/player/compact_playback_progress_test.dart`
- `test/core/player/media_kit_source_properties_test.dart`
- `test/core/player/super_resolution_chain_test.dart`
- `test/domains/recorder/local_player_small_window_test.dart`
- `test/domains/recorder/recording_resume_test.dart`

- 冻结 SHA(full):`d3ad68be12d43cca6e0b73bef4c29db502ca342c`;merge base(full):`e1b5055bd004e0c525c5677f009e0de067d4017a`
