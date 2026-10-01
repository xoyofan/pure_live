import 'dart:async';

import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/core/site/cc/cc_catalog.dart';
import 'package:pure_live/modules/areas/areas_list_controller.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/zishu/domain/category_display.dart';
import 'package:pure_live/zishu/domain/category_sections.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/platform_brands.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/platform_icon.dart';
import 'package:pure_live/zishu_app/features/areas/zishu_areas_view.dart';
import 'package:pure_live/zishu_app/features/record/zishu_recorder_view.dart';
import 'package:pure_live/zishu_app/features/browse/zishu_browse_view.dart';
import 'package:pure_live/zishu_app/features/follow/zishu_follow_view.dart';
import 'package:pure_live/zishu_app/features/search/zishu_search_dialog.dart';
import 'package:pure_live/zishu_app/features/settings/zishu_settings_view.dart';
import 'package:pure_live/zishu_app/shell/category_warmup.dart';
import 'package:pure_live/zishu_app/shell/flyouts/zishu_my_category_flyout.dart';
import 'package:pure_live/zishu_app/shell/zishu_app_nav_shortcuts.dart';
import 'package:pure_live/zishu_app/shell/zishu_shell_flyout_machine.dart';
import 'package:pure_live/zishu_app/shell/zishu_shell_top_bar.dart';

/// zishu 前端移植主外壳(宽屏 >680):44px 顶栏 + 可折叠浏览侧栏。
///
/// 新目录 `lib/zishu_app/` 按"照搬 zishu 前端 + pure_live 解析"路线组建;
/// 本壳对齐 zishu browse_sidebar:侧栏展开 220 / 收起 52
/// ([AppDirectoryDrawer]),折叠把手 13.6×44(仅右侧 4px 圆角)悬浮于
/// 内容区左缘(不占布局宽,见 build 的 Stack);平台块统一 44×44、
/// 横向 Wrap 自动换行。
///
/// 分类详情外壳内两级:[selectAreaCategory] 是全部分类入口(侧栏热门
/// 分类/顶栏平台浮层 chips/我的分类 chips/分区封面格)的统一收口 —— 切到
/// 分区 tab 并把分类交给 [ZishuAreasView] 内嵌渲染(不再推 kAreaRooms
/// 路由);CC 官方入口维持外链回落。
class ZishuAppShell extends StatefulWidget {
  final Widget body;
  final int index;
  final List<String> activeMenuIds;
  final void Function(int) onDestinationSelected;

  const ZishuAppShell({
    super.key,
    required this.body,
    required this.index,
    required this.activeMenuIds,
    required this.onDestinationSelected,
  });

  @override
  State<ZishuAppShell> createState() => _ZishuAppShellState();
}

class _ZishuAppShellState extends State<ZishuAppShell> with ZishuShellFlyoutMachine {
  static const List<String> _hotCategories = [
    '英雄联盟',
    '王者荣耀',
    '和平精英',
    'CS2',
    'DOTA2',
    '无畏契约',
    '原神',
    '我的世界',
    '穿越火线',
    '棋牌桌游',
    '体育',
    '户外',
    '美食',
    '影视娱乐',
    '二次元',
  ];

  /// 侧栏宽/把手位动画时长(展开 220 ↔ 收起 52):侧栏本体
  /// AnimatedContainer 与外壳把手的 AnimatedPositioned 同源同曲线。
  /// 对齐真源 browse_sidebar 的 AnimatedContainer(AppMotion.normal,
  /// AppMotion.curve),不走裸数值。
  static const Duration _kSidebarWidthAnimDuration = AppMotion.normal;

  PopularController? _popular;
  VoidCallback? _tabListener;
  bool _bound = false;
  bool _collapsed = false;
  int _siteIndex = 0;
  AreasController? _areas;
  VoidCallback? _areasTabListener;
  bool _areasBound = false;
  int _areasSiteIndex = 0;

  // ---- 外壳内分类详情(分区 tab 两级) ----

  /// 待打开分类代数:每采纳一次分类自增。ZishuAreasView 以「代数变化」
  /// 识别重新应用 initialCategory —— 同一分类重复点选也要重建控制器。
  int? _pendingAreaCategory;

  /// 待打开分类及其所属站点(与代数同步更新,建控制器要 Site)。
  Site? _pendingCategorySite;
  LiveArea? _pendingCategoryArea;

