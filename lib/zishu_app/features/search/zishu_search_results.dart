/// zishu 搜索弹窗的结果区:按档位切渲染 —— 房间档保持既有双列卡片网格
/// (已裁决形态,复用 [ZishuRoomCard]),主播档为单列行 tile
/// ([ZishuSearchAnchorTile]);输入实时解析出的房间号/链接直达 tile 置于
/// 结果区顶部(真源 zishu search_view.dart:331-337,仅房间档显示,
/// 真源 :315-316 既有口径:主播档输入房间号无意义)。
///
/// 加载/进度/错误/加载更多全部沿用既有 `SearchController` Rx,两档共用
/// 同一套管线状态;点击先关弹窗再 `AppNavigator.toLiveRoomDetail` 进房。
library;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/search/search_controller.dart' as pure_live;
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/empty_view.dart' as zishu;
import 'package:pure_live/zishu/presentation/widgets/retry_button.dart' as zishu;
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/browse/zishu_room_card.dart';
import 'package:pure_live/zishu_app/features/search/zishu_search_anchor_tile.dart';

/// 无 i18n key 的中文文案(记录):
/// - 分档空态:真源 search_view.dart:363 同口径(`未找到与「kw」相关的{名词}`);
/// - 直达 tile:真源 search_direct_tile.dart:57 同文案;
/// - 未开播拦截:复用 zishu_anchor_tile.dart 的 zishuAnchorOfflineMessage。
String _emptyMessage(String keyword, String noun) => '未找到与「$keyword」相关的$noun';

const String _kRoomNoun = '房间';
const String _kAnchorNoun = '主播';
const String _kOpenLinkLabel = '打开链接';
const String _kEnterRoomDirectPrefix = '进入房间 ';

/// 结果区:直达 tile / loading / 未搜索 / 分档空态 / 列表 + 分页尾。
class ZishuSearchResultArea extends StatelessWidget {
  const ZishuSearchResultArea({super.key, required this.controller, this.onOpenDirect});

  final pure_live.SearchController controller;

