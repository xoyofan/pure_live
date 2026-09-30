import 'package:pure_live/common/index.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/empty_view.dart' as zishu;
import 'package:pure_live/zishu/presentation/widgets/retry_button.dart' as zishu;
import 'package:pure_live/zishu_app/features/browse/zishu_room_card.dart';
import 'package:pure_live/zishu_app/features/browse/zishu_room_card_skeleton.dart';

/// zishu 浏览视图:热门页单站点的网格内容,接 pure_live 既有分页控制器
/// (`BasePageScrollAndStateBone<LiveRoom>`,tag = 站点 id),刷新/加载更多
/// 仍由 BasePageView 承担,网格度量走 zishu tokens。
class ZishuBrowseView extends StatelessWidget {
  final String siteId;

  const ZishuBrowseView({super.key, required this.siteId});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<BasePageScrollAndStateBone<LiveRoom>>(tag: siteId)) {
      // 分页控制器由 PopularController.initControllers 懒注册;站点表
      // 到位前先占位。
      return const Center(child: CircularProgressIndicator());
    }
    final controller = Get.find<BasePageScrollAndStateBone<LiveRoom>>(tag: siteId);
    // 首屏空数据 + 加载中 → 骨架屏(列数与下方网格同口径),数据到达后
    // 原位替换为 BasePageView 网格;失败/空态(loadding=false)仍走
    // BasePageView 的错误/空态分支,骨架不遮挡任何恢复入口。
    return Obx(() {
      if (controller.list.isEmpty && controller.loadding.value) {
        return LayoutBuilder(
          builder: (context, constraints) =>
              RoomGridSkeleton(count: AppRoomGrid.columnsFor(constraints.maxWidth), site: siteId),
        );
      }
      return BasePageView<BasePageScrollAndStateBone<LiveRoom>, LiveRoom>(
        controller: controller,
        showScrollToTopBtn: SettingsService.to.page.showScrollToTopBtn.v,
        pageSizeOptions: SettingsService.to.page.pageSizeOptions,
        showPageSizeSelector: SettingsService.to.page.showPageSizeSelector.v,
        emptyBuilder: (context) => zishu.EmptyView(
          icon: Icons.live_tv_rounded,
          message: i18n('empty_live_title'),
          action: zishu.RetryButton(label: i18n('refresh'), onRetry: () => controller.refreshData()),
        ),
        // contentBuilder 在 BasePageView 内部的 Obx 里调用
        // (base_page_view.dart:141-173),此处读 loadding.value 即被该 Obx
        // 追踪,加载尾随其出现/消失;刷新与加载更多仍由 BasePageView 的
        // EasyRefresh 驱动,footer 仅是视觉占位。
        contentBuilder: (context, list, scrollController) {
          return ZishuBrowseGrid(
            rooms: list,
            scrollController: scrollController,
            loadingMore: controller.loadding.value && list.isNotEmpty,
          );
        },
      );
    });
  }
}

/// zishu 房间网格:断点定列([AppRoomGrid.columnsFor])、16/13.6 间距、
/// 16:9 封面 + 58px 元信息预算的等高卡片。[loadingMore] 为 true 时在网格
/// 末尾渲染加载中 footer(对齐 zishu 真源 room_grid.dart 的
/// `_LoadingMoreFooter`:16px accent 环 + 「加载中」文案,占一个网格槽位)。
class ZishuBrowseGrid extends StatelessWidget {
  final List<LiveRoom> rooms;
  final ScrollController? scrollController;

  /// 控制器加载中时在网格末尾追加视觉占位 footer;加载触发仍由
  /// BasePageView 的 EasyRefresh/分页控件承担,此处不重复触发。
  final bool loadingMore;

  const ZishuBrowseGrid({super.key, required this.rooms, this.scrollController, this.loadingMore = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = AppRoomGrid.columnsFor(constraints.maxWidth);
        const crossSpacing = AppSpacing.gridCrossAxisSpacing;
        const mainSpacing = AppSpacing.gridMainAxisSpacing;
        final gridWidth = constraints.maxWidth - 2 * AppSpacing.lg;
        final cardWidth = (gridWidth - (columns - 1) * crossSpacing) / columns;
        final aspectRatio = cardWidth / (cardWidth * 9 / 16 + metaHeightFor(58, context));
        return CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: crossSpacing,
                  mainAxisSpacing: mainSpacing,
                  childAspectRatio: aspectRatio,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index >= rooms.length) return const _ZishuLoadingMoreFooter();
                  return ZishuRoomCard(
                    key: ValueKey('${rooms[index].platform}:${rooms[index].roomId}'),
                    room: rooms[index],
                  );
                }, childCount: rooms.length + (loadingMore ? 1 : 0)),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 网格末尾的加载中 footer,视觉上与卡片底色区分(移植 zishu 真源
/// `_LoadingMoreFooter`:16px accent 环 + 「加载中」文案)。
class _ZishuLoadingMoreFooter extends StatelessWidget {
  const _ZishuLoadingMoreFooter();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: AppSpacing.lg,
            height: AppSpacing.lg,
            child: CircularProgressIndicator(strokeWidth: 2, color: tokens.accent),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(i18n('refresh_loading'), style: context.textCaption),
        ],
      ),
    );
  }
}
