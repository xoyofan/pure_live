# zishu_app 移植架构（lib/zishu_app/）

> 给后续维护者的移植地图：zishu_flutter（SFVideoLive 视觉真源）→ pure_live 的落地方式。
> 所有路径相对仓库根，行号以 2026-10-01 源码为准；改代码后请同步更新引用行。

## 1. 三层分层

| 层 | 目录 | 职责 |
|---|---|---|
| 设计系统 | `lib/zishu/` | 从 zishu_flutter **整体搬运**，不含 pure_live 业务依赖 |
| 应用层 | `lib/zishu_app/` | 外壳 + 六 feature（`features/`：browse/follow/areas/play/record/search，另有 settings 设置页） |
| 数据层 | `lib/modules/`（含 `lib/recorder/`、`lib/player/`） | 既有 GetX 控制器/播放部件，被 zishu_app **消费**、不重写 |

- `lib/zishu/` 内部：tokens（`presentation/design_tokens.dart`、`presentation/zishu_tokens.dart`、
  `presentation/app_theme.dart`、`presentation/category_colors.dart`）、组件（`presentation/widgets/` 10 件：
  platform_icon/outline_chip/empty_view/error_view/cover_badges/platform_badge/compact_switch/retry_button/
  section_header/state_dot）、平台品牌（`presentation/platform_brands.dart`）、分类中文映射
  （`domain/category_display.dart` 跨平台映射纯函数 + `domain/cross_categories_data*.dart` 内置表 +
  `domain/zh_categories.dart` SOOP cid→中文）。主题注入点：`lib/common/style/theme.dart:187` 调 `ZishuTheme.decorate`。
- **移植路线**：「照搬 zishu 前端 + pure_live 解析」——视觉/结构/交互对齐 zishu_flutter 真源
  （各文件头部注释标注真源路径与逐像素值），状态管理 Riverpod→GetX，数据一律接 pure_live 真实 API
  （见 `lib/zishu_app/shell/zishu_app_shell.dart:28` 路线宣言）。
- zishu_app 对数据层的消费清单（import 证据）：`modules/live_play/`（controller/widgets/keyboard）、
  `modules/areas/areas_list_controller.dart`、`modules/search/search_controller.dart`、
  `modules/settings/pages/*`（设置子页复用）、`modules/backup`、`modules/iptv`；
  PopularController/FavoriteController/AreasController 经 `common/index.dart` 全局读取。
  全局注册见 `lib/common/global/initial_services.dart:34-39`（MyCategoryController 为 permanent，:35）。
- 设置页（`features/settings/zishu_settings_view.dart`）为可嵌入视图（`embedded: true`），
  由壳层顶栏/账号菜单 `Get.to` 推入（zishu_app_shell.dart:215-223），不是主导航 menu；
  内部子项直接复用 `modules/settings/pages/` 既有设置页。

## 2. 外壳矩阵（宽屏 / 窄屏 / 断点）

- **分发**：`lib/modules/home/home_page.dart:232-271` LayoutBuilder 按
  `AppBreakpoints.phone = 768`（`lib/zishu/presentation/design_tokens.dart:795`）二选一：
  `<768 → ZishuPhoneShell`，`≥768 → ZishuAppShell`（home_page.dart:236,256-270）。
  popular/areas 页内部 `Get.width<=680` 的旧口径本轮不动（home_page.dart:234-235 注释）。
