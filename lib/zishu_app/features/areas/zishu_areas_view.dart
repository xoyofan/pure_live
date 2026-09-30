import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/site/cc/cc_catalog.dart';
import 'package:pure_live/modules/area_rooms/area_rooms_binding.dart';
import 'package:pure_live/modules/areas/areas_list_controller.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/empty_view.dart' as zishu;
import 'package:pure_live/zishu/presentation/widgets/retry_button.dart' as zishu;
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/areas/zishu_area_grid.dart';
import 'package:pure_live/zishu_app/features/browse/zishu_browse_view.dart';
import 'package:remixicon/remixicon.dart';

/// zishu 分区视图(pure_live `AreasController` 适配版),形态对齐 zishu
/// `features/browse/views/category_view.dart` 的「分类索引页」:
/// - 宽容器(≥680):左侧分组栏(132px,分组名列表,选中态品牌金描边)
///   + 右侧该分组子分类封面格,即 zishu `_GroupTabs` + `_CategoryGrid`
///   的索引形态(分类数据复用 `AreasListController.categories`,点分组只
///   切 `tabIndex`,不进路由);
/// - 窄容器(<680):分组栏转顶部横滚 chips(不挤内容区),封面格占满;
/// - 分区封面格 [ZishuAreaGrid](zishu token 度量),沿用
///   `AreasListController` 的既有局部分页/刷新管线(`BasePageView`),
///   点分区 tile 优先走注入的 [onOpenCategory](宽屏外壳内嵌分类详情),
///   未注入时走 `AppNavigator.toCategoryDetail` 进路由;
/// - **外壳内两级**:选中分类后本站点面板整体切为「面包屑行 + 分类房间
///   流」,房间流复用 browse 目录的 [ZishuBrowseGrid](卡片即 ZishuRoomCard),
///   控制器由 `AreaRoomsBinding.createController` 产出(与 kAreaRooms 路由
///   同一数据管线),面板 State 直接持实例并负责销毁;
/// - 站点切换沿用 `AreasController.tabController`(外壳平台 tab 会
///   animateTo 它),本视图用 TabBarView 跟随,横向手势关闭,与
///   `AreasPage` 同构(两个同轴手势不打架的既有裁决)。
class ZishuAreasView extends StatelessWidget {
  const ZishuAreasView({
    super.key,
    this.initialCategory,
    this.initialCategorySite,
    this.categoryToken,
    this.onOpenCategory,
  });

  /// 外壳待打开的分类(外壳内两级 deep-link):站点面板 State 首建时直接
  /// 落到匹配站点的分类详情态。
  final LiveArea? initialCategory;

  /// 待打开分类所属站点(与 [initialCategory] 成对;建控制器要 [Site])。
  final Site? initialCategorySite;

  /// 待打开代数:外壳每采纳一次分类自增。视图以「代数变化」识别重新应用
  /// ([initialCategory] 同值重复点选也要重建控制器)。
  final int? categoryToken;

  /// 注入的分类入口(宽屏外壳的 selectAreaCategory):封面格/快切 chips 命中
  /// CC 官方入口等不可内嵌的分类时回落;为 null 时一律走旧路由跳转。
  final void Function(Site site, LiveArea area)? onOpenCategory;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AreasController>()) {
      // AreasController 由分区路由 binding 注册;接入外壳前先占位。
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final areas = Get.find<AreasController>();
    // Obx 跟随站点表(hotAreasList):AreasController 的 ever 监听注册在先、
    // 触发也在先 —— 它重建 tabController 之后本 Obx 才重建,读到的必是
    // 新控制器(与 AreasPage 同款处理,杜绝拿旧 tabController)。
    return Obx(() {
      final sites = Sites().availableSites();
      // 空站点表时不触碰 tabController: AreasController 空表分支不初始化它。
      if (sites.isEmpty || areas.sites.isEmpty) {
        return zishu.EmptyView(icon: Icons.apps_rounded, message: i18n('empty_areas_title'));
      }
      return TabBarView(
        controller: areas.tabController,
        // 站点横向切换交由外壳平台 tab 显式驱动(同 AreasPage 裁决)。
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final site in sites)
            _SiteAreasPane(
              siteId: site.id,
              initialCategory: initialCategory,
              initialCategorySite: initialCategorySite,
              categoryToken: categoryToken,
              onOpenCategory: onOpenCategory,
            ),
        ],
      );
    });
  }
}

