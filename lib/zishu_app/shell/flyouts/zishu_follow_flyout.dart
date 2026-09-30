import 'package:cached_network_image/cached_network_image.dart';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/cache_manager.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/shell/flyouts/zishu_flyout_panel.dart';

/// 「关注」hover 出的在播房间网格(移植 zishu 真源
/// `lib/src/app/shell/follow_avatars.dart` 的 `_FollowFlyout` 容器规格,
/// 单格改为 pure_live 口径的「封面 + 主播名 + 人气」小卡)。
///
/// 数据由壳层传入:`SettingsService.to.fav.favoriteRooms.v` 过滤
/// [LiveRoom.isLiveNow] 的在播收藏;列数按实际在播数收敛(≤7 列,与面板
/// 宽度同源);点小卡由壳层先收浮层再 `AppNavigator.toLiveRoomDetail`。
class ZishuFollowFlyout extends StatelessWidget {
  const ZishuFollowFlyout({
    super.key,
    required this.columns,
    required this.rooms,
    required this.onEnter,
    required this.onExit,
    required this.onOpenRoom,
  });

  // ---- 布局规格(容器对齐真源 `_followFlyoutLayoutFor` 的推导方式) ----

  /// 单元格宽:16:9 封面 + 名字 + 人气的可读下限。
  static const double slotWidth = 120;

  /// 单元格高:封面(120×9/16 ≈ 67.5)+ 名字行 + 人气行 + 纵向 padding。
  static const double slotHeight = 108;

  /// 列间距。
  static const double columnGap = 8;

  /// 行间距。
  static const double rowGap = 4;

  /// 面板内边距(对齐真源 `_FollowFlyout` 的 3.52 系)+ 边框 2px。
  static const double panelChrome = 3.52 * 2 + 2;

  /// 列数上限(真源:固定 7 列,web `.follow-hover-avatar-grid`)。
  static const int maxColumns = 7;

  /// 面板最大高:约 3 行可见,超出滚动(真源同为 maxHeight 约束 + 内滚)。
  static const double panelMaxHeight = 356;

  /// 列数 = 实际在播数(≤7),宽度随列数收缩并夹到 `[12rem, 56rem]` ——
  /// 条目少时不留空列(真源 `_followFlyoutLayoutFor` 同口径)。
  static ({int columns, double width}) layoutFor(int liveCount) {
    var columns = liveCount;
    if (columns < 1) columns = 1;
    if (columns > maxColumns) columns = maxColumns;
    var width = panelChrome + columns * slotWidth + (columns - 1) * columnGap;
    if (width < 192) width = 192;
    if (width > 896) width = 896;
    return (columns: columns, width: width);
  }

  /// 实际列数(壳层按在播数算好传入,与面板宽度同源)。
  final int columns;
  final List<LiveRoom> rooms;
  final VoidCallback onEnter;
  final VoidCallback onExit;

  /// 点小卡进播放页:由壳层提供(负责先收起浮层再导航)。
  final void Function(LiveRoom room) onOpenRoom;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onEnter(),
      onExit: (_) => onExit(),
      child: ZishuFlyoutPanel(
        padding: const EdgeInsets.fromLTRB(3.52, 4.16, 3.52, 3.52),
        maxHeight: panelMaxHeight,
        child: rooms.isEmpty
            ? ZishuFlyoutHint(i18n('empty_favorite_online_title'))
            : GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: rooms.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: slotHeight,
                  mainAxisSpacing: rowGap,
                  crossAxisSpacing: columnGap,
                ),
                itemBuilder: (context, index) =>
                    _FollowRoomCard(room: rooms[index], onTap: () => onOpenRoom(rooms[index])),
              ),
      ),
    );
  }
}

/// 关注浮层小卡:16:9 封面 + 主播名 + 人气,点击进入播放页。
class _FollowRoomCard extends StatelessWidget {
  const _FollowRoomCard({required this.room, required this.onTap});

  final LiveRoom room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final anchor = (room.nick ?? '').trim();
    return Tooltip(
      message: '$anchor · ${room.title ?? ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allSm,
        hoverColor: tokens.surfaceRaised,
        focusColor: AppStateLayer.focusOf(tokens.accent),
        splashColor: AppStateLayer.splashOf(tokens.accent),
        highlightColor: AppStateLayer.pressedOf(tokens.accent),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 封面吃满剩余高度(格高 108 固定,文字随系统字号缩放时由
              // 封面让位,避免大字号下纵向溢出)。
              Expanded(child: _cover(context)),
              const SizedBox(height: 3),
              Text(
                anchor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textCaption.copyWith(color: tokens.textPrimary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 1),
              Text(
                _popularityLabel(room),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textCaption.copyWith(color: tokens.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 封面(口径同 zishu 房间卡 `_Cover`:normalize + 站点 referer 头 +
  /// 共享缓存管理器),空/加载失败回落「主播名首字」占位。充满父级给的
  /// 剩余空间(约 16:9),不自带宽高比约束。
  Widget _cover(BuildContext context) {
    final tokens = context.tokens;
    final coverUrl = normalizeNetworkImageUrl(room.cover);
    final anchor = (room.nick ?? '').trim();
    final fallback = ColoredBox(
      color: tokens.surfaceRaised,
      child: Center(
        child: Text(
          anchor.isEmpty ? '?' : anchor.substring(0, 1),
          style: TextStyle(fontSize: AppFontSize.subtitle, color: tokens.textSecondary),
        ),
      ),
    );
    return ClipRRect(
      borderRadius: AppRadius.allSm,
      child: coverUrl.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: coverUrl,
              fit: BoxFit.cover,
              httpHeaders: networkImageHeaders(coverUrl),
              cacheManager: CustomImageCacheManager.instance,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              useOldImageOnUrlChange: true,
              placeholder: (_, _) => ColoredBox(color: tokens.surfaceRaised),
              errorWidget: (_, _, _) => fallback,
            ),
    );
  }

  /// 人气文案:并发在线 → 平台热度 → legacy watching(与关注列表状态列
  /// `zishu_follow_room_list.dart` 的取值顺序同口径,追加热度兜底)。
  String _popularityLabel(LiveRoom room) {
    final online = (room.onlineViewers ?? '').trim();
    if (online.isNotEmpty) return online;
    final popularity = (room.popularity ?? '').trim();
    if (popularity.isNotEmpty) return popularity;
    return (room.watching ?? '').trim();
  }
}
