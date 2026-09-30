import 'package:flutter/material.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/empty_view.dart' as zishu;
import 'package:pure_live/zishu/presentation/widgets/retry_button.dart' as zishu;
import 'package:pure_live/zishu_app/features/browse/zishu_room_card.dart';

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
      contentBuilder: (context, list, scrollController) {
        return ZishuBrowseGrid(rooms: list, scrollController: scrollController);
      },
    );
  }
}

/// zishu 房间网格:断点定列([AppRoomGrid.columnsFor])、16/13.6 间距、
/// 16:9 封面 + 58px 元信息预算的等高卡片。
class ZishuBrowseGrid extends StatelessWidget {
  final List<LiveRoom> rooms;
  final ScrollController? scrollController;

  const ZishuBrowseGrid({super.key, required this.rooms, this.scrollController});

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
                delegate: SliverChildBuilderDelegate(
                  (context, index) => ZishuRoomCard(
                    key: ValueKey('${rooms[index].platform}:${rooms[index].roomId}'),
                    room: rooms[index],
                  ),
                  childCount: rooms.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
