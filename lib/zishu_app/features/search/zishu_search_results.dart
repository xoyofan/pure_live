/// zishu 搜索弹窗的结果区:既有 `SearchController` Rx 状态渲染(加载/未搜索/
/// 空态/双列卡片网格 + 分页尾),卡片复用 [ZishuRoomCard],点击先关弹窗再
/// `AppNavigator.toLiveRoomDetail` 进房。
library;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/search/search_controller.dart' as pure_live;
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/empty_view.dart' as zishu;
import 'package:pure_live/zishu/presentation/widgets/retry_button.dart' as zishu;
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/browse/zishu_room_card.dart';

/// 结果区:loading / 未搜索 / 空 / 列表 + 分页尾,全部读控制器既有 Rx。
class ZishuSearchResultArea extends StatelessWidget {
  const ZishuSearchResultArea({super.key, required this.controller});

  final pure_live.SearchController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = controller.loading.v;
      final searched = controller.searched.v;
      final results = controller.results;
      return CustomScrollView(
        controller: controller.scrollController,
        physics: const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          if (controller.pendingSiteCount.v > 0 && !loading)
            const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
          if (controller.errorMessage.v.isNotEmpty && results.isNotEmpty)
            SliverToBoxAdapter(child: ZishuSearchErrorBanner(controller: controller)),
          if (loading || !searched || results.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _buildStatus(context, loading, searched, results.isEmpty))
          else ...[
            SliverPadding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              sliver: LayoutBuilder(
                builder: (context, constraints) {
                  // 弹窗宽度上限 520 < 640:columnsFor 恒为 2 列(窄视口 2 列档)。
                  final columns = AppRoomGrid.columnsFor(constraints.maxWidth);
                  const crossSpacing = AppSpacing.gridCrossAxisSpacing;
                  const mainSpacing = AppSpacing.gridMainAxisSpacing;
                  final cardWidth = (constraints.maxWidth - (columns - 1) * crossSpacing) / columns;
                  final aspectRatio = cardWidth / (cardWidth * 9 / 16 + metaHeightFor(58, context));
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: crossSpacing,
                      mainAxisSpacing: mainSpacing,
                      childAspectRatio: aspectRatio,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => ZishuRoomCard(
                        key: ValueKey('${results[index].platform}:${results[index].roomId}'),
                        room: results[index],
                        onTap: () {
                          Navigator.of(context).pop();
                          AppNavigator.toLiveRoomDetail(liveRoom: results[index]);
                        },
                      ),
                      childCount: results.length,
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, AppSpacing.sm, 0, AppSpacing.md),
                child: Center(
                  child: controller.loadingMore.v
                      ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : controller.hasMore.v
                      ? TextButton.icon(
                          onPressed: controller.loadMore,
                          icon: const Icon(Icons.expand_more_rounded, size: 18),
                          label: Text(i18n('load_more_results')),
                        )
                      : Text(i18n('all_results_loaded'), style: context.textCaption),
                ),
              ),
            ),
          ],
        ],
      );
    });
  }

  Widget _buildStatus(BuildContext context, bool loading, bool searched, bool empty) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (!searched) {
      return zishu.EmptyView(icon: Icons.travel_explore_rounded, message: i18n('native_search_title'));
    }
    return zishu.EmptyView(
      icon: Icons.search_off_rounded,
      message: i18n('search_no_results'),
      action: controller.canSearchNatively
          ? zishu.RetryButton(label: i18n('retry'), onRetry: controller.doSearch)
          : null,
    );
  }
}

/// 错误横幅:部分站点失败等既有 errorMessage 单条展示,可续网页搜索。
class ZishuSearchErrorBanner extends StatelessWidget {
  const ZishuSearchErrorBanner({super.key, required this.controller});

  final pure_live.SearchController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: tokens.error),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              controller.errorMessage.v,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textCaption.copyWith(color: tokens.error),
            ),
          ),
          if (controller.canOpenWebSearch)
            TextButton(
              onPressed: controller.openWebSearch,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(i18n('continue_web_search'), style: context.textCaption.copyWith(color: tokens.accent)),
            ),
        ],
      ),
    );
  }
}
