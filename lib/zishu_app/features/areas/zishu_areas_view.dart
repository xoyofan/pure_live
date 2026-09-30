import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/areas/areas_list_controller.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/empty_view.dart' as zishu;
import 'package:pure_live/zishu/presentation/widgets/retry_button.dart' as zishu;
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/areas/zishu_area_grid.dart';

/// zishu 分区视图(pure_live `AreasController` 适配版),形态对齐 zishu
/// `features/browse/views/category_view.dart` 的「分类索引页」简洁版:
/// - 顶部分类 chips 行:横向滚动,选中态品牌金描边 + 抬升底
///   (替代原 `AreaGridView` 的 ScrollableTabBar,即 zishu 左侧分组栏的
///   顶部 chips 化);
/// - 下方分区封面格:[ZishuAreaGrid](zishu token 度量),沿用
///   `AreasListController` 的既有局部分页/刷新管线(`BasePageView`),
///   点分区 tile 走 `AppNavigator.toCategoryDetail` 进房间流;
/// - 站点切换沿用 `AreasController.tabController`(外壳平台 tab 会
///   animateTo 它),本视图用 TabBarView 跟随,横向手势关闭,与
///   `AreasPage` 同构(两个同轴手势不打架的既有裁决)。
class ZishuAreasView extends StatelessWidget {
  const ZishuAreasView({super.key});

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
        children: [for (final site in sites) _SiteAreasPane(siteId: site.id)],
      );
    });
  }
}

/// 单站点分区面板:分类 chips 行 + 分区封面格。
class _SiteAreasPane extends StatelessWidget {
  final String siteId;

  const _SiteAreasPane({required this.siteId});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AreasListController>(tag: siteId)) {
      // AreasController 已对全部站点 lazyPut(fenix);站点表就位前占位。
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final controller = Get.find<AreasListController>(tag: siteId);
    return Obx(() {
      // 抖音扁平站点无分类层级,直接铺全量分区(对齐 AreaGridView.isFlatten)。
      final hasChips = !controller.isFlatten && controller.categories.isNotEmpty;
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
          return ZishuAreaGrid(areas: list, scrollController: scrollController);
        },
      );
      if (!hasChips) return grid;
      return Column(
        children: [
          _CategoryChipRow(controller: controller),
          Expanded(child: grid),
        ],
      );
    });
  }
}

/// 顶部分类 chips 行:横向滚动,选中态品牌金描边。
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
          border: Border.all(color: selected ? tokens.brand : tokens.border, width: 1),
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