- **宽屏 ZishuAppShell**（`lib/zishu_app/shell/zishu_app_shell.dart`）：
  - 44px 顶栏（`AppSpacing.topNavHeight`，design_tokens.dart:339；`_TopBar` :502）：
    品牌 / 平台 tab / 关注钮 / 设置，平台 tab 悬停触发分类浮层；
  - 可折叠浏览侧栏（`_BrowseSidebar` :853）：展开 220 / 收起 52，右缘外挂 13.6×44 突出折叠钮
    （`AppDirectoryDrawer` 令牌，design_tokens.dart:825-892）；平台色块统一 44×44、选中 accent 描边（:1095）；
  - hover flyout 状态机：平台 tab 300ms 开门 / 全局 800ms 延迟关门（:71-74，对齐 zishu `_kHoverCloseDelay`），
    浮层 Stack 覆盖 Scaffold 之上（`_buildFlyouts` :435）；flyouts 实现 5 件
    （`shell/flyouts/`：zishu_hover_overlay / zishu_category_flyout（类名 ZishuPlatformCategoryFlyout）/
    zishu_follow_flyout / zishu_my_category_flyout / zishu_user_area）；点浮层分类走 `_openCategoryFromFlyout` →
    `AppNavigator.toCategoryDetail`，与侧栏热门分类同一入口（:192-195）；
  - Ctrl+F / Ctrl+K 全局搜索（:372-376），`_searchOpening` 防重入（:102-104），
    弹窗为 `features/search/zishu_search_dialog.dart`（数据走既有 SearchController，按
    `zishu-search-dialog` tag 隔离，房间号 ≥3 位纯数字直达）；
  - 内容分发 `_contentForMenu`（:319-333）：popular→`ZishuBrowseView(siteId)`、favorites→`ZishuFollowView`、
    areas→`ZishuAreasView`、record→`ZishuRecorderView`，四个 menu 全量接管。
- **窄屏 ZishuPhoneShell**（`lib/zishu_app/shell/phone/zishu_phone_shell.dart`）：
  顶部 `ZishuPhonePlatformStrip`（竖屏 2 行×6 列宫格 / 横屏单行横滚，`zishu_phone_platform_strip.dart:7-12`）
  + 底部 `ZishuPhoneBottomNav`（56px 七项：logo/首页/分类/我的分类/关注/搜索/主题，
  `zishu_phone_bottom_nav.dart:11`，高度令牌 design_tokens.dart:342）；长按平台格或 ▼ 开
  `ZishuPhoneCategorySheet` 分类底部面板（zishu_phone_shell.dart:14-19,187）。
- **`_pageForMenu` 兜底**（home_page.dart:60-74）：窄屏外壳无内容分发，四个 tab 的 body 仍由本页按需提供，
  且**渲染的是旧 pure_live 页**（FavoritePage/PopularPage/AreasPage/RecorderPage）；宽屏 body 恒
  `SizedBox.shrink()`（home_page.dart:266，`_contentForMenu` 覆盖全部 menu、兜底分支不可达）。
  即：窄屏 = zishu chrome + 旧内容页，宽屏 = zishu chrome + zishu 视图。
- 两壳平台上下文同源：`_selectSiteId` 切平台时同步驱动热门页与分区页 tabController
  （zishu_app_shell.dart:283-302 / zishu_phone_shell.dart:106-126，「平台即全局站点上下文」）。

## 3. 播放页

- **路由接线**：`lib/routes/app_pages.dart:95-100`，`RoutePath.kLivePlay → ZishuPlayView()`，
  binding 仍是 `LivePlayBinding()`（控制器不变，仅替换页面体）。
- **布局**（`lib/zishu_app/features/play/zishu_play_view.dart:25-36,128-185`，U5 左右布局）：
  `Row[左列(房间头 _ZishuRoomHeader + Expanded 舞台帧), 侧栏 ZishuPlaySidePanel]`；
  `<768` 侧栏堆叠到视频下方 flex 3:2（:137,159-171）；舞台 ClipRRect 12px、`<640` 为 0（:140）。
- **`VideoControllerPanel.renderLegacyBars` 开关**：定义于
  `lib/modules/live_play/widgets/video_player/video_controller_panel.dart:123`（默认 true）；
  ZishuPlayView 在 initState 置 false（zishu_play_view.dart:57-62）。判定在面板 build 内
  （video_controller_panel.dart:155-161）：**仅常规态**（normal 且非 PiP）跳过旧顶栏/底栏；
  沉浸态（全屏/网页全屏/竖屏全屏）与 PiP 面板自行恢复完整渲染。手势层/弹幕/锁定逻辑不受影响。
- **on-video 接管**：舞台 Stack（zishu_play_view.dart:191-212）= `LivePlayVideo(expandToParent: true)`
  + 睡眠定时徽章 + 底部居中 `ZishuPlayerControlsBar`（播放器就位前不挂，:200-208）。
  控制条（`zishu_player_controls.dart`）：48px 单行压渐变 scrim，左组播放/刷新/弹幕开关「弹」/弹幕设置
  popover，右组静音/音量 96px/画质/线路/画中画/宽屏 W/全屏 F（:1-18 文档）；显隐完全由既有
  `VideoController.showController`/`isMenuOpen` 驱动（:108-118），弹幕设置写 VideoController 的 Rx 字段（:15-17）。