/// 单站点分区面板:未选分类 = 左侧分组栏(宽容器)/顶部 chips 行(窄容器)
/// + 分区封面格;选中分类 = 面包屑行 + 分类房间流(外壳内两级)。
class _SiteAreasPane extends StatefulWidget {
  const _SiteAreasPane({
    required this.siteId,
    this.initialCategory,
    this.initialCategorySite,
    this.categoryToken,
    this.onOpenCategory,
  });

  final String siteId;
  final LiveArea? initialCategory;
  final Site? initialCategorySite;
  final int? categoryToken;
  final void Function(Site site, LiveArea area)? onOpenCategory;

  @override
  State<_SiteAreasPane> createState() => _SiteAreasPaneState();
}

class _SiteAreasPaneState extends State<_SiteAreasPane> {
  /// 分组栏与顶部 chips 的形态分界:容器宽 <680 视为窄容器,分组栏
  /// 转顶部横滚 chips(量容器而非屏幕,分区面板嵌在外壳内容区里)。
  static const double _groupBarBreakpoint = 680;

  /// 选中分类(非空 = 本站面板处于外壳内分类详情态)。
  LiveArea? _selectedCategory;
  Site? _selectedCategorySite;

  /// 分类房间流分页控制器:`AreaRoomsBinding.createController` 产出
  /// (与 kAreaRooms 路由同一数据管线),State 直接持实例不经 GetX 注册
  /// —— 避免与路由 binding 的同名 tag 相互覆盖;销毁走 [onDelete]
  /// (GetX 生命周期链:释放滚动控制器/取消在途请求)。
  BasePageScrollAndStateBone<LiveRoom>? _categoryController;

  @override
  void initState() {
    super.initState();
    // 外壳待打开分类直达:面板按站点认领(非本站忽略),initState 内
    // 直接赋值不 setState。
    final site = widget.initialCategorySite;
    final area = widget.initialCategory;
    if (site == null || area == null || site.id != widget.siteId) return;
    if (CCCatalog.isOfficialEntry(area)) return;
    _installCategory(site, area);
  }

  @override
  void didUpdateWidget(covariant _SiteAreasPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    final token = widget.categoryToken;
    // 代数不变不重复应用(同参数的外壳重建不得重建控制器)。
    if (token == null || token == oldWidget.categoryToken) return;
    final site = widget.initialCategorySite;
    final area = widget.initialCategory;
    if (site == null || area == null || site.id != widget.siteId) return;
    _openCategory(site, area);
  }

  @override
  void dispose() {
    _categoryController?.onDelete();
    super.dispose();
  }

  /// 分类入口统一收口:CC 官方入口不可内嵌(外链语义,对齐
  /// `AppNavigator.toCategoryDetail` 的口径),交注入回调(外壳再走外链)
  /// 或旧路由;其余分类应用为内嵌详情。
  void _openCategory(Site site, LiveArea area) {
    if (CCCatalog.isOfficialEntry(area)) {
      final open = widget.onOpenCategory;
      if (open != null) {
        open(site, area);
      } else {
        unawaited(AppNavigator.toCategoryDetail(site: site, category: area));
      }
      return;
    }
    setState(() => _installCategory(site, area));
  }

