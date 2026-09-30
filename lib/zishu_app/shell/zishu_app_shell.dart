import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/common/utils/windows_multi_instance_launcher.dart';
import 'package:pure_live/core/site/cc/cc_catalog.dart';
import 'package:pure_live/modules/areas/areas_list_controller.dart';
import 'package:pure_live/routes/app_navigation.dart';
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
import 'package:pure_live/zishu_app/shell/flyouts/zishu_category_flyout.dart';
import 'package:pure_live/zishu_app/shell/flyouts/zishu_follow_avatars.dart';
import 'package:pure_live/zishu_app/shell/category_warmup.dart';
import 'package:pure_live/zishu_app/shell/flyouts/zishu_follow_flyout.dart';
import 'package:pure_live/zishu_app/shell/flyouts/zishu_hover_overlay.dart';
import 'package:pure_live/zishu_app/shell/flyouts/zishu_my_category_flyout.dart';

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

class _ZishuAppShellState extends State<ZishuAppShell> {
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

  /// hover 浮层关闭延迟:对齐 zishu 真源 `_AppShellState` 的
  /// `_kHoverCloseDelay`(800)—— 离开触发区后留时间把鼠标移进浮层。
  static const Duration _kHoverCloseDelay = Duration(milliseconds: 800);

  /// 平台 tab 悬停到浮层弹出的延迟(300ms):扫过顶栏不弹,停留才弹。
  static const Duration _kPlatformHoverOpenDelay = Duration(milliseconds: 300);

  /// 侧栏宽/把手位动画时长(展开 220 ↔ 收起 52):侧栏本体
  /// AnimatedContainer 与外壳把手的 AnimatedPositioned 同源同曲线。
  static const Duration _kSidebarWidthAnimDuration = Duration(milliseconds: 200);

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

  // ---- hover 浮层态机(自持于本 State;Timer 管开/关延迟,浮层互斥) ----

  /// 300ms 悬停开门定时器(平台 tab 用;关注钮即时开)。
  Timer? _openTimer;

  /// 800ms 延迟关门定时器(离开触发区/浮层后统一走它)。
  Timer? _closeTimer;

  /// 当前打开分类浮层的站点 id(null = 关闭)。
  String? _flyoutPlatformId;
  double _platformFlyoutX = 0;

  /// 关注在播浮层开关与触发点中心 x。
  bool _followFlyoutOpen = false;
  double _followFlyoutX = 0;

  /// 搜索防重入:showZishuSearchDialog 本身不防叠,连按两次 Ctrl+F 会开
  /// 两层(对齐 zishu 真源 `_searchOpening` 同款处理)。
  bool _searchOpening = false;

  /// Ctrl+F / Ctrl+K 全局搜索快捷键的焦点锚点:CallbackShortcuts 需要
  /// 一个持有焦点的 Focus 才能在气泡阶段收到按键;本壳层恒在 home 路由
  /// 顶层且覆盖整页,焦点空闲时由它兜底持有。
  final FocusNode _shortcutFocusNode = FocusNode(debugLabel: 'zishu-app-shell-shortcuts');

  void _cancelFlyoutClose() => _closeTimer?.cancel();

  /// 离开触发区/浮层:取消未成的开门,再排 800ms 延迟关门。
  void _scheduleFlyoutClose() {
    _openTimer?.cancel();
    _closeTimer?.cancel();
    _closeTimer = Timer(_kHoverCloseDelay, () {
      if (!mounted) return;
      setState(() {
        _flyoutPlatformId = null;
        _followFlyoutOpen = false;
      });
    });
  }