- **沉浸态**：`screenMode != normal && !isInPip`（zishu_play_view.dart:80）→ `LivePlayContent` 整块复用
  + `ZishuPlayImmersiveSheet` 右缘抽屉（:86-98）；PiP 完全交 `LivePlayContent`（:82-84）。
  沉浸抽屉（`zishu_play_immersive_sheet.dart`）：18.4×40 左圆角把手 + 全高面板（宽按视口分档
  268/328/392/425，:52-54），3s 无交互自动收起、面板内交互重置计时（:94-110），250ms 出入动效。
- **键盘**：既有 `VideoKeyboardShortcuts`（Space/R/↑↓/Esc）+ zishu 扩展
  `ZishuPlayKeyboardShortcutsExt`（M 静音/F 全屏/W 宽屏），zishu_play_view.dart:102-123。
- **侧栏内容**（`features/play/zishu_play_side_panel.dart:5-13`）：surface 底 + 「聊天/关注/推荐/设置」
  四等分 tab——聊天接既有 `DanmakuTabView`、关注接 `FavoriteController`、推荐接 `PopularController`
  分类房间流、设置跳既有路由；常规态与沉浸态共用同一组件。

## 4. 设计口径

- **accent 紫 vs brand 金的语义分工**（用户口径 2026-09-20，`lib/zishu/presentation/zishu_tokens.dart:57-63`）：
  控件强调（slider/开关/复选/选中态/进度/CTA）一律品牌紫 `accent`（dark `#7C4DFF` :128 / light `#6A1B9A` :167）；
  金色只做收藏星等 web 对齐功能色 `brand`（dark `#F3D04E` :125 / light `#C9A227` :164），
  金色不再充当控件色。`brandBright`（dark `#F5DC70` / light `#9A7B1A`）是「轮播/回放」独立亮金档，
  **必须随主题切换**（浅底上亮金不可读，:50-55）。
- 分工实例：选中态用 accent（平台块描边 zishu_app_shell.dart:690,1095）；收藏/品牌用 brandBright
  （顶栏关注钮激活 zishu_app_shell.dart:557、播放页收藏星 zishu_play_view.dart:340、关注列表角标
  zishu_follow_room_list.dart:270）。播放页房间头徽标的前景回退也按此语义：回退平台色底时按底亮度取
  `AppOnVideo.text` / `AppOnBright.text` 恒定前景，不再随主题翻转（zishu_play_view.dart:282-285）。
- 注意：`colorScheme.primary/secondary` 接的是 **brand 金**而非 accent（`lib/zishu/presentation/app_theme.dart:20-25`
  注释：对齐 pure_live web 线拍板；若要回紫改 `tokens.accent`）。
- **AppOnVideo 恒亮族**（design_tokens.dart:8-50）：叠在视频画面上的控件恒定暗色语义
  （scrim/bar/text/captionPill/popoverBg），**不随主题翻转**；on-video accent 恒取亮紫 `#7C4DFF`。
  on-video 控件的 hover/pressed/focus 墨色也恒亮（`_onVideoInkTheme`，zishu_player_controls.dart:31-39）。
- **浅色对比度修复纪要**：浅色 accent `#6A1B9A` 在暗 popover 上对比 2.0:1 不足，故 on-video 语境统一取
  恒亮值（design_tokens.dart:43-46）；accent 底上前景一律白（浅色下黑前景仅 2.24:1 属无障碍缺陷，
  `AppOnBright` 裁决 design_tokens.dart:52-74）；brandBright/统计色等浅色值降明度同色系
  （zishu_tokens.dart:158-183）。

## 5. 数据契约