  /// 建分类房间流控制器并落到新分类(不做 setState):旧控制器先销毁
  /// (在途请求随 onClose 取消);首帧数据由 refreshData 起跑,与
  /// AreasRoomPage.initState 同口径。
  void _installCategory(Site site, LiveArea area) {
    _categoryController?.onDelete();
    final controller = AreaRoomsBinding.createController(site, area);
    unawaited(controller.refreshData());
    _selectedCategorySite = site;
    _selectedCategory = area;
    _categoryController = controller;
  }

  /// 返回索引页:详情控制器随之销毁。
  void _closeCategory() {
    _categoryController?.onDelete();
    setState(() {
      _categoryController = null;
      _selectedCategory = null;
      _selectedCategorySite = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedCategory != null && _categoryController != null) {
      return _buildCategoryDetail(context);
    }
    if (!Get.isRegistered<AreasListController>(tag: widget.siteId)) {
      // AreasController 已对全部站点 lazyPut(fenix);站点表就位前占位。
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final controller = Get.find<AreasListController>(tag: widget.siteId);
    // LayoutBuilder 在 Obx 外:容器宽度变化只重建布局壳,Obx 的分类/列表
    // 状态照旧走自己的依赖。
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _groupBarBreakpoint;
        return Obx(() {
          // 抖音扁平站点无分类层级,直接铺全量分区(对齐 AreaGridView.isFlatten)。
          final hasGroups = !controller.isFlatten && controller.categories.isNotEmpty;
          final grid = BasePageView<AreasListController, LiveArea>(
            controller: controller,
            enableRefresh: true,
            enableLoadMore: true,
            // 空分类快照不得拆掉外层 TabBarView 页(对齐 AreaGridView 裁决)。
            preserveContentWhenEmpty: true,
            showScrollToTopBtn: SettingsService.to.page.showScrollToTopBtn.v,
            showPageSizeSelector: SettingsService.to.page.showPageSizeSelector.v,
            pageSizeOptions: SettingsService.to.page.pageSizeOptions,
            emptyBuilder: (context) => zishu.EmptyView(
              icon: Icons.apps_rounded,
              message: i18n('empty_areas_title'),
              action: zishu.RetryButton(label: i18n('refresh'), onRetry: () => controller.refreshData()),
            ),
            contentBuilder: (context, list, scrollController) {
              // preserveContentWhenEmpty 生效后空分类走这里(切到无子分区的
              // 分类时 totalCount 已非空,emptyBuilder 不再触发)。
              if (list.isEmpty) {
                return zishu.EmptyView(icon: Icons.apps_rounded, message: i18n('empty_areas_title'));
              }
              return ZishuAreaGrid(
                areas: list,
                scrollController: scrollController,
                // 封面格点分类:注入回调进外壳内嵌详情,未注入维持旧路由。
                onOpenCategory: widget.onOpenCategory == null
                    ? null
                    : (area) => _openCategory(Sites.of(widget.siteId), area),
              );
            },
          );
          if (!hasGroups) return grid;
          if (wide) {
            // zishu 索引形态:分组栏 + 1px 分隔线 + 内容区三分横排,
            // 栏与内容区各自独立纵向滚动。
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CategorySideBar(controller: controller),
                Container(width: 1, color: context.tokens.border),
                Expanded(child: grid),
              ],
            );
          }
          return Column(
            children: [
              _CategoryChipRow(controller: controller),
              Expanded(child: grid),
            ],
          );
        });
      },
    );
  }

  /// 外壳内分类详情态:顶部面包屑行(返回 + 当前分类名 + 同站快切 chips,
  /// 高 36)+ 复用 [ZishuBrowseGrid] 渲染房间流(卡片即 ZishuRoomCard,
  /// 分页/刷新全由控制器与 BasePageView 既有管线承担,零新网格样式)。
  Widget _buildCategoryDetail(BuildContext context) {
    final controller = _categoryController!;
    final site = _selectedCategorySite!;
    final area = _selectedCategory!;
    return Column(
      children: [
        _CategoryDetailHeader(
          site: site,
          current: area,
          onBack: _closeCategory,
          onSelectCategory: (selected) => _openCategory(site, selected),
        ),
        Expanded(
          child: BasePageView<BasePageScrollAndStateBone<LiveRoom>, LiveRoom>(
            controller: controller,
            enableRefresh: true,
            enableLoadMore: true,
            showScrollToTopBtn: SettingsService.to.page.showScrollToTopBtn.v,
            showPageSizeSelector: SettingsService.to.page.showPageSizeSelector.v,
            pageSizeOptions: SettingsService.to.page.pageSizeOptions,
            emptyBuilder: (context) => zishu.EmptyView(
              icon: Icons.live_tv_rounded,
              message: i18n('empty_live_title'),
              action: zishu.RetryButton(label: i18n('refresh'), onRetry: () => controller.refreshData()),
            ),
            // contentBuilder 在 BasePageView 内部的 Obx 里调用
            // (base_page_view.dart:141-173),读 loadding.value 即被追踪,
            // 加载尾随其出现/消失(与 ZishuBrowseView 同口径)。
            contentBuilder: (context, list, scrollController) {
              return ZishuBrowseGrid(
                rooms: list,
                scrollController: scrollController,
                loadingMore: controller.loadding.value && list.isNotEmpty,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 分类详情顶部面包屑行(高 36):返回钮 + 当前分类名 + 同站分类快切
/// chips 横滚。chips 与分组栏同一数据源(`AreasListController.categories`
/// 展开子分类),点击原位切分类(不回外壳,同一数据管线重建控制器)。
class _CategoryDetailHeader extends StatelessWidget {
  final Site site;
  final LiveArea current;
  final VoidCallback onBack;
  final void Function(LiveArea area) onSelectCategory;

  const _CategoryDetailHeader({
    required this.site,
    required this.current,
    required this.onBack,
    required this.onSelectCategory,
  });

  /// 面包屑行高(交付口径)。
  static const double _headerHeight = 36;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final rawName = current.areaName?.trim() ?? '';
    final currentName = rawName.isEmpty ? i18n('unnamed_area') : rawName;
    return Container(
      height: _headerHeight,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          InkResponse(
            onTap: onBack,
            radius: 16,
            hoverColor: tokens.surfaceRaised,
            child: Tooltip(
              message: i18n('back'),
              child: SizedBox(
                width: 24,
                height: 24,
                child: Icon(Remix.arrow_left_s_line, size: 18, color: tokens.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            currentName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textBody.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _CategoryQuickChips(site: site, current: current, onSelect: onSelectCategory),
          ),
        ],
      ),
    );
  }
}

/// 同站分类快切 chips:目录控制器未注册/目录为空时不占位(只留面包屑)。
class _CategoryQuickChips extends StatelessWidget {
  final Site site;
  final LiveArea current;
  final void Function(LiveArea area) onSelect;

  const _CategoryQuickChips({required this.site, required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AreasListController>(tag: site.id)) {
      return const SizedBox.shrink();
    }
    final controller = Get.find<AreasListController>(tag: site.id);
    return Obx(() {
      final chips = <LiveArea>[
        for (final group in controller.categories)
          for (final area in group.children)
            if ((area.areaName ?? '').trim().isNotEmpty) area,
      ];
      if (chips.isEmpty) return const SizedBox.shrink();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final chip in chips) ...[
              if (!identical(chip, chips.first)) const SizedBox(width: AppSpacing.xs),
              _QuickCategoryChip(
                label: chip.areaName!.trim(),
                selected: chip.hasSameIdentity(current),
                onTap: () => onSelect(chip),
              ),
            ],
          ],
        ),
      );
    });
  }
}

/// 快切 chip:_CategoryChip 同视觉(选中 = 抬升底 + 品牌金描边),纵向
/// 内边距压缩适配 36px 面包屑行高(原 chips 上下各 AppSpacing.sm 放不下)。
class _QuickCategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QuickCategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.allMd,
      hoverColor: tokens.surfaceRaised,
      splashColor: AppStateLayer.splashOf(tokens.accent),
      highlightColor: AppStateLayer.pressedOf(tokens.accent),
      focusColor: AppStateLayer.focusOf(tokens.accent),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 3.5),
        decoration: BoxDecoration(
          color: selected ? tokens.surfaceRaised : Colors.transparent,
          borderRadius: AppRadius.allMd,
          border: Border.all(color: selected ? tokens.accent : tokens.border, width: 1),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textBody.copyWith(
            color: selected ? tokens.textPrimary : tokens.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// 左侧分组栏(对齐 zishu `category_view.dart` 的 `_GroupTabs`):132px
/// 分组名列表,独立纵向滚动;点分组只切 `AreasListController.tabIndex`
/// (本地分页切片),不进路由。选中态 = surfaceRaised 底 + 品牌金描边。
class _CategorySideBar extends StatelessWidget {
  final AreasListController controller;

  const _CategorySideBar({required this.controller});

  /// 左侧分组栏宽度(zishu `_tabsWidth = 132`)。
  static const double _sideBarWidth = 132;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final categories = controller.categories;
      final selected = controller.tabIndex.value;
      return Container(
        width: _sideBarWidth,
        color: context.tokens.surface,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          children: [
            for (var i = 0; i < categories.length; i++)
              _GroupTab(label: categories[i].name, selected: i == selected, onTap: () => controller.selectCategory(i)),
          ],
        ),
      );
    });
  }
}

