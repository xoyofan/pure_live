# 首页外壳换布局方案（2026-09-30）

> 状态：**已规划、未实施**。本文记录经代码探索确认的改造方案，实施时以当前 `HEAD` 复核行号后执行。

## 背景与目标

解析核心（`lib/core/`）已通过注入点（CoreLog runtime、代理指令、Cookie、按房间音量，见 `lib/common/services/parser_runtime_binding.dart`）与 Flutter 应用解耦，同一份解析源码可编译为 Dart sidecar 供 streamingserver 调用。在此基础上，用户要求更换 **Flutter 应用前端** 的 UI 布局（仅换布局，不动解析与业务逻辑）。

现外壳为「窄屏底部 `NavigationBar` + 宽屏左侧 `NavigationRail`」。目标布局：

- **宽屏（>680px，Windows/平板）**：左侧常驻侧边栏（约 200dp，图标 + 文字 + 分区），内容区全宽。
- **窄屏（≤680px，手机）**：AppBar ☰ 拉出 `NavigationDrawer` 抽屉，导航项与侧边栏同源。

页面、控制器、网格、卡片、路由全部复用，只重写导航外壳。

## 现状基线（探索结论）

- 外壳不是独立的 app_view，而是 `lib/modules/home/home_page.dart`（292 行）：
  - `_pageMap` 持有 4 个 const 页面：关注 / 热门 / 分区 / 录制（`HomeMenu` 枚举，`lib/common/consts/app_consts.dart:6-18`），按 `savedMenuIds` 虚实索引映射切换，无 IndexedStack。
  - 断点 `constraint.maxWidth > 680`（home_page.dart:232）分发到 `HomeMobileView`（mobile_view.dart，底部 NavigationBar）或 `HomeTabletView`（tablet_view.dart，NavigationRail + leading 图标列）。
  - 宽屏强制剔除录制页（home_page.dart:118-121、169-171、236-238、247），仅保留 rail leading 图标与路由入口。
- 隐藏契约（重写时必须原样保留）：
  - `FavoriteController.tabBottomIndex` 双向同步（home_page.dart:106-111、195）；
  - `savedMenuIds` 的 `ever` worker 重建/重选（home_page.dart:113-138）；
  - Android `PopScope` → MoveToDesktop、启动更新检查、resume 刷新、edge-to-edge、命令行初始房间接管（home_page.dart:72-104、141-165、218-222）。
- 四个 tab 页 AppBar 以 `Get.width <= 680` 决定是否显示 leading `MenuButton` 与 `CommonAppBarActions`（favorite_page.dart:17、popular_page.dart:15、areas_page.dart:18、recorder_page.dart:29）。
- `MenuButton`（lib/common/widgets/menu_button.dart）= 设置/关于/历史/备份/新窗口弹窗；`CommonAppBarActions` = 搜索/工具箱/多窗弹窗；宽屏时这两组入口由 rail leading 图标列承担。
- 仓库无 `test/` 目录（仅 `integration_test/` 播放器测试），外壳无既有受影响测试。

## 侧边栏结构（宽屏）

```
┌──────────┬──────────────────────┐
│ Pure Live│  页面内容（不变）      │
│ 🔍 搜索   │                      │
│ ──────── │                      │
│ ⭐ 关注   │                      │
│ 🔥 热门   │                      │
│ 📁 分区   │                      │
│ ⏺ 录制   │                      │
│ ──────── │                      │
│ ⏱ 历史   │                      │
│ 🖥 多窗*  │                      │
│ 🧰 工具箱 │                      │
│ ☁ 备份    │                      │
│ ℹ 关于    │                      │
│ ⚙ 设置    │                      │
│ ＋新窗口* │                      │
└──────────┴──────────────────────┘
```

- 主导航项由 `SettingsService.to.app.savedMenuIds` 动态生成，顺序/可见性仍由 设置→导航（`navigation_settings_page.dart`）管理，设置页不改。
- **录制页在桌面端转为正常导航项**：删除 home_page.dart 中宽屏剔除 record 的特例；侧边栏空间充足，逻辑更简单（唯一行为变化）。
- 次级项覆盖现 `MenuButton` + `CommonAppBarActions` + rail leading 的全部入口；多窗受 `enableMultiView`、新窗口受 Windows + `enableNewWindowPlay` 控制。
- 全部复用现有 i18n key（favorites_title、popular_title、areas_title、record_center、search_live、history、backup_recover、settings_title、about、multiview_title、open_link 等），不新增文案。
- 选中态沿用主题（rounded `secondaryContainer` 容器），不自造颜色。

## 文件改动清单

新增：

1. `lib/modules/home/home_nav_items.dart` — 共享导航项模型与构建（图标/选中图标/label key/主次分区/路由或菜单 index），侧边栏与抽屉共用一份。
2. `lib/modules/home/home_sidebar_view.dart` — 宽屏常驻侧边栏（`Row`：侧栏 + `Expanded(body)`）。
3. `lib/modules/home/home_drawer_view.dart` — 窄屏外壳：`Scaffold(drawer: NavigationDrawer(...), body: body)`。
4. `lib/modules/home/home_drawer_button.dart` — ☰ 按钮，经外壳持有的 `GlobalKey<ScaffoldState>` 打开抽屉（嵌套 Scaffold 无法用 `Scaffold.of` 向上找到外层抽屉）。

修改：

5. `lib/modules/home/home_page.dart` — 断点分发改为两个新视图；删除宽屏剔除 record 特例；initState 注册 / dispose 清理抽屉 GlobalKey；其余契约逻辑不动；`_pageMap` 保持 const。
6. 四个 tab 页 AppBar leading（`showAction` 手机分支）：`MenuButton()` → `HomeDrawerButton()`；宽屏分支与 `CommonAppBarActions` 不动。

删除：

7. `lib/modules/home/mobile_view.dart`、`lib/modules/home/tablet_view.dart`。

## 明确不动

页面内部布局（网格/卡片/BasePageView/分页）、主题系统、live_play、设置子页、路由表、`NavigationSettingsPage`；全库其余 `680` 断点（base 分页、live_play 布局、multiview 等）属内容层逻辑，与外壳无关。

## 验证口径

- 实施后跑一次 `tool/flutterw.ps1 analyze`；`dart format` 仅格式化改动文件（排除 `lib/core/scripts/douyin_sign.dart`）。
- 无受影响测试可跑；可选本地 Windows debug 冒烟确认侧栏/抽屉/选中态/设置同步。
- 纯 UI 外壳改动：不触发版本号与 Android 发布批次。

## 风险与回退

- 主要风险是 `tabBottomIndex` 同步与 `savedMenuIds` 虚实索引映射——新视图只消费传入的 `index` / `activeMenuIds` / `onDestinationSelected`（签名对齐现 `HomeTabletView`）。
- 回退干净：新增文件独立，删除的两个视图可从 git 恢复。
