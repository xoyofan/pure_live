import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/areas/areas_list_controller.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/empty_view.dart' as zishu;
import 'package:pure_live/zishu/presentation/widgets/retry_button.dart' as zishu;
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/areas/zishu_area_grid.dart';

/// zishu 分区视图(pure_live `AreasController` 适配版),形态对齐 zishu
/// `features/browse/views/category_view.dart` 的「分类索引页」:
/// - 宽容器(≥680):左侧分组栏(132px,分组名列表,选中态品牌金描边)
///   + 右侧该分组子分类封面格,即 zishu `_GroupTabs` + `_CategoryGrid`
///   的索引形态(分类数据复用 `AreasListController.categories`,点分组只
///   切 `tabIndex`,不进路由);
/// - 窄容器(<680):分组栏转顶部横滚 chips(不挤内容区),封面格占满;
/// - 分区封面格 [ZishuAreaGrid](zishu token 度量),沿用
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

/// 单站点分区面板:左侧分组栏(宽容器)/顶部 chips 行(窄容器)+ 分区封面格。
class _SiteAreasPane extends StatelessWidget {
  final String siteId;

  const _SiteAreasPane({required this.siteId});

  /// 分组栏与顶部 chips 的形态分界:容器宽 <680 视为窄容器,分组栏
  /// 转顶部横滚 chips(量容器而非屏幕,分区面板嵌在外壳内容区里)。
  static const double _groupBarBreakpoint = 680;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AreasListController>(tag: siteId)) {
      // AreasController 已对全部站点 lazyPut(fenix);站点表就位前占位。
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final controller = Get.find<AreasListController>(tag: siteId);
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
              return ZishuAreaGrid(areas: list, scrollController: scrollController);
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
          decoration: BoxDecoration(border: Border.all(color: selected ? tokens.brand : Colors.transparent)),
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
