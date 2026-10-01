import 'dart:math' as math;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/zishu/presentation/category_colors.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/platform_brands.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/follow/zishu_follow_entry_card.dart';
import 'package:pure_live/zishu_app/features/play/super_follow_controller.dart';
import 'package:pure_live/zishu_app/translation/translated_text.dart';

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
///
/// 批量管理(真源 FollowRoomList selectMode 口径):[selectMode] 打开时
/// 条目行首/封面左上出现复选框,点击语义交由 [onTap](页面在批量态改为
/// 切换选中),[onLongPress] 供长按进批量。
class ZishuFollowRoomList extends StatelessWidget {
  const ZishuFollowRoomList({
    super.key,
    required this.rooms,
    required this.density,
    required this.emptyView,
    this.scrollController,
    this.selectMode = false,
    this.selectedKeys = const <String>{},
    this.onTap,
    this.onLongPress,
    this.onToggleSelect,
    this.onToggleSuper,
    this.onToggleRemind,
    this.onRemove,
  });

  final List<LiveRoom> rooms;
  final ZishuFollowDensity density;
  final Widget emptyView;
  final ScrollController? scrollController;

  /// 批量选择态与选择集(key = `platform:roomId`,即 [LiveRoom.identityKey])。
  final bool selectMode;
  final Set<String> selectedKeys;

  /// 点击条目(缺省进播放页;批量模式下由页面改为切换选中)。
  final void Function(LiveRoom room)? onTap;
  final void Function(LiveRoom room)? onLongPress;
  final void Function(LiveRoom room)? onToggleSelect;
  final void Function(LiveRoom room)? onToggleSuper;
  final void Function(LiveRoom room)? onToggleRemind;
  final void Function(LiveRoom room)? onRemove;

  final EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.sm,
    AppSpacing.lg,
    AppSpacing.lg,
  );

  /// 卡片档最小列宽(对齐 zishu 页面网格,web `minmax(240px, 1fr)`)。
  static const double _cardMaxExtent = 240;

  /// 卡片元信息区高度预算:页面档 92(真源 follow_room_list.dart:99
  /// `_cardMetaHeight` 页面档,含统计/操作行三行),侧栏 compact 46 不在
  /// 本列表内(侧栏网格由播放页侧栏轨自建)。
  static const double _cardMetaHeight = 92;

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
            return ZishuFollowEntryCard(
              key: ValueKey('${room.platform}:${room.roomId}'),
              room: room,
              selectMode: selectMode,
              selected: selectedKeys.contains(room.identityKey),
              onTap: () => (onTap ?? (r) => AppNavigator.toLiveRoomDetail(liveRoom: r))(room),
              onLongPress: onLongPress == null ? null : () => onLongPress!(room),
              onToggleSelect: onToggleSelect == null ? null : () => onToggleSelect!(room),
              onToggleSuper: onToggleSuper == null ? null : () => onToggleSuper!(room),
              onToggleRemind: onToggleRemind == null ? null : () => onToggleRemind!(room),
              onRemove: onRemove == null ? null : () => onRemove!(room),
            );
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
              child: ZishuFollowRowItem(
                room: rooms[index],
                selectMode: selectMode,
                selected: selectedKeys.contains(rooms[index].identityKey),
                onTap: onTap == null ? null : () => onTap!(rooms[index]),
                onLongPress: onLongPress == null ? null : () => onLongPress!(rooms[index]),
                onToggleSelect: onToggleSelect == null ? null : () => onToggleSelect!(rooms[index]),
              ),
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

/// 列表档单行(对齐真源 zishu `FollowEntryRow` 四列表格,「我的关注」页与
/// 播放页侧栏共用同一行组件 —— 真源口径:两处只有一套行视图):
/// 分类 / 主播名 / 标题 / 状态(在播 = 人形图标 + 人数、轮播 = 金色描边
/// 「轮播」小标签、未开播 = 次级文案)。批量模式在行首插入复选框
/// (真源 FollowEntryRow selectMode 分支同款)。
class ZishuFollowRowItem extends StatelessWidget {
  const ZishuFollowRowItem({
    super.key,
    required this.room,
    this.selectMode = false,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.onToggleSelect,
  });

  final LiveRoom room;

  /// 批量选择模式:行首 18px 复选框,选中行铺品牌色淡底(真源同款)。
  final bool selectMode;
  final bool selected;

  /// 点击回调(缺省进播放页;批量模式下由页面改为切换选中)。
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 复选框勾选回调(行本体点击的切换由页面 onTap 承担)。
  final VoidCallback? onToggleSelect;

  /// 状态列宽(人形图标 + 最多 5 字人数/状态文案)。
  static const double _statusColumnWidth = 72;
  static const double _categoryColumnWidth = 54;

  /// 主播名列宽(真源 FollowEntryRow 固定 84)。
  static const double _anchorColumnWidth = 84;

