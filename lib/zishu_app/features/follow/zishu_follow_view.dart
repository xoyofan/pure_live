import 'package:pure_live/common/index.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/follow/zishu_follow_empty_state.dart';
import 'package:pure_live/zishu_app/features/follow/zishu_follow_filters.dart';
import 'package:pure_live/zishu_app/features/follow/zishu_follow_room_list.dart';

/// zishu 关注页(pure_live [FavoriteController] 适配版)。
///
/// 布局/密度对齐 zishu_flutter `features/follow/views/follow_view.dart`:
/// 标题行 + 筛选行(状态三段 / 平台 chips / 卡片·列表两档)+ 内容列表。
/// 数据与交互全部走 pure_live 既有控制器,不自建状态持久化:
/// - 状态筛选 → `tabOnlineIndex`(0 开播 / 1 录播 / 2 未开播),
///   经 `animateToStatusIndex` 与 `tabController` 保持同步;
/// - 平台筛选 → `availableFavoriteSites` + `tabSiteIndex`,经 `selectSiteIndex`;
/// - 列表/刷新 → [BasePageView](与收藏页同一套分页/刷新/错误接线)+ `refreshData`。
/// 卡片档网格复用 [ZishuRoomCard];空态为 zishu FollowEmptyState 移植版。
class ZishuFollowView extends StatelessWidget {
  const ZishuFollowView({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<FavoriteController>()) {
      // FavoriteController 由 initial_services 懒注册(fenix);启动早期占位。
      return const Center(child: CircularProgressIndicator());
    }
    return _ZishuFollowBody(controller: Get.find<FavoriteController>());
  }
}

/// 页面本体:只有「卡片/列表」两档视图密度是本页私有视图状态
/// (用户口径 2026-09-20:不提供「紧凑」档),其余状态全在控制器。
class _ZishuFollowBody extends StatefulWidget {
  const _ZishuFollowBody({required this.controller});

  final FavoriteController controller;

  @override
  State<_ZishuFollowBody> createState() => _ZishuFollowBodyState();
}

class _ZishuFollowBodyState extends State<_ZishuFollowBody> {
  ZishuFollowDensity _density = ZishuFollowDensity.card;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context),
        _buildToolbar(context),
        Expanded(child: _buildContent()),
      ],
    );
  }

  /// 标题 + 刷新行(对齐 zishu follow_view 头部:标题 headline 档,
  /// 刷新中显示 16px 进度圈替代按钮)。
  Widget _buildHeader(BuildContext context) {
    final controller = widget.controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        children: [
          Text(i18n('favorites_title'), style: context.textTitle.copyWith(fontSize: AppFontSize.headline)),
          const Spacer(),
          Obx(() {
            if (controller.loadding.value) {
              return const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
            }
            return IconButton(
              tooltip: i18n('refresh'),
              onPressed: controller.refreshData,
              icon: Icon(Icons.refresh_rounded, size: 20, color: context.tokens.textSecondary),
            );
          }),
        ],
      ),
    );
  }

  /// 筛选行:状态三段 + 平台 chips + 视图两档,Wrap 自适应换行。
  Widget _buildToolbar(BuildContext context) {
    final controller = widget.controller;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Obx(() {
        final sites = controller.availableFavoriteSites;
        final index = controller.tabSiteIndex.value;
        final selectedSiteIndex = index >= 0 && index < sites.length ? index : -1;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ZishuFollowStatusFilter(
              selectedIndex: controller.tabOnlineIndex.value,
              onSelected: controller.animateToStatusIndex,
            ),
            ZishuFollowPlatformFilter(
              sites: sites,
              selectedIndex: selectedSiteIndex,
              onSelected: controller.selectSiteIndex,
            ),
            SegmentedButton<ZishuFollowDensity>(
              segments: [
                for (final density in ZishuFollowDensity.values)
                  ButtonSegment(
                    value: density,
                    label: Text(density.label, key: Key('follow-density-${density.name}')),
                    icon: Icon(density.icon, size: 14),
                  ),
              ],
              selected: {_density},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => setState(() => _density = selection.first),
              style: zishuFollowSegmentedStyle(context),
            ),
          ],
        );
      }),
    );
  }

  /// 内容区:沿用 pure_live 收藏页的 [BasePageView] 接线(下拉刷新/桌面
  /// 键盘分页/回顶按钮),只把内容与空态渲染换成 zishu 风格。空列表的
  /// 占位由 [ZishuFollowRoomList] 在内容区内绘制(preserveContentWhenEmpty
  /// 模式下 BasePageView 自身的 emptyBuilder 不再触发)。
  Widget _buildContent() {
    final controller = widget.controller;
    return BasePageView<FavoriteController, LiveRoom>(
      controller: controller,
      enableRefresh: true,
      enableLoadMore: true,
      preserveContentWhenEmpty: true,
      showScrollToTopBtn: SettingsService.to.page.showScrollToTopBtn.v,
      showPageSizeSelector: SettingsService.to.page.showPageSizeSelector.v,
      pageSizeOptions: SettingsService.to.page.pageSizeOptions,
      emptyBuilder: (context) => ZishuFollowEmptyState(controller: controller),
      contentBuilder: (context, list, scrollController) {
        return ZishuFollowRoomList(
          rooms: list,
          density: _density,
          scrollController: scrollController,
          emptyView: ZishuFollowEmptyState(controller: controller),
        );
      },
    );
  }
}