  // ---- hover 浮层态机(scheduleFlyoutClose / buildFlyoutOverlays 等) ----
  // 挂在 [ZishuShellFlyoutMachine]:与播放页共用同一份开/关调度与浮层渲染。

  /// 搜索防重入:showZishuSearchDialog 本身不防叠,连按两次 Ctrl+F 会开
  /// 两层(对齐 zishu 真源 `_searchOpening` 同款处理)。
  bool _searchOpening = false;

  /// Ctrl+F / Ctrl+K 全局搜索快捷键的焦点锚点:CallbackShortcuts 需要
  /// 一个持有焦点的 Focus 才能在气泡阶段收到按键;本壳层恒在 home 路由
  /// 顶层且覆盖整页,焦点空闲时由它兜底持有。
  final FocusNode _shortcutFocusNode = FocusNode(debugLabel: 'zishu-app-shell-shortcuts');

  /// 关注浮层点小卡:先收浮层,再进播放页。
  void _openRoomFromFlyout(LiveRoom room) {
    closeAllFlyouts();
    unawaited(AppNavigator.toLiveRoomDetail(liveRoom: room));
  }

  /// 分类详情统一入口:先收浮层,再切分区 tab 内嵌打开(需要 Site 对象)。
  ///
  /// 分类入口统一收口(侧栏热门分类/顶栏平台浮层 chips/我的分类 chips/
  /// 分区封面格都走这里):切到分区 tab 并把分类交给 [ZishuAreasView]
  /// 内嵌渲染(外壳内两级,不再推 kAreaRooms 路由)。
  void selectAreaCategory(Site site, LiveArea area) {
    if (!mounted) return;
    closeAllFlyouts();
    // CC 官方入口是外链分类,不进内嵌房间流(对齐
    // AppNavigator.toCategoryDetail 的口径,维持既有外链/提示行为)。
    if (CCCatalog.isOfficialEntry(area)) {
      unawaited(AppNavigator.toCategoryDetail(site: site, category: area));
      return;
    }
    _pendingCategorySite = site;
    _pendingCategoryArea = area;
    setState(() => _pendingAreaCategory = (_pendingAreaCategory ?? 0) + 1);
    _navigateToMenu(HomeMenu.areas.index);
    // 分区页站点对齐分类所属站:目标站点的目录面板要在前台
    // (_currentSiteId 同步,同 _selectSiteId 的处理)。
    _bindAreas();
    if (_areas != null) {
      final areasIndex = _areas!.sites.indexWhere((s) => s.id == site.id);
      if (areasIndex >= 0) _areas!.tabController.animateTo(areasIndex);
    }
  }

  /// 菜单导航收口:离开分区 tab 时作废内嵌分类详情态(重进分区回索引页,
  /// 不把详情态带过页)。
  void _navigateToMenu(int index) {
    if (index != HomeMenu.areas.index) {
      _pendingAreaCategory = null;
      _pendingCategorySite = null;
      _pendingCategoryArea = null;
    }
    widget.onDestinationSelected(index);
  }

  Site? _siteById(String siteId) {
    for (final site in _sites) {
      if (site.id == siteId) return site;
    }
    return null;
  }

  Site? get _currentSite {
    final id = _currentSiteId;
    return id == null ? null : _siteById(id);
  }

  void _openSearchAction() {
    if (_searchOpening || !mounted) return;
    _searchOpening = true;
    unawaited(showZishuSearchDialog(context).whenComplete(() => _searchOpening = false));
  }

  /// zishu 设置弹窗入口(顶栏设置钮与账号菜单共用同一份)。
  ///
  /// 对齐 zishu openSettingsDialog 口径:弹对话框而非推整页
  /// (弹窗框与内嵌视图见 zishu_settings_view.dart)。
  void _openSettingsDialog() {
    unawaited(openZishuSettingsDialog(context));
  }

  /// F5 浏览器式刷新的壳层落地(对齐真源 refreshPlay > refreshHome 的
  /// 注册分发):按当前主导航页直发对应控制器刷新,菜单未挂控制器时
  /// 静默(真源「未注册即静默」同口径)。播放页在 kLivePlay 路由持有
  /// 焦点时本壳收不到按键,无 refreshPlay 注册点(播放页域外,本轨不碰
  /// zishu_play_view);录制页 RecorderController 无公开刷新口径,同样静默。
  void _refreshCurrentPage() {
    final index = widget.index;
    if (index == HomeMenu.popular.index) {
      _bindPopular();
      final popular = _popular;
      if (popular != null) unawaited(popular.refreshCurrentData());
    } else if (index == HomeMenu.areas.index) {
      _bindAreas();
      final areas = _areas;
      if (areas != null) unawaited(areas.refreshCurrentData());
    } else if (index == HomeMenu.favorites.index) {
      if (Get.isRegistered<FavoriteController>()) {
        unawaited(Get.find<FavoriteController>().refreshData());
      }
    }
    // 录制页:RecorderController 无公开刷新口径,静默(真源未注册即静默)。
  }