  /// 立即收起所有浮层(点分类跳转 / 点小卡进播放页 / 顶栏点击导航前调用)。
  void _closeAllFlyouts() {
    _openTimer?.cancel();
    _closeTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _flyoutPlatformId = null;
      _followFlyoutOpen = false;
    });
  }

  /// 平台 tab 悬停:先取消既有的开/关,300ms 后弹该平台分类浮层。
  void _schedulePlatformFlyout(String siteId, double centerX) {
    _closeTimer?.cancel();
    _openTimer?.cancel();
    _openTimer = Timer(_kPlatformHoverOpenDelay, () => _openPlatformFlyout(siteId, centerX));
  }

  /// 移出平台 tab:取消未成的开门,交给延迟关门。
  void _cancelPlatformFlyoutOpen() {
    _openTimer?.cancel();
    _scheduleFlyoutClose();
  }

  void _openPlatformFlyout(String siteId, double centerX) {
    if (!mounted) return;
    _closeTimer?.cancel();
    // 浮层一开就补跑一轮目录加载:用户看到的应是此刻目录,而不是等分区页
    // 先被打开过。loadData 幂等(进行中复用同一 Future,已有数据不重拉)。
    if (Get.isRegistered<AreasListController>(tag: siteId)) {
      final controller = Get.find<AreasListController>(tag: siteId);
      if (controller.categories.isEmpty) {
        unawaited(controller.loadData());
      }
    }
    if (_flyoutPlatformId == siteId) {
      // 同一平台重复触发:浮层已开,不重建(触发点 x 不变,无需 setState)。
      return;
    }
    setState(() {
      _flyoutPlatformId = siteId;
      _platformFlyoutX = centerX;
      _followFlyoutOpen = false;
    });
  }

  void _openFollowFlyout(double centerX) {
    _closeTimer?.cancel();
    if (_followFlyoutOpen) {
      _followFlyoutX = centerX;
      return;
    }
    setState(() {
      _followFlyoutOpen = true;
      _followFlyoutX = centerX;
      _flyoutPlatformId = null;
    });
  }

  /// 关注浮层点小卡:先收浮层,再进播放页。
  void _openRoomFromFlyout(LiveRoom room) {
    _closeAllFlyouts();
    unawaited(AppNavigator.toLiveRoomDetail(liveRoom: room));
  }

  /// 分类详情统一入口:先收浮层,再切分区 tab 内嵌打开(需要 Site 对象)。
  ///
  /// 分类入口统一收口(侧栏热门分类/顶栏平台浮层 chips/我的分类 chips/
  /// 分区封面格都走这里):切到分区 tab 并把分类交给 [ZishuAreasView]
  /// 内嵌渲染(外壳内两级,不再推 kAreaRooms 路由)。
  void selectAreaCategory(Site site, LiveArea area) {
    if (!mounted) return;
    _closeAllFlyouts();
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
    _openTimer?.cancel();
    _closeTimer?.cancel();
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

  /// 平台入口渲染表:严格按 `savedPlatformIds` 顺序;未保存(隐藏)的站点
  /// 一律不渲染。新平台在「平台顺序与可见」设置里默认关,勾选后才进外壳。
  List<Site> _visibleSites() {
    final saved = SettingsService.to.app.savedPlatformIds.v;
    final all = _sites;
    final visible = <Site>[];
    for (final id in saved) {
      for (final site in all) {
        if (site.id == id) {
          visible.add(site);
          break;
        }
      }
    }
    return visible;
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
    return Stack(
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
                  // Obx 覆盖平台入口区:订阅 savedPlatformIds 与热门页站点表。
                  child: Obx(() {
                    final visibleSites = _visibleSites();
                    return Column(
                      children: [
                        _TopBar(
                          index: widget.index,
                          sites: visibleSites,
                          currentSiteId: _currentSiteId,
                          onSelectMenu: _navigateToMenu,
                          onSelectSite: _selectSiteId,
                          onPlatformHoverStart: _schedulePlatformFlyout,
                          onPlatformHoverEnd: _cancelPlatformFlyoutOpen,
                          onFollowHoverStart: _openFollowFlyout,
                          onFollowHoverEnd: _scheduleFlyoutClose,
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
                                curve: Curves.easeOutCubic,
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
        ..._buildFlyouts(),
      ],
    );
  }

  /// 当前应展示的浮层(平台分类 / 关注在播)。宽度与内容同源:分类宽度随
  /// `categories` 分组数收缩(Obx 订阅),关注宽度随在播数收缩。
  List<Widget> _buildFlyouts() {
    final flyouts = <Widget>[];
    final platformId = _flyoutPlatformId;
    if (platformId != null) {
      final site = _siteById(platformId);
      if (Get.isRegistered<AreasListController>(tag: platformId)) {
        flyouts.add(
          Obx(() {
            // 每次 Obx 重建都重新 find:lazyPut(fenix) 的实例可能被 smart
            // management 换新,闭包不能持有旧引用。
            final controller = Get.find<AreasListController>(tag: platformId);
            final groups = controller.categories;
            // 空目录区分「加载中 / 失败」:pageError 是 RxBool,失败时本 Obx
            // 也会随之重建(加载中文案见 _openPlatformFlyout 触发的 loadData)。
            final emptyHint = controller.pageError.value ? '分类加载失败' : i18n('zishu_category_flyout_loading');
            return ZishuHoverOverlay(
              centerX: _platformFlyoutX,
              width: ZishuPlatformCategoryFlyout.widthFor(groups),
              child: ZishuPlatformCategoryFlyout(
                groups: groups,
                onEnter: _cancelFlyoutClose,
                onExit: _scheduleFlyoutClose,
                onOpenCategory: site == null ? null : (area) => selectAreaCategory(site, area),
                emptyHint: groups.isEmpty ? emptyHint : i18n('zishu_category_flyout_empty'),
              ),
            );
          }),
        );
      } else {
        // 站点目录控制器未注册(分区页尚未打开过):兜底空面板。
        flyouts.add(
          ZishuHoverOverlay(
            centerX: _platformFlyoutX,
            width: ZishuPlatformCategoryFlyout.minFlyoutWidth,
            child: ZishuPlatformCategoryFlyout(
              groups: const <AppLiveCategory>[],
              onEnter: _cancelFlyoutClose,
              onExit: _scheduleFlyoutClose,
            ),
          ),
        );
      }
    }
    if (_followFlyoutOpen) {
      flyouts.add(
        Obx(() {
          final rooms = SettingsService.to.fav.favoriteRooms.v.where((room) => room.isLiveNow).toList();
          final layout = ZishuFollowFlyout.layoutFor(rooms.length);
          return ZishuHoverOverlay(
            centerX: _followFlyoutX,
            width: layout.width,
            child: ZishuFollowFlyout(
              columns: layout.columns,
              rooms: rooms,
              onEnter: _cancelFlyoutClose,
              onExit: _scheduleFlyoutClose,
              onOpenRoom: _openRoomFromFlyout,
            ),
          );
        }),
      );
    }
    return flyouts;
  }
}

/// 44px 顶栏:surface 底,主导航图标组 | 平台 tab 居中 | 工具区(关注/搜索/设置/账号)。
class _TopBar extends StatelessWidget {
  final int index;
  final List<Site> sites;
  final String? currentSiteId;
  final void Function(int) onSelectMenu;
  final void Function(String) onSelectSite;

  /// 「关注」钮 hover → 触发点中心 x(弹在播头像网格);移出交给延迟关门。
  final void Function(double centerX) onFollowHoverStart;
  final VoidCallback onFollowHoverEnd;

  /// 平台 tab hover → `(站点 id, 触发点中心 x)`,300ms 后弹分类浮层;
  /// 移出取消开门并交给延迟关门。
  final void Function(String siteId, double centerX) onPlatformHoverStart;
  final VoidCallback onPlatformHoverEnd;

  /// 打开 zishu 设置弹窗(设置钮与账号菜单共用)。
  final VoidCallback onOpenSettings;

  const _TopBar({
    required this.index,
    required this.sites,
    required this.currentSiteId,
    required this.onSelectMenu,
    required this.onSelectSite,
    required this.onPlatformHoverStart,
    required this.onPlatformHoverEnd,
    required this.onFollowHoverStart,
    required this.onFollowHoverEnd,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      height: AppSpacing.topNavHeight,
      color: tokens.surface,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          _TopNavBrand(index: index, onSelectMenu: onSelectMenu),
          const Spacer(),
          for (final site in sites)
            _PlatformTab(
              site: site,
              selected: site.id == currentSiteId && index == HomeMenu.popular.index,
              onTap: () => onSelectSite(site.id),
              onHoverStart: onPlatformHoverStart,
              onHoverEnd: onPlatformHoverEnd,
            ),
          const Spacer(),
          // 关注触发器:在播头像堆叠(无在播回落星形),悬停仍走既有
          // follow flyout 态机(_openFollowFlyout / 延迟关门),点击进关注页。
          ZishuFollowAvatars(
            tooltip: i18n('favorites_title'),
            onTap: () => onSelectMenu(HomeMenu.favorites.index),
            onHoverStart: onFollowHoverStart,
            onHoverEnd: onFollowHoverEnd,
          ),
          _TopNavTool(
            tooltip: '${i18n('search_live')}  Ctrl+F',
            icon: Remix.search_line,
            onTap: () => showZishuSearchDialog(context),
          ),
          const SizedBox(width: AppSpacing.xs),
          _TopNavTool(tooltip: i18n('settings_title'), icon: Remix.settings_5_line, onTap: onOpenSettings),
          _TopUserArea(onOpenSettings: onOpenSettings),
        ],
      ),
    );
  }
}

/// 品牌字 + 主导航图标组(首页/分区/我的分类);关注等工具入口在顶栏右侧。
/// 组成与顺序对齐 zishu 真源 top_nav.dart 的 nav-home / nav-category /
/// nav-my-category(真源图标 Icons.star_border_rounded);我的分类无对应
/// 菜单页签(点击弹 ZishuMyCategorySheet),无持久选中态,图标恒为
/// 主组未选色 textSecondary。
class _TopNavBrand extends StatelessWidget {
  final int index;
  final void Function(int) onSelectMenu;

  const _TopNavBrand({required this.index, required this.onSelectMenu});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: Text(
            'Pure Live',
            style: context.textTitle.copyWith(
              fontSize: AppFontSize.title,
              color: tokens.brandBright,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _TopNavIcon(
          key: const Key('nav-home'),
          icon: Remix.home_5_fill,
          tooltip: i18n('popular_title'),
          color: index == HomeMenu.popular.index ? tokens.textPrimary : tokens.textSecondary,
          onTap: () => onSelectMenu(HomeMenu.popular.index),
        ),
        _TopNavIcon(
          key: const Key('nav-category'),
          icon: Remix.apps_2_fill,
          tooltip: i18n('areas_title'),
          color: index == HomeMenu.areas.index ? tokens.textPrimary : tokens.textSecondary,
          onTap: () => onSelectMenu(HomeMenu.areas.index),
        ),
        _TopNavIcon(
          key: const Key('nav-my-category'),
          icon: Icons.star_border_rounded,
          tooltip: i18n('my_category_title'),
          color: tokens.textSecondary,
          onTap: () => unawaited(showZishuMyCategorySheet(context)),
        ),
      ],
    );
  }
}

class _TopNavIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _TopNavIcon({super.key, required this.icon, required this.tooltip, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      splashRadius: 18,
    );
  }
}