  /// 房间档直达 tile 点击(宿主处理进房与全平台拦截提示)。
  final ValueChanged<pure_live.DirectTarget>? onOpenDirect;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isRoomTab = controller.searchType.v == pure_live.SearchType.rooms;
      final loading = controller.loading.v;
      final searched = controller.searched.v;
      final results = controller.results;
      final anchors = controller.anchors;
      final hasItems = isRoomTab ? results.isNotEmpty : anchors.isNotEmpty;
      return CustomScrollView(
        controller: controller.scrollController,
        physics: const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          // 房间档直达 tile:输入实时解析(RoomId/斗鱼链接),置顶高亮;
          // 搜索进行中也保持可见(真源 :331-337 直达恒在列表首位)。
          if (isRoomTab && controller.direct.v != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: _SearchDirectTile(
                  target: controller.direct.v!,
                  onTap: () => onOpenDirect?.call(controller.direct.v!),
                ),
              ),
            ),
          if (controller.pendingSiteCount.v > 0 && !loading)
            const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
          if (controller.errorMessage.v.isNotEmpty && hasItems)
            SliverToBoxAdapter(child: ZishuSearchErrorBanner(controller: controller)),
          if (loading || !searched || !hasItems)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildStatus(context, loading, searched, hasItems, isRoomTab),
            )
          else ...[
            if (isRoomTab) ..._buildRoomSlivers(context) else _buildAnchorSliver(context),
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

  /// 房间档:既有双列卡片网格(已裁决形态,原样保留)。
  List<Widget> _buildRoomSlivers(BuildContext context) {
    final results = controller.results;
    return [
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
    ];
  }

  /// 主播档:单列行 tile 列表(真源 search_view.dart:350-358 的行列表形态)。
  Widget _buildAnchorSliver(BuildContext context) {
    final anchors = controller.anchors;
    return SliverPadding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final hit = anchors[index];
          return ZishuSearchAnchorTile(
            key: ValueKey('${hit.site.id}:${hit.anchor.roomId}'),
            site: hit.site.id,
            anchor: hit.anchor,
            onRowTap: () => _openAnchorRoom(context, hit),
            onEnterTap: () => _openAnchorRoom(context, hit),
          );
        }, childCount: anchors.length),
      ),
    );
  }

  /// 主播行进房:未开播拦截提示(真源 search_view.dart:92-98 同口径);
  /// 本仓无主播页路由,行/钮点击均按 roomId 构造 LiveRoom 进房(妥协已记录)。
  void _openAnchorRoom(BuildContext context, pure_live.SearchAnchorHit hit) {
    if (!hit.anchor.liveStatus) {
      ToastUtil.show(zishuAnchorOfflineMessage(hit.anchor.userName));
      return;
    }
    Navigator.of(context).pop();
    AppNavigator.toLiveRoomDetail(
      liveRoom: LiveRoom(platform: hit.site.id, roomId: hit.anchor.roomId),
    );
  }

  Widget _buildStatus(BuildContext context, bool loading, bool searched, bool hasItems, bool isRoomTab) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (!searched) {
      return zishu.EmptyView(icon: Icons.travel_explore_rounded, message: i18n('native_search_title'));
    }
    // 总失败 / 不支持(全平台档下全站失败、单选 web-only 站、不支持主播档
    // 的切站竞态)时既有 errorMessage 非空且无结果 —— 优先展示错误本身,
    // 不被分档空态文案吞掉(真源 search_view.dart:190-203 同口径)。
    final error = controller.errorMessage.v;
    if (error.isNotEmpty && !hasItems) {
      return zishu.EmptyView(
        icon: Icons.search_off_rounded,
        message: error,
        action: _canRetry(isRoomTab) ? zishu.RetryButton(label: i18n('retry'), onRetry: controller.doSearch) : null,
      );
    }
    return zishu.EmptyView(
      icon: Icons.search_off_rounded,
      // 空态名词随档位切换(真源 search_view.dart:363 的 searchNoun 同口径)。
      message: _emptyMessage(controller.searchController.text.trim(), isRoomTab ? _kRoomNoun : _kAnchorNoun),
      action: _canRetry(isRoomTab) ? zishu.RetryButton(label: i18n('retry'), onRetry: controller.doSearch) : null,
    );
  }

  /// 重试可用性按档位取各自能力位(房间档沿用既有 canSearchNatively)。
  bool _canRetry(bool isRoomTab) =>
      isRoomTab ? controller.canSearchNatively : controller.supportsAnchorSearchAt(controller.index.v);
}

/// 直达高亮 tile:accent 12% 淡底 + accent 60% 描边,几何/交互态逐字照真源
/// search_direct_tile.dart:23-88(meeting_room/link 图标 18 accent、标题
/// w700、右尾 arrow_forward_ios_rounded 12 accent、hover accent 10% 叠加)。
class _SearchDirectTile extends StatelessWidget {
  const _SearchDirectTile({required this.target, required this.onTap});

  final pure_live.DirectTarget target;
  final VoidCallback onTap;

  bool get _isLink => target.kind == pure_live.DirectKind.link;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: tokens.accent.withValues(alpha: 0.12),
      borderRadius: AppRadius.allMd,
      child: InkWell(
        borderRadius: AppRadius.allMd,
        onTap: onTap,
        // 直达项底已是 accent 淡底,hover 用同一 accent 低 alpha 加深;
        // 焦点/按压同族(不盖掉 accent 语义)。真源 :29-34 同口径。
        hoverColor: tokens.accent.withValues(alpha: 0.10),
        splashColor: AppStateLayer.splashOf(tokens.accent),
        highlightColor: AppStateLayer.pressedOf(tokens.accent),
        focusColor: AppStateLayer.focusOf(tokens.accent),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.allMd,
            border: Border.all(color: tokens.accent.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Icon(_isLink ? Icons.link_rounded : Icons.meeting_room_rounded, size: 18, color: tokens.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLink ? _kOpenLinkLabel : '$_kEnterRoomDirectPrefix${target.roomId}',
                      style: context.textBody.copyWith(color: tokens.textPrimary, fontWeight: FontWeight.w700),
                    ),
                    // 链接直达:副行展示原始输入(真源 :63-74 同构)。
                    if (_isLink && (target.url?.isNotEmpty ?? false))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          target.url!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textCaption.copyWith(color: tokens.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: tokens.accent),
            ],
          ),
        ),
      ),
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
