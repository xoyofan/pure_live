import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/platform_brands.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/platform_icon.dart';
import 'package:pure_live/zishu_app/features/areas/zishu_areas_view.dart';
import 'package:pure_live/zishu_app/features/browse/zishu_browse_view.dart';
import 'package:pure_live/zishu_app/features/follow/zishu_follow_view.dart';
import 'package:pure_live/zishu_app/features/search/zishu_search_dialog.dart';
import 'package:pure_live/zishu_app/features/settings/zishu_settings_view.dart';

/// zishu 前端移植主外壳(宽屏 >680):44px 顶栏 + 可折叠浏览侧栏。
///
/// 新目录 `lib/zishu_app/` 按"照搬 zishu 前端 + pure_live 解析"路线组建;
/// 本壳对齐 zishu browse_sidebar:侧栏展开 220 / 收起 52
/// ([AppDirectoryDrawer]),右缘外挂 13.6×44 突出折叠按钮(仅右侧 4px
/// 圆角);平台块统一 44×44、横向 Wrap 自动换行。
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

  PopularController? _popular;
  VoidCallback? _tabListener;
  bool _bound = false;
  bool _collapsed = false;
  int _siteIndex = 0;
  AreasController? _areas;
  VoidCallback? _areasTabListener;
  bool _areasBound = false;
  int _areasSiteIndex = 0;

  @override
  void initState() {
    super.initState();
    _bindPopular();
    _bindAreas();
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
      widget.onDestinationSelected(HomeMenu.popular.index);
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

  /// 内容区:热门/关注/分区已迁 zishu 视图,录制仍走旧页面体。
  Widget _contentForMenu(int menuIndex, String? currentSiteId) {
    if (menuIndex == HomeMenu.popular.index && currentSiteId != null) {
      return ZishuBrowseView(siteId: currentSiteId);
    }
    if (menuIndex == HomeMenu.favorites.index) {
      return const ZishuFollowView();
    }
    if (menuIndex == HomeMenu.areas.index) {
      return const ZishuAreasView();
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
    return Scaffold(
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
                onSelectMenu: widget.onDestinationSelected,
                onSelectSite: _selectSiteId,
              ),
              const Divider(height: 1, thickness: 1),
              Expanded(
                child: Row(
                  children: [
                    _BrowseSidebar(
                      index: widget.index,
                      sites: visibleSites,
                      currentSiteId: _currentSiteId,
                      collapsed: _collapsed,
                      onToggleCollapsed: () => setState(() => _collapsed = !_collapsed),
                      onSelectSite: _selectSiteId,
                      onSelectMenu: widget.onDestinationSelected,
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(child: _contentForMenu(widget.index, _currentSiteId)),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// 44px 顶栏:surface 底,主导航图标组 | 平台 tab 居中 | 工具区(关注/搜索/设置)。
class _TopBar extends StatelessWidget {
  final int index;
  final List<Site> sites;
  final String? currentSiteId;
  final void Function(int) onSelectMenu;
  final void Function(String) onSelectSite;

  const _TopBar({
    required this.index,
    required this.sites,
    required this.currentSiteId,
    required this.onSelectMenu,
    required this.onSelectSite,
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
            ),
          const Spacer(),
          _TopNavTool(
            tooltip: i18n('favorites_title'),
            icon: Remix.heart_3_fill,
            color: index == HomeMenu.favorites.index ? tokens.brand : null,
            onTap: () => onSelectMenu(HomeMenu.favorites.index),
          ),
          _TopNavTool(
            tooltip: i18n('search_live'),
            icon: Remix.search_line,
            onTap: () => showZishuSearchDialog(context),
          ),
          const SizedBox(width: AppSpacing.xs),
          _TopNavTool(
            tooltip: i18n('settings_title'),
            icon: Remix.settings_5_line,
            onTap: () => Get.to(
              () => Scaffold(
                appBar: AppBar(title: Text(i18n('settings_title'))),
                body: const ZishuSettingsView(embedded: true),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 品牌字 + 主导航图标组(首页/分区);关注等工具入口在顶栏右侧。
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
              color: tokens.brand,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _TopNavIcon(
          icon: Remix.home_5_fill,
          tooltip: i18n('popular_title'),
          color: index == HomeMenu.popular.index ? tokens.textPrimary : tokens.textSecondary,
          onTap: () => onSelectMenu(HomeMenu.popular.index),
        ),
        _TopNavIcon(
          icon: Remix.apps_2_fill,
          tooltip: i18n('areas_title'),
          color: index == HomeMenu.areas.index ? tokens.textPrimary : tokens.textSecondary,
          onTap: () => onSelectMenu(HomeMenu.areas.index),
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

  const _TopNavIcon({required this.icon, required this.tooltip, required this.color, required this.onTap});

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

/// 顶栏平台 tab:32×32 悬停 pill 内放平台图标。
class _PlatformTab extends StatelessWidget {
  final Site site;
  final bool selected;
  final VoidCallback onTap;

  const _PlatformTab({required this.site, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
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
              border: Border.all(color: selected ? tokens.brand : Colors.transparent, width: 1),
            ),
            padding: const EdgeInsets.all(4),
            child: PlatformIcon(id: site.id, size: 22),
          ),
        ),
      ),
    );
  }
}

class _TopNavTool extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _TopNavTool({required this.tooltip, required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color ?? Theme.of(context).extension<ZishuTokens>()!.textSecondary),
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      splashRadius: 18,
    );
  }
}

/// 可折叠浏览侧栏:展开 220 / 收起 52,右缘外挂突出折叠按钮。
///
/// 展开态 = 平台统一色块(44×44,Wrap 横向换行)+ 热门分类 + 录制;
/// 收起态 = 平台图标竖排 + 折叠按钮。
class _BrowseSidebar extends StatelessWidget {
  final int index;
  final List<Site> sites;
  final String? currentSiteId;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final void Function(String) onSelectSite;
  final void Function(int) onSelectMenu;

  const _BrowseSidebar({
    required this.index,
    required this.sites,
    required this.currentSiteId,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onSelectSite,
    required this.onSelectMenu,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final width = collapsed ? AppDirectoryDrawer.railWidth : AppDirectoryDrawer.width;
    return SizedBox(
      width: width + AppDirectoryDrawer.toggleWidth,
      child: Stack(
        children: [
          Container(
            width: width,
            color: tokens.surfaceSoft,
            child: collapsed ? _buildCollapsed(context, tokens) : _buildExpanded(context, tokens),
          ),
          // 突出折叠按钮:贴侧栏右缘外挂 13.6×44,仅右侧 4px 圆角。
          Positioned(
            left: width,
            top: 0,
            bottom: 0,
            child: Center(
              child: Material(
                color: tokens.surface,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                elevation: 1,
                child: InkWell(
                  onTap: onToggleCollapsed,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                  child: SizedBox(
                    width: AppDirectoryDrawer.toggleWidth,
                    height: AppDirectoryDrawer.toggleHeight,
                    child: Icon(
                      collapsed ? Remix.arrow_right_s_line : Remix.arrow_left_s_line,
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
        for (final category in _ZishuAppShellState._hotCategories)
          _CategoryRow(name: category, onTap: () => onSelectMenu(HomeMenu.areas.index)),
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
                          ? tokens.brand
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
                color: index == HomeMenu.record.index ? tokens.brand : tokens.textSecondary,
              ),
            ),
          ),
        ),
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
            border: Border.all(color: selected ? tokens.brand : Colors.transparent, width: 1.5),
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
              Icon(icon, size: 14, color: selected ? tokens.brand : tokens.textSecondary),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textBody.copyWith(fontSize: 13, color: selected ? tokens.brand : tokens.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