/// 分组 tab:全宽 tile,选中 = surfaceRaised 底 + 品牌金描边 + 主文字,
/// 未选中 = 透明底 + 次级文字(状态层全部走 token)。描边经透明边框占位,
/// 选中切换不跳布局。
class _GroupTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GroupTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: selected ? tokens.surfaceRaised : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        // 选中底已是 surfaceRaised,hover 退一档到 surface;未选中 hover
        // 抬到 surfaceRaised(zishu `_GroupTab` 同口径)。
        hoverColor: selected ? tokens.surface : tokens.surfaceRaised,
        splashColor: AppStateLayer.splashOf(tokens.accent),
        highlightColor: AppStateLayer.pressedOf(tokens.accent),
        focusColor: AppStateLayer.focusOf(tokens.accent),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: selected ? tokens.accent : Colors.transparent)),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textBody.copyWith(
              color: selected ? tokens.textPrimary : tokens.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// 顶部分类 chips 行(窄容器 <680 的分组栏形态):横向滚动,选中态品牌
/// 金描边 + 抬升底。
class _CategoryChipRow extends StatelessWidget {
  final AreasListController controller;

  const _CategoryChipRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final categories = controller.categories;
      if (categories.isEmpty) return const SizedBox.shrink();
      final selected = controller.tabIndex.value;
      final tokens = context.tokens;
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border(bottom: BorderSide(color: tokens.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < categories.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xs),
                _CategoryChip(
                  label: categories[i].name,
                  selected: i == selected,
                  onTap: () => controller.selectCategory(i),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

/// 分类 chip:未选中 = 透明底 + border 描边 + 次级文字;
/// 选中 = surfaceRaised 抬升底 + 品牌金描边 + 主文字。
/// 状态层全部走 token(与外壳平台 tab、zishu 卡片同口径)。
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.allMd,
      hoverColor: tokens.surfaceRaised,
      splashColor: AppStateLayer.splashOf(tokens.accent),
      highlightColor: AppStateLayer.pressedOf(tokens.accent),
      focusColor: AppStateLayer.focusOf(tokens.accent),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? tokens.surfaceRaised : Colors.transparent,
          borderRadius: AppRadius.allMd,
          border: Border.all(color: selected ? tokens.accent : tokens.border, width: 1),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textBody.copyWith(
            color: selected ? tokens.textPrimary : tokens.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
