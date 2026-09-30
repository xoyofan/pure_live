import 'dart:async';

import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/shell/phone/zishu_phone_bottom_nav.dart';
import 'package:pure_live/zishu_app/shell/phone/zishu_phone_category_sheet.dart';
import 'package:pure_live/zishu_app/shell/phone/zishu_phone_platform_strip.dart';

/// zishu 窄屏(<768)外壳:移植 zishu_flutter 移动端 chrome 的
/// 「顶部平台条 + 底部主导航」结构,替换旧的 `HomeDrawerView` 抽屉。
///
/// - 顶部 `ZishuPhonePlatformStrip`:竖屏 2 行×6 列宫格 / 横屏单行横滚,
///   点格切平台(数据 = `PopularController.sites`,按 `savedPlatformIds`
///   的顺序与可见性过滤,与宽屏 `ZishuAppShell` 同口径),长按格或 ▼ 开
///   `ZishuPhoneCategorySheet` 分类面板;
/// - 底部 `ZishuPhoneBottomNav`(56px 七项):logo/首页/分类/我的分类/
///   关注/搜索/主题,页面切换走外壳 `onDestinationSelected`。
///
/// 站点绑定逻辑与宽屏 `ZishuAppShell` 同源:`tabController` 监听取当前站点,
/// 切平台时同步驱动热门页与分区页(平台即全局站点上下文)。
class ZishuPhoneShell extends StatefulWidget {
  final Widget body;
  final int index;
  final List<String> activeMenuIds;
  final void Function(int) onDestinationSelected;

  const ZishuPhoneShell({
    super.key,
    required this.body,
    required this.index,
    required this.activeMenuIds,
    required this.onDestinationSelected,
  });

  @override
  State<ZishuPhoneShell> createState() => _ZishuPhoneShellState();
}

class _ZishuPhoneShellState extends State<ZishuPhoneShell> {
  PopularController? _popular;
  VoidCallback? _tabListener;
  bool _bound = false;
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
  void didUpdateWidget(covariant ZishuPhoneShell oldWidget) {
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
      // animateTo 的下标按 controller.sites 全量表算,不按过滤后的条目。
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

  /// 平台入口渲染表(与宽壳同口径):严格按 `savedPlatformIds` 顺序;
  /// 未保存(隐藏)的站点一律不渲染。
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
      // 与宽屏外壳同口径:零主菜单时给出可解释的空态。
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
        // Obx 覆盖平台条:订阅 savedPlatformIds 与热门页站点表。
        child: Obx(() {
          final visibleSites = _visibleSites();
          return Column(
            children: [
              ZishuPhonePlatformStrip(
                sites: visibleSites,
                currentSiteId: _currentSiteId,
                onSelectSite: _selectSiteId,
                onOpenCategories: (siteId) => unawaited(showZishuPhoneCategorySheet(context, siteId)),
              ),
              Expanded(child: widget.body),
            ],
          );
        }),
      ),
      bottomNavigationBar: ZishuPhoneBottomNav(index: widget.index, onSelectMenu: widget.onDestinationSelected),
    );
  }
}
