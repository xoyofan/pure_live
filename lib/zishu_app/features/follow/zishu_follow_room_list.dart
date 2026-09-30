import 'dart:math' as math;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/zishu/presentation/category_colors.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/state_dot.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/browse/zishu_room_card.dart';

/// 视图档位:卡片网格 / 单行列(对齐 zishu FollowDensity,用户口径
/// 2026-09-20 只保留两档,不提供「紧凑」)。
enum ZishuFollowDensity {
  card,
  row;

  /// 文案走既有 i18n key(原字面量「卡片/列表」迁移到
  /// zh.json 的 follow_density_card / follow_density_row)。
  String get label => switch (this) {
    ZishuFollowDensity.card => i18n('follow_density_card'),
    ZishuFollowDensity.row => i18n('follow_density_row'),
  };

  IconData get icon => switch (this) {
    ZishuFollowDensity.card => Icons.grid_view_rounded,
    ZishuFollowDensity.row => Icons.format_list_bulleted_rounded,
  };
}

/// 关注列表:按 [density] 铺开 [FavoriteController] 已过滤好的条目
/// (移植 zishu FollowRoomList 的调度器形态)。
///
/// 空列表时在内容区内以 [emptyView] 占位(SliverFillRemaining),
/// 保持滚动体挂在 [scrollController] 上,下拉刷新仍然可用。
class ZishuFollowRoomList extends StatelessWidget {
  const ZishuFollowRoomList({
    super.key,
    required this.rooms,
    required this.density,
    required this.emptyView,
    this.scrollController,
  });

  final List<LiveRoom> rooms;
  final ZishuFollowDensity density;
  final Widget emptyView;
  final ScrollController? scrollController;

  final EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.sm,
    AppSpacing.lg,
    AppSpacing.lg,
  );

  /// 卡片档最小列宽(对齐 zishu 页面网格,web `minmax(240px, 1fr)`)。
  static const double _cardMaxExtent = 240;

  /// 卡片元信息区高度预算(与 ZishuBrowseGrid 的 58px 两行口径同源)。
  static const double _cardMetaHeight = 58;

  /// 列表档列宽约束(web `FollowRoomRowView--multi-col` 直译):
  /// 列宽下限 300px、单行上限 400px、列距 4.5px(0.28rem @16px 根字号)。
  static const double _rowColFloor = 300;
  static const double _rowColMax = 400;
  static const double _rowColGap = 4.5;

  /// 列表档行高(zishu FollowEntryRow.rowHeight)。
  static const double rowHeight = 26;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return CustomScrollView(
        controller: scrollController,
        slivers: [SliverFillRemaining(hasScrollBody: false, child: emptyView)],
      );
    }
    return switch (density) {
      ZishuFollowDensity.card => _buildCardGrid(context),
      ZishuFollowDensity.row => _buildRowGrid(context),
    };
  }

  /// 卡片网格:按 240px 最小列宽自适应分列,「封面 16:9 + 元信息区」
  /// 精确推导纵横比,避免不同宽度下溢出。
  Widget _buildCardGrid(BuildContext context) {
    const spacing = AppSpacing.md;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(0.0, constraints.maxWidth - padding.horizontal);
        final columns = math.max(1, (width / _cardMaxExtent).floor());
        final gaps = spacing * (columns - 1);
        final cardWidth = width <= 0 ? 1.0 : (width - gaps) / columns;
        final metaHeight = metaHeightFor(_cardMetaHeight, context);
        return GridView.builder(
          controller: scrollController,
          padding: padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: cardWidth / (cardWidth * 9 / 16 + metaHeight),
          ),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];
            return ZishuRoomCard(key: ValueKey('${room.platform}:${room.roomId}'), room: room);
          },
        );
      },
    );
  }

  /// 列表档:单行小表格自适应多列平铺;行本体限宽 400、靠左放置。
  Widget _buildRowGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(0.0, constraints.maxWidth - padding.horizontal);
        final columns = _responsiveColCount(width, floor: _rowColFloor, max: _rowColMax, gap: _rowColGap);
        final cellWidth = math.max(1.0, (width - _rowColGap * (columns - 1)) / columns);
        return GridView.builder(
          controller: scrollController,
          padding: padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 0,
            crossAxisSpacing: _rowColGap,
            childAspectRatio: cellWidth / rowHeight,
          ),
          itemCount: rooms.length,
          itemBuilder: (context, index) => Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _rowColMax),
              child: ZishuFollowRowItem(room: rooms[index]),
            ),
          ),
        );
      },
    );
  }

  /// 「列宽不小于 floor、不超过 max」的列数计算(逐字移植 zishu
  /// `computeResponsiveColCount`,真源 web `computeResponsiveColCount`):
  /// 先按下限取列数,再上调到列宽 ≤ max,最后回落保证列宽 ≥ floor。
  static int _responsiveColCount(double inner, {required double floor, required double max, required double gap}) {
    if (inner <= 0) return 1;
    var cols = math.max(1, ((inner + gap) / (floor + gap)).floor());
    while (cols < 64) {
      final share = (inner - (cols - 1) * gap) / cols;
      if (share <= max) break;
      cols += 1;
    }
    while (cols > 1) {
      final share = (inner - (cols - 1) * gap) / cols;
      if (share >= floor) break;
      cols -= 1;
    }
    return cols;
  }
}

