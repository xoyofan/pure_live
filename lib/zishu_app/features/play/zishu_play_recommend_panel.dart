// zishu 播放页侧栏「推荐」tab(真源:zishu_flutter
// `side_panel/recommend_panel.dart` → `play_recommend_panel.dart` 的
// pure_live 数据源适配版)。
//
// 对齐口径:
// - 无标题,直接铺 2 列封面网格(真源 `_columns = 2`;卡片复用「我的关注」
//   页同款 ZishuRoomCard,几何对齐真源 PlayRoomGrid:间距 sm、卡高 =
//   封面 16:9 + 两行元信息,由实际列宽反推纵横比);
// - 首屏加载渲染灰底骨架卡(对齐真源 `_SkeletonCard`:封面块 + 两条
//   文字块,灰度全走 tokens);
// - 推荐里剔除当前房间(真源:roomId 相同不出现自己);
// - 滚到底部附近追加下一页(真源 _loadMoreThreshold = 160;分页走热门页
//   既有 `BasePageScrollAndStateBone.loadMoreData`,其自带加载中防重入);
// - 点击卡片进房沿用 `AppNavigator.toLiveRoomDetail`(pure_live 既有切房
//   通道;真源的 pushReplacement 语义由侧栏会话级 tab 记忆承接 —— 切房
//   重建后右侧仍停在推荐 tab,不退回聊天)。
//
// 与真源的差异(报告口径):真源推荐是跨平台交错(分类映射 + 热门兜底,
// play_recommend_provider),pure_live 无该编排,数据源为当前平台热门流。

import 'dart:async';
import 'dart:math' as math;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/empty_view.dart' as zishu;
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/browse/zishu_room_card.dart';

/// zishu 播放页侧栏「推荐」tab:同平台热门流 2 列封面网格,点击换房。
class ZishuPlayRecommendPanel extends StatefulWidget {
  const ZishuPlayRecommendPanel({super.key, required this.room});

  /// 当前房间快照:取平台定位热门流控制器,并把当前房从推荐里剔除。
  final LiveRoom room;

  @override
  State<ZishuPlayRecommendPanel> createState() => _ZishuPlayRecommendPanelState();
}

class _ZishuPlayRecommendPanelState extends State<ZishuPlayRecommendPanel> {
  /// 列数:侧栏宽度下 2 列(对齐真源 _columns)。
  static const int _columns = 2;

  /// 卡片元信息区(封面下两行文本)高度预算,与「我的关注」页网格同值。
  static const double _cardMetaHeight = 58;

  /// 触底阈值:距底部不足这个距离就预取下一页(对齐真源)。
  static const double _loadMoreThreshold = 160;

  /// 首屏骨架卡张数(约 3 行 × 2 列,对齐真源每站骨架量的视觉体量)。
  static const int _skeletonCount = 6;

  /// 首屏加载已触发(与原推荐 tab 同款一次性 kick,防 build 内重复请求)。
  bool _kicked = false;

  bool _isCurrentRoom(LiveRoom room) =>
      room.normalizedPlatformId == widget.room.normalizedPlatformId &&
      room.normalizedRoomId == widget.room.normalizedRoomId;

  BasePageScrollAndStateBone<LiveRoom>? _controllerFor(String platform) {
    if (platform.isEmpty || !Get.isRegistered<BasePageScrollAndStateBone<LiveRoom>>(tag: platform)) {
      return null;
    }
    return Get.find<BasePageScrollAndStateBone<LiveRoom>>(tag: platform);
  }

  /// 滚到底部附近 → 追加下一页(编排层自带防重入)。
  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.metrics.extentAfter > _loadMoreThreshold) return false;
    final controller = _controllerFor(widget.room.platform ?? '');
    if (controller != null && controller.canLoadMore.value) {
      unawaited(controller.loadMoreData());
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controllerFor(widget.room.platform ?? '');
    if (controller == null) {
      // 无该站点控制器(iptv 等)或未注册:空态占位。
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: zishu.EmptyView(icon: Icons.live_tv_rounded, message: i18n('empty_live_title')),
      );
    }
    if (!_kicked && controller.list.isEmpty && !controller.loadding.value) {
      _kicked = true;
      controller.loadData();
    }
    return Obx(() {
      final rooms = controller.list.where((room) => !_isCurrentRoom(room)).toList(growable: false);
      if (rooms.isEmpty) {
        // 首屏加载中渲染骨架(对齐真源);加载落空给空态。
        return controller.loadding.value ? _buildSkeletonGrid(context) : _buildEmpty(context);
      }
      return NotificationListener<ScrollNotification>(onNotification: _onScroll, child: _buildGrid(context, rooms));
    });
  }

  Widget _buildEmpty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: zishu.EmptyView(icon: Icons.live_tv_rounded, message: i18n('empty_live_title')),
    );
  }

  /// 网格几何与「我的关注」页同源:2 列、间距 sm、纵横比由实际列宽反推。
  SliverGridDelegate _gridDelegate(BuildContext context, double maxWidth) {
    const padding = EdgeInsets.symmetric(horizontal: AppSpacing.sm);
    final width = math.max(0.0, maxWidth - padding.horizontal);
    final cardWidth = math.max(1.0, (width - AppSpacing.sm * (_columns - 1)) / _columns);
    final metaHeight = metaHeightFor(_cardMetaHeight, context);
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: _columns,
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: cardWidth / (cardWidth * 9 / 16 + metaHeight),
    );
  }

  Widget _buildGrid(BuildContext context, List<LiveRoom> rooms) {
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        key: const Key('play-side-recommend-grid'),
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
        gridDelegate: _gridDelegate(context, constraints.maxWidth),
        itemCount: rooms.length,
        itemBuilder: (context, index) => ZishuRoomCard(room: rooms[index]),
      ),
    );
  }

  /// 首屏骨架网格(对齐真源 _SkeletonCard:封面块 + 两条文字块)。
  Widget _buildSkeletonGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        key: const Key('play-side-recommend-skeleton'),
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
        gridDelegate: _gridDelegate(context, constraints.maxWidth),
        itemCount: _skeletonCount,
        itemBuilder: (context, index) => const _RecommendSkeletonCard(),
      ),
    );
  }
}

/// 骨架占位卡:封面块 + 两条文字块,灰度色全部取 tokens(对齐真源)。
class _RecommendSkeletonCard extends StatelessWidget {
  const _RecommendSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    Widget bar({required double widthFactor, required double height}) {
      return FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widthFactor,
        child: Container(
          height: height,
          decoration: BoxDecoration(color: tokens.surfaceRaised, borderRadius: AppRadius.allSm),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: AppRadius.allSm,
        border: Border.all(color: tokens.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(color: tokens.surfaceRaised),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                bar(widthFactor: 0.7, height: 9),
                const SizedBox(height: 5),
                bar(widthFactor: 0.45, height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