/// 顶栏平台 tab:32×32 悬停 pill 内放平台图标;hover ≥300ms 弹分类浮层
/// (延迟由壳层态机持有,这里只回传触发点中心 x 与移出事件)。
class _PlatformTab extends StatelessWidget {
  final Site site;
  final bool selected;
  final VoidCallback onTap;

  /// hover 浮层挂钩:进入回传 `(站点 id, 触发点中心 x)`(全局坐标),
  /// 移出取消开门并交给壳层延迟关门。
  final void Function(String siteId, double centerX) onHoverStart;
  final VoidCallback onHoverEnd;

  const _PlatformTab({
    required this.site,
    required this.selected,
    required this.onTap,
    required this.onHoverStart,
    required this.onHoverEnd,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Builder(
        builder: (hoverContext) {
          // 触发点中心 x:MouseRegion 与点击区共用同一个 RenderBox 快照
          // (真源 _NavAction 同款处理)。
          RenderBox? box;
          double centerX() {
            final target = box ??= hoverContext.findRenderObject() as RenderBox?;
            if (target == null) return 0;
            final dx = target.localToGlobal(Offset.zero).dx;
            return dx + target.size.width / 2;
          }

          return MouseRegion(
            onEnter: (_) => onHoverStart(site.id, centerX()),
            onExit: (_) => onHoverEnd(),
            child: InkResponse(
              onTap: onTap,
              radius: 18,
              hoverColor: tokens.surfaceRaised,
              child: Tooltip(
                message: site.name,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected ? tokens.surfaceRaised : Colors.transparent,
                    borderRadius: AppRadius.allMd,
                    border: Border.all(color: selected ? tokens.accent : Colors.transparent, width: 1),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: PlatformIcon(id: site.id, size: 22),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TopNavTool extends StatelessWidget {
  const _TopNavTool({required this.tooltip, required this.icon, required this.onTap});

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: Theme.of(context).extension<ZishuTokens>()!.textSecondary),
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      splashRadius: 18,
    );
  }
}

/// 顶栏右侧用户区:圆形头像钮 + PopupMenu。
///
/// 菜单在 zishu 原三项(历史/设置/关于)之外并入 pure_live 工具四项
/// (备份/工具箱/多窗/新窗口),对齐旧 UI 的 MenuButton + CommonAppBarActions
/// 能力面 —— 顶栏不另加图标避免拥挤,全部收进用户菜单。原
/// 原 `ZishuUserArea` 菢单固定为三项且不可扩展,故按其视觉(头像钮、菜单
/// 行高/图标/字级)在本壳内重建;工具项图标与文案沿用旧 UI 口径
/// (cloud_line/link/layout_grid_line/add_to_photos_outlined)。
///
/// 开关门控在 itemBuilder 内读取(菜单每次打开即时取值,对齐旧 UI):
/// 多窗受 `enableMultiView`,新窗口受 `Platform.isWindows && enableNewWindowPlay`,
/// 关闭的项不渲染。
class _TopUserArea extends StatelessWidget {
  const _TopUserArea({required this.onOpenSettings});

  /// 打开 zishu 设置弹窗(与顶栏设置钮同一入口,由壳层注入)。
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return PopupMenuButton<String>(
      key: const Key('zishu-nav-user'),
      tooltip: i18n('account'),
      offset: const Offset(0, 30),
      color: tokens.surface,
      onSelected: (action) {
        switch (action) {
          case 'history':
            Get.toNamed(RoutePath.kHistory);
          case 'settings':
            onOpenSettings();
          case 'about':
            Get.toNamed(RoutePath.kAbout);
          case 'backup':
            Get.toNamed(RoutePath.kBackup);
          case 'toolbox':
            Get.toNamed(RoutePath.kToolbox);
          case 'multiview':
            unawaited(AppNavigator.toMultiview());
          case 'new_window':
            unawaited(_launchNewWindow());
        }
      },
      itemBuilder: (menuContext) => [
        _item(menuContext, 'history', Icons.history_rounded, i18n('history')),
        _item(menuContext, 'settings', Remix.settings_5_line, i18n('settings_title')),
        _item(menuContext, 'about', Remix.information_line, i18n('about')),
        _item(menuContext, 'backup', Remix.cloud_line, i18n('backup_recover')),
        _item(menuContext, 'toolbox', Remix.link, i18n('open_link')),
        if (SettingsService.to.app.enableMultiView.v)
          _item(menuContext, 'multiview', Remix.layout_grid_line, i18n('multiview_title')),
        if (Platform.isWindows && SettingsService.to.app.enableNewWindowPlay.v)
          _item(menuContext, 'new_window', Icons.add_to_photos_outlined, i18n('open_new_window')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: CircleAvatar(
          radius: 14,
          backgroundColor: tokens.accent,
          child: Icon(Icons.person_outline_rounded, size: 16, color: AppOnBright.white),
        ),
      ),
    );
  }

  /// 新窗口:launch 已自守 `Platform.isWindows`;失败时对齐旧 UI MenuButton
  /// 的 toast 提示。
  Future<void> _launchNewWindow() async {
    try {
      await WindowsMultiInstanceLauncher.launch();
    } catch (_) {
      ToastUtil.show(i18n('open_new_window_failed'));
    }
  }

  PopupMenuItem<String> _item(BuildContext context, String value, IconData icon, String label) {
    final tokens = context.tokens;
    return PopupMenuItem(
      value: value,
      height: 34,
      child: Row(
        children: [
          Icon(icon, size: 15, color: tokens.textSecondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: AppFontSize.bodySecondary, color: tokens.textPrimary),
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
      curve: Curves.easeOutCubic,
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

/// 侧栏「热门分类」:当前选中站点 `AreasListController.categories` 展开
/// 子分类取前 15(真实目录);控制器未注册或目录为空时回落硬编码表
/// (老口径,保证任何时刻侧栏不空)。
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
  /// 展示条数上限(交付口径:展开子分类取前 15)。
  static const int _maxCategories = 15;

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

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    if (site == null || !Get.isRegistered<AreasListController>(tag: site.id)) {
      return _fallbackList();
    }
    final controller = Get.find<AreasListController>(tag: site.id);
    return Obx(() {
      // 多分组目录按组序展开子分类,过滤空名后取前 15。
      final areas = <LiveArea>[
        for (final group in controller.categories)
          for (final area in group.children)
            if ((area.areaName ?? '').trim().isNotEmpty) area,
      ].take(_maxCategories).toList();
      if (areas.isEmpty) return _fallbackList();
      return Column(
        children: [
          for (final area in areas)
            _CategoryRow(name: area.areaName!.trim(), onTap: () => widget.onOpenCategory(site, area)),
        ],
      );
    });
  }
}