  @override
  void initState() {
    super.initState();
    _bindPopular();
    _bindAreas();
    // 分类目录预热:首帧后延迟 2s 启动(不与首屏抢带宽),悬停分类 flyout 秒开。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 2), CategoryWarmup.schedule);
    });
  }

  @override
  void didUpdateWidget(covariant ZishuAppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bindPopular();
    _bindAreas();
  }

  void _bindPopular() {
    if (_bound) return;
    if (!Get.isRegistered<PopularController>()) return;
    final controller = Get.find<PopularController>();
    _tabListener = () {
      if (mounted && controller.tabController.index >= 0) {
        setState(() => _siteIndex = controller.tabController.index);
      }
    };
    controller.tabController.addListener(_tabListener!);
    if (controller.tabController.index >= 0) _siteIndex = controller.tabController.index;
    _popular = controller;
    _bound = true;
  }

  @override
  void dispose() {
    disposeFlyoutMachine();
    _shortcutFocusNode.dispose();
    if (_popular != null && _tabListener != null) {
      _popular!.tabController.removeListener(_tabListener!);
    }
    if (_areas != null && _areasTabListener != null) {
      _areas!.tabController.removeListener(_areasTabListener!);
    }
    super.dispose();
  }

  void _bindAreas() {
    if (_areasBound) return;
    if (!Get.isRegistered<AreasController>()) return;
    final controller = Get.find<AreasController>();
    _areasTabListener = () {
      if (mounted && controller.tabController.index >= 0) {
        setState(() => _areasSiteIndex = controller.tabController.index);
      }
    };
    controller.tabController.addListener(_areasTabListener!);
    if (controller.tabController.index >= 0) _areasSiteIndex = controller.tabController.index;
    _areas = controller;
    _areasBound = true;
  }

  void _selectSiteId(String siteId) {
    if (widget.index != HomeMenu.popular.index) {
      _navigateToMenu(HomeMenu.popular.index);
    }
    _bindPopular();
    final controller = _popular;
    if (controller != null) {
      final fullIndex = controller.sites.indexWhere((s) => s.id == siteId);
      if (fullIndex >= 0) {
        controller.tabController.animateTo(fullIndex);
        if (mounted) setState(() => _siteIndex = fullIndex);
      }
    }
    // 平台即全局站点上下文:分区页同步切到同一站点(存在时)。
    _bindAreas();
    if (_areas != null) {
      final areasIndex = _areas!.sites.indexWhere((s) => s.id == siteId);
      if (areasIndex >= 0) _areas!.tabController.animateTo(areasIndex);
    }
  }

  List<Site> get _sites => _popular?.sites ?? const <Site>[];

  /// 当前站点 id 按激活页取源:分区页跟 AreasController,其余跟热门页。
  String? get _currentSiteId {
    if (widget.index == HomeMenu.areas.index) {
      final sites = _areas?.sites ?? const <Site>[];
      if (_areasSiteIndex >= 0 && _areasSiteIndex < sites.length) return sites[_areasSiteIndex].id;
      return null;
    }
    final sites = _sites;
    if (_siteIndex < 0 || _siteIndex >= sites.length) return null;
    return sites[_siteIndex].id;
  }

  /// 内容区:热门/关注/分区已迁 zishu 视图,录制仍走旧页面体。分区视图
  /// 接收外壳待打开分类(initialCategory + 代数 token)与分类入口回调,
  /// 实现外壳内两级分类详情。
  Widget _contentForMenu(int menuIndex, String? currentSiteId) {
    if (menuIndex == HomeMenu.popular.index && currentSiteId != null) {
      return ZishuBrowseView(siteId: currentSiteId);
    }
    if (menuIndex == HomeMenu.favorites.index) {
      return const ZishuFollowView();
    }
    if (menuIndex == HomeMenu.areas.index) {
      return ZishuAreasView(
        initialCategory: _pendingCategoryArea,
        initialCategorySite: _pendingCategorySite,
        categoryToken: _pendingAreaCategory,
        onOpenCategory: selectAreaCategory,
      );
    }
    if (menuIndex == HomeMenu.record.index) {
      return const ZishuRecorderView();
    }
    return widget.body;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (widget.activeMenuIds.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: AppStatusView(
            type: AppStatusType.empty,
            icon: Remix.menu_2_fill,
            title: i18n('no_menu_title'),
            subtitle: i18n('no_menu_subtitle'),
          ),
        ),
      );
    }
    // 全局导航快捷键(Alt+←/→/Home、F5、鼠标侧键 X1/X2,对齐真源
    // app_nav_shortcuts):包住整棵壳层 —— 内层 CallbackShortcuts 先收
    // Ctrl+F/K,Alt/F5 沿焦点祖先链冒泡到外层;Listener opaque 让空白区
    // 也参与命中(侧键是落点无关手势)。挂点先例与 Focus 冒泡语义同
    // 既有 Ctrl+F/K 挂点。
    return ZishuAppNavShortcuts(
      index: widget.index,
      onNavigateToMenu: _navigateToMenu,
      onRefreshCurrentPage: _refreshCurrentPage,
      child: Stack(
        children: [
          // Ctrl+F / Ctrl+K 全局搜索:CallbackShortcuts 在焦点气泡阶段收键;
          // Focus(autofocus) 让壳层在无其他焦点者时兜底持有焦点。壳层覆盖
          // 整页内容,页内任何控件持有焦点时按键也会沿祖先链回到这里。
          CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.keyF, control: true): _openSearchAction,
              const SingleActivator(LogicalKeyboardKey.keyK, control: true): _openSearchAction,
            },
            child: Focus(
              focusNode: _shortcutFocusNode,
              autofocus: true,
              child: Theme(
                // 交互态收口:外壳根部统一 focus 色(键盘导航可见)。
                data: Theme.of(context).copyWith(focusColor: AppStateLayer.focusOf(tokens.accent)),
                child: Scaffold(
                  backgroundColor: tokens.background,
                  body: SafeArea(
                    // Obx 覆盖平台入口区:订阅 savedPlatformIds 与热门页站点表
                    // (visibleTopBarSites 内读 Rx,与顶栏/侧栏共用同一份)。
                    child: Obx(() {
                      final visibleSites = visibleTopBarSites();
                      return Column(
                        children: [
                          ZishuShellTopBar(
                            index: widget.index,
                            sites: visibleSites,
                            currentSiteId: _currentSiteId,
                            // 平台 tab 选中口径:仅热门页随站点高亮(分区/关注页不亮)。
                            platformTabsActive: widget.index == HomeMenu.popular.index,
                            onSelectMenu: _navigateToMenu,
                            onSelectSite: _selectSiteId,
                            onPlatformHoverStart: schedulePlatformFlyout,
                            onPlatformHoverEnd: cancelPlatformFlyoutOpen,
                            onFollowHoverStart: openFollowFlyout,
                            onFollowHoverEnd: scheduleFlyoutClose,
                            onMyCategoryHoverStart: scheduleMyCategoryFlyout,
                            onMyCategoryTap: toggleMyCategoryFlyout,
                            onMyCategoryHoverEnd: cancelMyCategoryFlyoutOpen,
                            onOpenSettings: _openSettingsDialog,
                          ),
                          const Divider(height: 1, thickness: 1),
                          Expanded(
                            // 折叠把手悬浮化:侧栏本体纯宽(220/52),Row 外包
                            // Stack,把手 Positioned 浮于内容区左缘(z 序高,
                            // Material+elevation 出投影),不再占布局宽。
                            child: Stack(
                              children: [
                                Row(
                                  children: [
                                    _BrowseSidebar(
                                      index: widget.index,
                                      sites: visibleSites,
                                      currentSiteId: _currentSiteId,
                                      collapsed: _collapsed,
                                      onSelectSite: _selectSiteId,
                                      onSelectMenu: _navigateToMenu,
                                      categorySite: _currentSite,
                                      onOpenCategory: selectAreaCategory,
                                    ),
                                    const VerticalDivider(width: 1, thickness: 1),
                                    Expanded(child: _contentForMenu(widget.index, _currentSiteId)),
                                  ],
                                ),
                                // 突出折叠把手:贴侧栏右缘悬浮(top:0/bottom:0 +
                                // Center = 布局垂直中部);宽度动画期间用
                                // AnimatedPositioned(与侧栏 AnimatedContainer
                                // 同时长同曲线)同步贴住侧栏当前宽。
                                AnimatedPositioned(
                                  duration: _kSidebarWidthAnimDuration,
                                  curve: AppMotion.curve,
                                  left: _collapsed ? AppDirectoryDrawer.railWidth : AppDirectoryDrawer.width,
                                  top: 0,
                                  bottom: 0,
                                  child: Center(
                                    child: Material(
                                      color: tokens.surface,
                                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                                      elevation: 1,
                                      child: InkWell(
                                        onTap: () => setState(() => _collapsed = !_collapsed),
                                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                                        focusColor: Theme.of(context).focusColor,
                                        child: SizedBox(
                                          width: AppDirectoryDrawer.toggleWidth,
                                          height: AppDirectoryDrawer.toggleHeight,
                                          child: Icon(
                                            _collapsed ? Remix.arrow_right_s_line : Remix.arrow_left_s_line,
                                            size: 16,
                                            color: tokens.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
          // hover 浮层:Stack 覆盖在外壳最上层(Scaffold 之外)。
          ...buildFlyoutOverlays(
            siteById: _siteById,
            onOpenCategory: selectAreaCategory,
            onOpenRoom: _openRoomFromFlyout,
          ),
        ],
      ),
    );
  }
}

/// 可折叠浏览侧栏:展开 220 / 收起 52(纯宽,折叠把手悬浮于外壳内容区
/// 左缘,见 _ZishuAppShellState.build 的 Stack,本组件不再占把手宽)。
///
/// 展开态 = 平台统一色块(44×44,Wrap 横向换行)+ 我的分类(内嵌展开)+
/// 热门分类 + 录制;收起态 = 平台图标竖排。宽度动画走 AnimatedContainer,
/// 与外壳把手的 AnimatedPositioned 同时长同曲线(把手贴右缘随动)。
class _BrowseSidebar extends StatelessWidget {
  final int index;
  final List<Site> sites;
  final String? currentSiteId;
  final bool collapsed;
  final void Function(String) onSelectSite;
  final void Function(int) onSelectMenu;

  /// 当前选中站点的 [Site] 对象(侧栏热门分类点跳分类详情需要)。
  final Site? categorySite;

  /// 点热门分类跳分类详情(先经壳层,与浮层分类同一入口)。
  final void Function(Site site, LiveArea area) onOpenCategory;

  const _BrowseSidebar({
    required this.index,
    required this.sites,
    required this.currentSiteId,
    required this.collapsed,
    required this.onSelectSite,
    required this.onSelectMenu,
    required this.categorySite,
    required this.onOpenCategory,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final width = collapsed ? AppDirectoryDrawer.railWidth : AppDirectoryDrawer.width;
    return AnimatedContainer(
      duration: _ZishuAppShellState._kSidebarWidthAnimDuration,
      curve: AppMotion.curve,
      width: width,
      color: tokens.surfaceSoft,
      child: collapsed ? _buildCollapsed(context, tokens) : _buildExpanded(context, tokens),
    );
  }

  Widget _buildExpanded(BuildContext context, ZishuTokens tokens) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.sm),
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final site in sites)
              _PlatformBlock(
                site: site,
                selected: site.id == currentSiteId && index == HomeMenu.popular.index,
                onTap: () => onSelectSite(site.id),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        // 「我的分类」入口行 + 内嵌展开区(位于热门分类区上方):点击行
        // 展开/收起收藏 chips,面板与 my_category flyout 同一份内容;
        // chip 点击经壳层 onOpenCategory 进内嵌分类详情。
        _SidebarMyCategorySection(onOpenCategory: onOpenCategory),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: tokens.brand, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('热门分类', style: context.textSecondary),
            ],
          ),
        ),
        _SidebarHotCategories(
          site: categorySite,
          fallback: _ZishuAppShellState._hotCategories,
          onFallbackTap: () => onSelectMenu(HomeMenu.areas.index),
          onOpenCategory: onOpenCategory,
        ),
        const Divider(height: AppSpacing.xl),
        _CategoryRow(
          name: i18n('record_center'),
          icon: Remix.download_2_line,
          selected: index == HomeMenu.record.index,
          onTap: () => onSelectMenu(HomeMenu.record.index),
        ),
      ],
    );
  }

  Widget _buildCollapsed(BuildContext context, ZishuTokens tokens) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.sm),
        for (final site in sites)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: InkResponse(
              onTap: () => onSelectSite(site.id),
              radius: 18,
              hoverColor: tokens.surfaceRaised,
              focusColor: Theme.of(context).focusColor,
              child: Tooltip(
                message: site.name,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: site.id == currentSiteId && index == HomeMenu.popular.index
                        ? tokens.surfaceRaised
                        : Colors.transparent,
                    borderRadius: AppRadius.allMd,
                    border: Border.all(
                      color: site.id == currentSiteId && index == HomeMenu.popular.index
                          ? tokens.accent
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Center(child: PlatformIcon(id: site.id, size: 26)),
                ),
              ),
            ),
          ),
        const Divider(height: AppSpacing.lg),
        InkResponse(
          onTap: () => onSelectMenu(HomeMenu.record.index),
          radius: 18,
          hoverColor: tokens.surfaceRaised,
          focusColor: Theme.of(context).focusColor,
          child: Tooltip(
            message: i18n('record_center'),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                Remix.download_2_line,
                size: 20,
                color: index == HomeMenu.record.index ? tokens.accent : tokens.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 侧栏「我的分类」入口行 + 内嵌展开区:点击行展开/收起收藏 chips(行
/// 图标 Remix.star_line,展开态文字/图标转品牌金,对齐 zishu「收藏分类」
/// 金色语义);展开区复用 [ZishuMyCategoryPanel](与 my_category flyout、
/// 窄屏底栏弹层同一份面板:管理入口 + chips),chip 点击按名称匹配平台
/// 目录后经 [onOpenCategory](壳层 selectAreaCategory)进外壳内嵌分类详情
/// (无宿主可收,close 钩子留空)。
class _SidebarMyCategorySection extends StatefulWidget {
  const _SidebarMyCategorySection({required this.onOpenCategory});

  /// 注入的分类跳转(壳层 selectAreaCategory,收藏 chip 进内嵌分类详情)。
  final void Function(Site site, LiveArea area) onOpenCategory;

  @override
  State<_SidebarMyCategorySection> createState() => _SidebarMyCategorySectionState();
}

class _SidebarMyCategorySectionState extends State<_SidebarMyCategorySection> {
  /// 展开态:本地 State,不持久化(对齐侧栏折叠态口径)。
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CategoryRow(
          name: i18n('my_category_title'),
          icon: Remix.star_line,
          selected: _expanded,
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded) ...[
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: ZishuMyCategoryPanel(onOpenCategory: widget.onOpenCategory),
          ),
        ],
      ],
    );
  }
}

/// 平台色块:统一 44×44,品牌色底 + 平台图标,选中态品牌金描边。
class _PlatformBlock extends StatelessWidget {
  final Site site;
  final bool selected;
  final VoidCallback onTap;

  const _PlatformBlock({required this.site, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final brand = PlatformBrandCatalog.byId(site.id);
    final color = brand?.color ?? tokens.surfaceRaised;
    return Tooltip(
      message: site.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allMd,
        focusColor: Theme.of(context).focusColor,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            borderRadius: AppRadius.allMd,
            border: Border.all(color: selected ? tokens.accent : Colors.transparent, width: 1.5),
          ),
          child: Center(child: PlatformIcon(id: site.id, size: 28)),
        ),
      ),
    );
  }
}

/// 侧栏文字行:热门分类 / 录制。
class _CategoryRow extends StatelessWidget {
  final String name;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryRow({required this.name, required this.onTap, this.icon, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.allSm,
      hoverColor: tokens.surfaceRaised,
      focusColor: Theme.of(context).focusColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 5),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? tokens.brandBright : tokens.textSecondary),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textBody.copyWith(
                  fontSize: 13,
                  color: selected ? tokens.brandBright : tokens.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 侧栏「热门分类」:当前选中站点 `AreasListController.categories` 经
/// [buildCategorySections] 构建分组树(与顶栏 hover 浮层**共用**同一套
/// 一级分区构建,见 `lib/zishu/domain/category_sections.dart`)—— 多组
/// 逐组「组标题行 + 该组全部子分类行」纵向排列(整列由侧栏外层
/// ListView 滚动),单组平铺无组标题;**不设条数上限**。控制器未注册
/// 或目录为空时回落硬编码表(老口径,保证任何时刻侧栏不空)。
///
/// 目录懒加载:控制器是 lazyPut(fenix),首次 find 才实例化且分类要
/// `loadData()` 才有 —— 挂一帧后补跑一次(loadData 幂等,不重拉)。
class _SidebarHotCategories extends StatefulWidget {
  const _SidebarHotCategories({
    required this.site,
    required this.fallback,
    required this.onFallbackTap,
    required this.onOpenCategory,
  });

  /// 当前选中站点(为空 → 直接硬编码兜底)。
  final Site? site;

  /// 硬编码兜底分类名表。
  final List<String> fallback;

  /// 兜底分类点击(老行为:切到分区页)。
  final VoidCallback onFallbackTap;

  /// 真实分类点击:跳该站分类详情。
  final void Function(Site site, LiveArea area) onOpenCategory;

  @override
  State<_SidebarHotCategories> createState() => _SidebarHotCategoriesState();
}

class _SidebarHotCategoriesState extends State<_SidebarHotCategories> {
  @override
  void initState() {
    super.initState();
    _ensureCatalogLoaded();
  }

  @override
  void didUpdateWidget(covariant _SidebarHotCategories oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.site?.id != widget.site?.id) {
      _ensureCatalogLoaded();
    }
  }

  /// 目录为空且控制器已注册 → 一帧后补跑 loadData(不在 build 期间触发
  /// Rx 通知)。loadData 幂等:进行中复用同一 Future,已有数据不重拉。
  void _ensureCatalogLoaded() {
    final site = widget.site;
    if (site == null || !Get.isRegistered<AreasListController>(tag: site.id)) return;
    final controller = Get.find<AreasListController>(tag: site.id);
    if (controller.categories.isNotEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!Get.isRegistered<AreasListController>(tag: site.id)) return;
      final latest = Get.find<AreasListController>(tag: site.id);
      if (latest.categories.isEmpty) unawaited(latest.loadData());
    });
  }

  Widget _fallbackList() {
    return Column(
      children: [for (final category in widget.fallback) _CategoryRow(name: category, onTap: widget.onFallbackTap)],
    );
  }

  /// 空名条目不展示(老口径的空名过滤保留,目录脏数据防御)。
  bool _visibleArea(LiveArea area) => (area.areaName ?? '').trim().isNotEmpty;

  /// 组标题行:样式对齐浮层列标题(bodySecondary + w700 + textSecondary),
  /// 行高略小于 [_CategoryRow](上下 3 vs 5),贴侧栏既有留白节奏。
  Widget _groupTitle(BuildContext context, String siteId, String name) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 3),
      child: Text(
        // 分组名统一走跨平台中文映射(douyin/douyu/huya/bilibili 原名直返)。
        displayCategoryGroupName(siteId, name),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: AppFontSize.bodySecondary, fontWeight: FontWeight.w700, color: tokens.textSecondary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    if (site == null || !Get.isRegistered<AreasListController>(tag: site.id)) {
      return _fallbackList();
    }
    final controller = Get.find<AreasListController>(tag: site.id);
    return Obx(() {
      // 与顶栏 hover 浮层同一套一级分区构建(过滤排序 + 空组滤除):
      // douyin 复合 id 排序、douyu/huya 滤非游戏组后按平台序,条目全量
      // 展示,不再取前 15;行名与浮层 chip 同走 displayCategoryName。
      final sections = buildCategorySections(site.id, controller.categories);
      if (sections.isEmpty) return _fallbackList();
      if (sections.length == 1) {
        // 单大组平台(twitch/soop/快手等):平铺无组标题。
        return Column(
          children: [
            for (final area in sections.first.items)
              if (_visibleArea(area))
                _CategoryRow(
                  name: displayCategoryName(site.id, area.areaName, area.areaId),
                  onTap: () => widget.onOpenCategory(site, area),
                ),
          ],
        );
      }
      // 多组:组标题行 + 该组全部子分类行,逐组纵向排列(外层侧栏
      // ListView 统一滚动,不自建滚动容器)。
      return Column(
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            _groupTitle(context, site.id, sections[i].name),
            for (final area in sections[i].items)
              if (_visibleArea(area))
                _CategoryRow(
                  name: displayCategoryName(site.id, area.areaName, area.areaId),
                  onTap: () => widget.onOpenCategory(site, area),
                ),
          ],
        ],
      );
    });
  }
}
