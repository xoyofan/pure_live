import 'package:cached_network_image/cached_network_image.dart';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/cache_manager.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

/// 顶栏「关注」触发器的在播头像堆叠(移植 zishu 真源
/// `lib/src/app/shell/follow_avatars.dart` 的 `_NavFollowAvatars`,:34-82):
/// 23.68px 圆头像、相邻左移 32% 宽实现堆叠、上限 3 张;无在播回落星形图标
/// (真源空态分支,`textSecondary`)。
///
/// 数据 = `SettingsService.to.fav.favoriteRooms.v` 过滤 [LiveRoom.isLiveNow]
/// 取前 3(Obx 订阅,与壳层关注浮层 `_buildFlyouts` 的关注分支同一份口径);
/// 头像取图对齐 `zishu_follow_flyout.dart` 小卡:过
/// [normalizeNetworkImageUrl] + 站点 referer 头 + 共享缓存管理器,斗鱼过期
/// 截图 CDN(`rpic.douyucdn.cn/asrpic…`)avatar/cover 都排除(真源
/// `_followAvatarSrc` 同款正则:会过期,不作头像长期展示);两个值都拿不到
/// → 「主播名首字」占位。
///
/// 悬停/点击回调由外壳注入:悬停接壳层既有 follow flyout 态机
/// (`_openFollowFlyout(centerX)` / 延迟关门),点击进关注页。
class ZishuFollowAvatars extends StatelessWidget {
  const ZishuFollowAvatars({
    super.key,
    required this.onTap,
    required this.onHoverStart,
    required this.onHoverEnd,
    required this.tooltip,
  });

  /// 头像边长(zishu web `--nav-follow-avatar-size: 1.48rem` ≈ 23.68px)。
  static const double avatarSize = 23.68;

  /// 重叠比例(web `--nav-follow-avatar-overlap`):相邻头像左移 size×0.32。
  static const double overlapRatio = 0.32;

  /// 上限(web `NAV_FOLLOW_AVATAR_LIMIT`)。
  static const int limit = 3;

  /// 点击进关注页(壳层 `_navigateToMenu(HomeMenu.favorites.index)`)。
  final VoidCallback onTap;

  /// 悬停回传触发点中心 x(壳层 `_openFollowFlyout`)。
  final void Function(double centerX) onHoverStart;

  /// 移出触发区(壳层延迟关门 `_scheduleFlyoutClose`)。
  final VoidCallback onHoverEnd;

  /// 悬停提示文案(沿用顶栏原关注钮的 `favorites_title`)。
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (hoverContext) {
        // 触发点中心 x:MouseRegion 与点击区共用同一个 RenderBox 快照
        // (壳层 _TopNavTool / _PlatformTab 同款处理)。
        RenderBox? box;
        double centerX() {
          final target = box ??= hoverContext.findRenderObject() as RenderBox?;
          if (target == null) return 0;
          final dx = target.localToGlobal(Offset.zero).dx;
          return dx + target.size.width / 2;
        }

        return MouseRegion(
          onEnter: (_) => onHoverStart(centerX()),
          onExit: (_) => onHoverEnd(),
          child: Tooltip(
            message: tooltip,
            child: InkResponse(
              onTap: onTap,
              radius: 18,
              hoverColor: context.tokens.surfaceRaised,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                child: Obx(() {
                  final live = SettingsService.to.fav.favoriteRooms.v.where((room) => room.isLiveNow).toList();
                  return _stack(context, live);
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 在播头像堆叠;无在播回落星形图标(真源空态分支)。
  Widget _stack(BuildContext context, List<LiveRoom> live) {
    if (live.isEmpty) {
      return SizedBox(
        width: avatarSize,
        height: avatarSize,
        child: Icon(Icons.star_border_rounded, size: avatarSize * 0.76, color: context.tokens.textSecondary),
      );
    }
    final shown = live.take(limit).toList();
    final step = avatarSize * (1 - overlapRatio);
    final width = avatarSize + (shown.length - 1) * step;
    return SizedBox(
      width: width,
      height: avatarSize,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              // 左起第一个在最上层(web 用 zIndex: length - index 配
              // margin-left 负值,Stack 后画在上同效)。
              left: i * step,
              child: _FollowAvatarBadge(room: shown[i], size: avatarSize),
            ),
        ],
      ),
    );
  }
}

/// 关注头像取图(真源 `_followAvatarSrc` 同口径):avatar 优先、cover 兜底;
/// 斗鱼的过期截图 CDN(`rpic.douyucdn.cn/asrpic…`)两个值都排除 —— 会过期,
/// 不作头像长期展示。命中值再过 [normalizeNetworkImageUrl](协议相对链接补
/// scheme,非法值归空,由调用方落「主播名首字」占位)。
String _followAvatarSrc(LiveRoom room) {
  final expiring = RegExp(r'(?:^|\.)rpic\.douyucdn\.cn/(?:asrpic|a\d+/)', caseSensitive: false);
  final isDouyu = room.normalizedPlatformId == 'douyu';
  final avatar = room.avatar?.trim() ?? '';
  if (avatar.isNotEmpty) {
    if (isDouyu && expiring.hasMatch(avatar)) return '';
    return normalizeNetworkImageUrl(avatar);
  }
  final cover = room.cover?.trim() ?? '';
  if (cover.isEmpty) return '';
  if (isDouyu && expiring.hasMatch(cover)) return '';
  return normalizeNetworkImageUrl(cover);
}

/// 单个圆形头像:avatar/cover 图 + 首字兜底(真源 `_NavFollowAvatar` 同款,
/// 图源加载口径与 `zishu_follow_flyout.dart` 小卡一致)。
class _FollowAvatarBadge extends StatelessWidget {
  const _FollowAvatarBadge({required this.room, required this.size});

  final LiveRoom room;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final src = _followAvatarSrc(room);
    final anchor = room.nick?.trim() ?? '';
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tokens.surfaceRaised, shape: BoxShape.circle),
      child: Text(
        anchor.isEmpty ? '?' : anchor.substring(0, 1),
        style: TextStyle(
          // 几何比例:首字母随头像容器缩放,非排版字号档。
          fontSize: size * 0.5,
          color: tokens.textSecondary,
        ),
      ),
    );
    return Container(
      key: Key('nav-follow-avatar-${room.normalizedPlatformId}-${room.normalizedRoomId}'),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: tokens.surfaceSoft),
      ),
      child: src.isEmpty
          ? fallback
          : ClipOval(
              child: CachedNetworkImage(
                imageUrl: src,
                width: size,
                height: size,
                fit: BoxFit.cover,
                httpHeaders: networkImageHeaders(src),
                cacheManager: CustomImageCacheManager.instance,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                useOldImageOnUrlChange: true,
                placeholder: (_, _) => ColoredBox(color: tokens.surfaceRaised),
                errorWidget: (_, _, _) => fallback,
              ),
            ),
    );
  }
}
