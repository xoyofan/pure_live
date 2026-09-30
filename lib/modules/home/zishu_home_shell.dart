import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/platform_brands.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/platform_icon.dart';

/// zishu 首页外壳(宽屏 >680):44px 顶栏 + 200px 左侧栏。
///
/// 对齐 zishu exe `exe_now_home` 基线与 pure_live web 线拍板布局:
/// 顶栏 = 品牌字 + 主导航图标组(首页/分区/关注·金) | 平台 tab 居中 | 工具区
/// (搜索/设置);侧栏 = 平台品牌色块 2 列 + 「热门分类」Top12 + 录制入口。
/// 平台 tab/色块点击 → 切到热门页并 animateTo 对应站点 tab。
class ZishuHomeShell extends StatefulWidget {
  final Widget body;
  final int index;
  final List<String> activeMenuIds;
  final void Function(int) onDestinationSelected;

  const ZishuHomeShell({
    super.key,
    required this.body,
    required this.index,
    required this.activeMenuIds,
    required this.onDestinationSelected,
  });

  @override
  State<ZishuHomeShell> createState() => _ZishuHomeShellState();
}

class _ZishuHomeShellState extends State<ZishuHomeShell> {
  /// 侧栏「热门分类」目录:对齐 zishu exe 侧栏视觉(点击暂只切换到分区页,
  /// 站内分类联动留到浏览批接线)。
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
  int _siteIndex = 0;

  @override
  void initState() {
    super.initState();
    _bindPopular();
  }

  @override
  void didUpdateWidget(covariant ZishuHomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bindPopular();
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
    super.dispose();
  }

  void _selectSiteId(String siteId) {
    if (widget.index != HomeMenu.popular.index) {
      widget.onDestinationSelected(HomeMenu.popular.index);
    }
    _bindPopular();
    final controller = _popular;
    if (controller == null) return;
    final fullIndex = controller.sites.indexWhere((s) => s.id == siteId);
    if (fullIndex >= 0) {
      controller.tabController.animateTo(fullIndex);
      if (mounted) setState(() => _siteIndex = fullIndex);
    }
  }

  List<Site> get _sites => _popular?.sites ?? const <Site>[];

  String? get _currentSiteId {
    final sites = _sites;
    if (_siteIndex < 0 || _siteIndex >= sites.length) return null;
    return sites[_siteIndex].id;
  }

  /// 平台入口渲染表:`savedPlatformIds` 顺序优先;热门页新增站点(不在
  /// 保存表)追加在尾部,保证新平台默认可见。
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
    for (final site in all) {
      if (!visible.any((v) => v.id == site.id)) visible.add(site);
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
        // Obx 覆盖平台入口区:订阅 savedPlatformIds 与热门页站点表,设置里
        // 改排序/显隐即时反映到顶栏与侧栏。
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
                    _Sidebar(
                      index: widget.index,
                      sites: visibleSites,
                      currentSiteId: _currentSiteId,
                      onSelectSite: _selectSiteId,
                      onSelectMenu: widget.onDestinationSelected,
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(child: widget.body),
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
            onTap: () => Get.toNamed(RoutePath.kSearch),
          ),
          const SizedBox(width: AppSpacing.xs),
          _TopNavTool(
            tooltip: i18n('settings_title'),
            icon: Remix.settings_5_line,
            onTap: () => Get.toNamed(RoutePath.kSettings),
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

/// 顶栏平台 tab:32×32 悬停 pill 内放平台图标(纯 live 站点 id 对齐 zishu
/// 品牌表;未收录平台由 PlatformIcon 落品牌金字母兜底)。
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

/// 200px 侧栏:surfaceSoft 底,平台色块 2 列 + 热门分类 + 录制入口。
class _Sidebar extends StatelessWidget {
  final int index;
  final List<Site> sites;
  final String? currentSiteId;
  final void Function(String) onSelectSite;
  final void Function(int) onSelectMenu;

  const _Sidebar({
    required this.index,
    required this.sites,
    required this.currentSiteId,
    required this.onSelectSite,
    required this.onSelectMenu,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: 200,
      color: tokens.surfaceSoft,
      child: ListView(
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
          for (final category in _ZishuHomeShellState._hotCategories)
            _CategoryRow(name: category, onTap: () => onSelectMenu(HomeMenu.areas.index)),
          const Divider(height: AppSpacing.xl),
          _CategoryRow(
            name: i18n('record_center'),
            icon: Remix.download_2_line,
            selected: index == HomeMenu.record.index,
            onTap: () => onSelectMenu(HomeMenu.record.index),
          ),
        ],
      ),
    );
  }
}

/// 平台色块:品牌色底 + 平台图标,选中态品牌金描边。
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
          width: 82,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: AppRadius.allMd,
            border: Border.all(color: selected ? tokens.brand : Colors.transparent, width: 1.5),
          ),
          child: Center(child: PlatformIcon(id: site.id, size: 24)),
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