- **`savedPlatformIds`**（`lib/common/services/settings/app_settings_controller.dart:75-77`）：
  站点 id 列表 = 外壳平台入口的**顺序 + 可见性**（不在列表内 = 隐藏），默认 `Sites.supportSites` 前 10；
  onInit 归一化（:84-85），`togglePlatformVisibility` 保证至少 1 个可见（:198-206）。
  两壳同口径消费：严格按列表顺序渲染、未保存不渲染（`_visibleSites`：zishu_app_shell.dart:335-350 /
  zishu_phone_shell.dart:144-157）；设置入口 `lib/modules/settings/pages/platform_order_settings_page.dart`。
  主导航 tab 同理由 `savedMenuIds` 驱动（home_page.dart:123-144 worker 监听）。
- **`LiveRoom.typeName` 语义**（字段 `lib/common/models/live_room.dart:266`）：**平台相关，层级不一**——
  B站 = 一级分区名（`parent_name`/`area_v2_parent_name`/`parent_area_name`，
  `lib/core/site/bilibili/bilibili_site.dart:87,127,718`）；虎牙 = gameFullName（
  `lib/core/site/huya/huya_site.dart:231,553,719`）；斗鱼 = 二级名（`c2name`/`second_lvl_name`，
  `lib/core/site/douyu/douyu_site.dart:146,551`）。房间卡 chips 消费：typeName 非 1 个 + area 非空且
  ≠ typeName 1 个，双空保留空占位行保证等高（`zishu_app/features/browse/zishu_room_card.dart:52-53,89-91`）。
  展示名经跨平台中文映射归一：`displayCategoryName`（`lib/zishu/domain/category_display.dart:278-305`）。
- **`MyCategoryController`**（`lib/zishu_app/features/play/my_category_controller.dart`）：跨平台「我的分类」
  收藏。已收藏判定优先跨平台 key（`cross|<key>`，未命中映射表退 `raw|<site>|<name>`，:49-60）——收藏任一平台
  的「英雄联盟」，全平台都算已收藏；上限 12（:31，对齐 `MAX_MY_CROSS_CATEGORIES`）；Hive 存储
  `zishu_app.myCategories.v1`（:28）；`lib/common/global/initial_services.dart:35` permanent 注册。
  播放页收藏星调用 `toggle`（zishu_play_view.dart:253-265）。

## 6. 已知边界

- **不迁**（zishu 侧 fixture/参考实现存在，本仓库无对应 UI，接线时勿误以为缺失损坏）：
  - **主播页**：`lib/zishu/presentation/platform_brands.dart:192-196` 仅保留 `anchorSearch` 能力位
    （搜索弹框「主播/房间」双档之用），`lib/zishu_app/` 目前无任何消费方，也无主播详情页；
  - **时间线**：`lib/zishu_app/` 无任何 timeline 代码（全文检索无命中）；
  - **字幕翻译**：`AppOnVideo.captionPill*` 令牌已随设计系统搬入（design_tokens.dart:21-34），
    但全仓无 widget 消费——功能 UI 未迁，令牌先行。
- **flame_barrage 弹幕引擎保留**：`pubspec.yaml:60`（^0.0.7），既有弹幕渲染链
  `lib/modules/live_play/widgets/danmaku/compact_danmaku_overlay.dart:3` 等继续使用；
  zishu 控制条只读写 `VideoController` 的弹幕 Rx 字段（zishu_player_controls.dart:15-17），不换引擎。
- **跨平台分类映射为内置常量表**：`kCrossCategories` 由 `tool/sync_cross_map.dart` 生成后内置
  （`lib/zishu/domain/category_display.dart:6-7`），运行时不依赖服务端下发；改分类数据先跑生成工具，
  勿手改 `cross_categories_data.dart`。
- **录制中心**是 pure_live 独有功能、zishu 无对应页面，按 zishu 设计语言全新绘制
  （`zishu_app/features/record/zishu_recorder_view.dart:1-8`），数据全走既有 `RecorderController`。
- **陈旧注释预警**：`lib/zishu_app/shell/zishu_app_shell.dart:318`「录制仍走旧页面体」与
  `_contentForMenu` 实际返回 `ZishuRecorderView`（:329-331）不符，改录制页时顺带修正。
- zishu fixture 构建口径（离线 UI 测试全量导航目录）见 platform_brands.dart:5-6,78-81。
- 本文档为纯文档产出：撰写过程中仅做只读核对（grep/读源），未运行 `flutter analyze`/build/测试
  （任务规约禁止）；文中全部行号均在 2026-10-01 逐一对照源码核实。