/// 列表档单行(移植 zishu FollowEntryRow 的四列表格):
/// 分类 / 主播名 / 标题 / 状态(在播 = 呼吸圆点 + 观众数、
/// 录播 = 金色「录播」、未开播 = 次级「未开播」)。
class ZishuFollowRowItem extends StatelessWidget {
  const ZishuFollowRowItem({super.key, required this.room});

  final LiveRoom room;

  /// 状态列宽(圆点 + 最多 5 字人数/状态文案)。
  static const double _statusColumnWidth = 72;
  static const double _categoryColumnWidth = 54;
  static const double _anchorColumnWidth = 72;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      key: Key('follow-row-${room.platform}-${room.roomId}'),
      color: tokens.surface,
      child: InkWell(
        onTap: () => AppNavigator.toLiveRoomDetail(liveRoom: room),
        hoverColor: tokens.surfaceRaised,
        splashColor: AppStateLayer.splashOf(tokens.accent),
        highlightColor: AppStateLayer.pressedOf(tokens.accent),
        focusColor: AppStateLayer.focusOf(tokens.accent),
        child: Container(
          height: ZishuFollowRoomList.rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.5))),
          ),
          child: Row(
            children: [
              _categoryCell(context),
              _anchorCell(context),
              Expanded(child: _titleCell(context)),
              _statusCell(context),
            ],
          ),
        ),
      ),
    );
  }

  /// 分类列:分类色淡底 + 中性前景;无分类时留空。
  Widget _categoryCell(BuildContext context) {
    final tokens = context.tokens;
    final category = (room.area ?? '').trim();
    final style = CategoryColors.opaqueFor(category: room.area, site: room.platform ?? '');
    return SizedBox(
      width: _categoryColumnWidth,
      child: Container(
        height: double.infinity,
        alignment: Alignment.center,
        color: style?.background.withValues(alpha: 0.18),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          category,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: context.textCaption.copyWith(
            fontSize: AppFontSize.label,
            // 调色板基色(主题无关):foreground 档在浅色 18% 淡底上对比不足。
            color: style?.background ?? tokens.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _anchorCell(BuildContext context) {
    final tokens = context.tokens;
    return SizedBox(
      width: _anchorColumnWidth,
      child: Text(
        (room.nick ?? '').trim(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textCaption.copyWith(color: tokens.textPrimary),
      ),
    );
  }

  Widget _titleCell(BuildContext context) {
    final tokens = context.tokens;
    return Text(
      (room.title ?? '').trim(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.textCaption.copyWith(color: tokens.textSecondary),
    );
  }

  Widget _statusCell(BuildContext context) {
    final tokens = context.tokens;
    final live = room.isLiveNow && room.isRecord != true;
    final replay = room.effectiveLiveStatus == LiveStatus.replay;
    final String label;
    final Color color;
    if (live) {
      final online = (room.onlineViewers ?? '').trim();
      final watching = (room.watching ?? '').trim();
      label = online.isNotEmpty ? online : (watching.isNotEmpty ? watching : i18n('online_room_title'));
      color = tokens.liveBadge;
    } else if (replay) {
      label = i18n('replay');
      color = tokens.brandBright;
    } else {
      label = i18n('offline_room_title');
      color = tokens.textSecondary;
    }
    return SizedBox(
      width: _statusColumnWidth,
      child: Row(
        children: [
          StateDot(live: live),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textCaption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