  /// 离线置灰滤镜(真源 follow_common.dart `kGrayscaleFilter` 原矩阵)。
  static final ColorFilter _grayscaleFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final live = room.isLiveNow && room.isRecord != true;
    // 批量选中行底:品牌色淡底,未收录平台回退 accent(真源
    // FollowEntryRow selectedBg 同口径)。
    final brand = PlatformBrandCatalog.byId(room.normalizedPlatformId);
    final selectedBg = (brand?.color ?? tokens.accent).withValues(alpha: 0.14);
    final row = Material(
      key: Key('follow-row-${room.platform}-${room.roomId}'),
      color: selectMode && selected ? selectedBg : tokens.surface,
      child: InkWell(
        onTap: onTap ?? () => AppNavigator.toLiveRoomDetail(liveRoom: room),
        onLongPress: onLongPress,
        // 状态反馈(真源 FollowEntryRow 同款):hover 抬亮;焦点/按压 accent 低 alpha。
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
              if (selectMode) ...[
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: selected,
                    onChanged: (_) => onToggleSelect?.call(),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeColor: tokens.accent,
                    checkColor: tokens.surfaceSoft,
                    side: BorderSide(color: tokens.border),
                    // hover/焦点/按压状态层走 token(AppStateLayer 等价)。
                    overlayColor: zishuFollowControlStateLayer(tokens),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              _categoryCell(context),
              const SizedBox(width: 4),
              _anchorCell(context),
              const SizedBox(width: 4),
              Expanded(child: _titleCell(context)),
              const SizedBox(width: 4),
              _statusCell(context),
            ],
          ),
        ),
      ),
    );
    // 离线/轮播行整行降权:55% 透明 + 置灰(真源 FollowEntryRow 同款;
    // 侧栏只显在播,该分支只在「我的关注」页生效)。
    if (!live) {
      return Opacity(
        opacity: 0.55,
        child: ColorFiltered(colorFilter: _grayscaleFilter, child: row),
      );
    }
    return row;
  }

  /// 分类列:分类色淡底 + 中性前景(对齐真源行首分类列;文字色次级)。
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
          style: context.textCaption.copyWith(fontSize: AppFontSize.label, color: tokens.textSecondary),
        ),
      ),
    );
  }

  /// 主播名列:固定列宽,平台品牌色(在播)/同色 60%(离线),超关 ★ 前缀
  /// (真源 FollowEntryRow + FollowAnchorName 口径;本仓「特别关注」语义
  /// 由本地超关标记承载)。中文名走翻译挂接(译文到达原位替换)。
  Widget _anchorCell(BuildContext context) {
    final tokens = context.tokens;
    final brand = PlatformBrandCatalog.byId(room.normalizedPlatformId);
    final live = room.isLiveNow && room.isRecord != true;
    final color = brand != null
        ? (live ? brand.color : brand.color.withValues(alpha: 0.6))
        : (live ? tokens.textPrimary : tokens.textSecondary);
    final isSuper = SuperFollowController.to.isSuper(room);
    return SizedBox(
      width: _anchorColumnWidth,
      child: Row(
        children: [
          if (isSuper) ...[Icon(Icons.star_rounded, size: 11, color: tokens.brand), const SizedBox(width: 2)],
          Expanded(
            child: TranslatedText(
              text: (room.nick ?? '').trim(),
              maxLines: 1,
              style: context.textBody.copyWith(
                fontSize: AppFontSize.caption,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _titleCell(BuildContext context) {
    return TranslatedText(
      text: (room.title ?? '').trim(),
      maxLines: 1,
      style: context.textCaption.copyWith(color: context.tokens.textSecondary),
    );
  }

  /// 状态列:在播 = 人形图标 + 人数(数字等宽、次级色,真源不把人数染成
  /// 强调色);轮播 = 金黄描边「轮播」小标签;未开播 = 次级文案。
  Widget _statusCell(BuildContext context) {
    final tokens = context.tokens;
    final live = room.isLiveNow && room.isRecord != true;
    final replay = room.effectiveLiveStatus == LiveStatus.replay;
    if (live) {
      final online = (room.onlineViewers ?? '').trim();
      final watching = (room.watching ?? '').trim();
      final label = online.isNotEmpty
          ? readableCount(online)
          : (watching.isNotEmpty ? readableCount(watching) : i18n('online_room_title'));
      return SizedBox(
        width: _statusColumnWidth,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_alt_rounded, size: 11, color: tokens.liveBadge),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textCaption.copyWith(
                  fontSize: AppFontSize.label,
                  color: tokens.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (replay) {
      // 真源 FollowReplayBadge:亮金 16% 底 + 55% 描边胶囊(web
      // `--follow-state-replay-accent`)。
      final accent = tokens.brandBright;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.16),
          borderRadius: AppRadius.allSm,
          border: Border.all(color: accent.withValues(alpha: 0.55)),
        ),
        child: Text(
          i18n('replay'),
          style: context.textCaption.copyWith(fontSize: 10, height: 1, color: accent, fontWeight: FontWeight.w600),
        ),
      );
    }
    return SizedBox(
      width: _statusColumnWidth,
      child: Text(
        i18n('offline_room_title'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textCaption.copyWith(fontSize: AppFontSize.label, color: tokens.textSecondary),
      ),
    );
  }
}
