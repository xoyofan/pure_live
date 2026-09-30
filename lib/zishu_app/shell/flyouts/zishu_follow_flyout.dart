import 'package:cached_network_image/cached_network_image.dart';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/cache_manager.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/platform_brands.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/shell/flyouts/zishu_flyout_panel.dart';

/// 「关注」hover 出的在播房间网格(移植 zishu 真源
/// `lib/src/app/shell/follow_avatars.dart` 的 `_FollowFlyout` 容器规格,
/// 单格改为 pure_live 口径的「头像优先封面图 + 主播名 + 人气」小卡,
/// 底色/hover 走平台品牌色两档,取图口径对齐真源 `_followAvatarSrc`)。
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
///
/// 每格底色与 hover 都取**平台品牌色**两档(对齐真源 `_FollowAvatarTile`):
/// 底为 0.16 透明度品牌色常态底,hover 加深到 0.3,让「哪个平台的主播」
/// 在网格里一眼可辨;未收录平台回退主文字色(真源同款兜底)。
class _FollowRoomCard extends StatelessWidget {
  const _FollowRoomCard({required this.room, required this.onTap});

  final LiveRoom room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final anchor = (room.nick ?? '').trim();
    final brandColor = PlatformBrandCatalog.byId(room.normalizedPlatformId)?.color ?? tokens.textPrimary;
    return Tooltip(
      message: '$anchor · ${room.title ?? ''}',
      // 常态底 0.16 必须铺进 Material 的 ink 层(Ink),否则会被 InkWell
      // 的叠色/水波纹画在上面遮掉(真源同款 Ink 结构)。
      child: Ink(
        color: brandColor.withValues(alpha: 0.16),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.allSm,
          hoverColor: brandColor.withValues(alpha: 0.3),
          // 焦点/按下也走本格语义色(品牌色),与 hover 同源,不用通用
          // accent(真源 _FollowAvatarTile 同口径);焦点保持 accent 光晕档。
          focusColor: AppStateLayer.focusOf(tokens.accent),
          splashColor: AppStateLayer.splashOf(brandColor),
          highlightColor: AppStateLayer.pressedOf(brandColor),
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
      ),
    );
  }

  /// 斗鱼过期截图 CDN(照抄真源 `follow_avatars.dart` 的 `_followAvatarSrc`
  /// 正则):`rpic.douyucdn.cn/asrpic…` 的截图会过期,不作小卡长期展示。
  static final RegExp _expiringDouyuCdn = RegExp(r'(?:^|\.)rpic\.douyucdn\.cn/(?:asrpic|a\d+/)', caseSensitive: false);

  /// 小卡取图:**头像优先、封面兜底**(真源 `_followAvatarSrc` 同口径,
  /// web `pickFollowAvatarSrc`);斗鱼的过期截图 CDN 两个值都排除;都拿
  /// 不到 → 空串,由调用方落「主播名首字」占位。
  static String _followCardImageSrc(LiveRoom room) {
    final isDouyu = room.normalizedPlatformId == 'douyu';
    final avatar = (room.avatar ?? '').trim();
    if (avatar.isNotEmpty) {
      if (isDouyu && _expiringDouyuCdn.hasMatch(avatar)) return '';
      return avatar;
    }
    final cover = (room.cover ?? '').trim();
    if (cover.isEmpty) return '';
    if (isDouyu && _expiringDouyuCdn.hasMatch(cover)) return '';
    return cover;
  }

  /// 小卡图:头像优先(圆角方图)、否则封面吃满剩余空间(约 16:9)。
  /// 两个值都过 normalizeNetworkImageUrl + networkImageHeaders(站点
  /// referer/UA 头,口径同 zishu 房间卡 `_Cover`)+ 共享缓存管理器,
  /// 空/加载失败回落「主播名首字」占位。充满父级给的剩余空间,不自带
  /// 宽高比约束。
  Widget _cover(BuildContext context) {
    final tokens = context.tokens;
    final imageUrl = normalizeNetworkImageUrl(_followCardImageSrc(room));
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
      child: imageUrl.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              httpHeaders: networkImageHeaders(imageUrl),
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
  /// `zishu_follow_room_list.dart` 的取值顺序同口径,追加热度兜底),
  /// 展示统一万进制:过 readableCount(空/非数字原样返回)。
  String _popularityLabel(LiveRoom room) {
    final online = (room.onlineViewers ?? '').trim();
    if (online.isNotEmpty) return readableCount(online);
    final popularity = (room.popularity ?? '').trim();
    if (popularity.isNotEmpty) return readableCount(popularity);
    return readableCount((room.watching ?? '').trim());
  }
}
