import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/cache_manager.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/platform_brands.dart';
import 'package:pure_live/zishu/presentation/widgets/cover_badges.dart';
import 'package:pure_live/zishu/presentation/widgets/outline_chip.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

/// zishu 风格房间卡片(pure_live LiveRoom 适配版):16:9 封面 + 四角 tag
/// + 标题/特色 chips 两行元信息。几何与状态层逐项对齐 zishu
/// `features/browse/widgets/room_card.dart`(2026-09 改版裁决):
/// - 左上:分类实底角标([CoverCategoryBadge]);
/// - 左下:主播昵称(平台品牌色底 + chipForeground);
/// - 右下:热度([CoverOnlineBadge],未开播或值兜底链为空不显示;轮播态同位金色「轮播」);
/// - 未开播:整封面遮罩「未开播」;
/// - 平台名角标不渲染(位置让给昵称,平台信息由页签上下文承载)。
class ZishuRoomCard extends StatelessWidget {
  const ZishuRoomCard({super.key, required this.room, this.onTap});

  final LiveRoom room;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      key: Key('room-card-${room.platform}-${room.roomId}'),
      color: tokens.surface,
      borderRadius: AppRadius.allMd,
      child: InkWell(
        borderRadius: AppRadius.allMd,
        onTap: onTap ?? () => AppNavigator.toLiveRoomDetail(liveRoom: room),
        hoverColor: tokens.surfaceRaised,
        splashColor: AppStateLayer.splashOf(tokens.accent),
        highlightColor: AppStateLayer.pressedOf(tokens.accent),
        focusColor: AppStateLayer.focusOf(tokens.accent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Cover(room: room),
            _RoomCardMeta(room: room),
          ],
        ),
      ),
    );
  }
}

/// 元信息两行:标题 + 特色 chips 行(高度恒定,与 metaHeightFor 两行预算
/// 同源)。chips 来源:typeName(二级分区,R5 轨给 LiveRoom 增补的
/// `String? typeName`,可能为 null)非空 1 个 + area 非空且 ≠ typeName
/// 1 个;两个都空保留空占位行保证卡片等高。
class _RoomCardMeta extends StatelessWidget {
  const _RoomCardMeta({required this.room});

  final LiveRoom room;

  static const double _metaLineHeight = 17;

  @override
  Widget build(BuildContext context) {
    final title = (room.title ?? '').trim().isNotEmpty
        ? room.title!
        : ((room.nick ?? '').trim().isNotEmpty ? room.nick! : ' ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTitle.copyWith(fontSize: AppFontSize.subtitle),
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildChipsLine(),
        ],
      ),
    );
  }

  /// 特色 chips 行:字段 trim 后判空/去重;行高恒为 [_metaLineHeight]
  /// ([OutlineChip] 垂直 padding 恒 0,边框计入后 16.3px,守住该预算)。
  /// 不传 onTap = 纯展示 chip,点击自然落到卡片整体 onTap。
  Widget _buildChipsLine() {
    final typeName = (room.typeName ?? '').trim();
    final area = (room.area ?? '').trim();
    final labels = <String>[if (typeName.isNotEmpty) typeName, if (area.isNotEmpty && area != typeName) area];
    if (labels.isEmpty) return const SizedBox(height: _metaLineHeight);
    return SizedBox(
      height: _metaLineHeight,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            // Flexible 允许压缩:约束不足时 chip 内文字省略号截断,不溢出。
            Flexible(child: OutlineChip(label: labels[i])),
          ],
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.room});

  final LiveRoom room;

  @override
  Widget build(BuildContext context) {
    final replay = room.isRecord == true;
    final live = room.isLiveNow;
    final brand = PlatformBrandCatalog.byId(room.platform ?? '');
    final anchor = (room.nick ?? '').trim();
    // 热度展示值(onlineViewers → watching → popularity 兜底):统一走模型
    // audienceValue 兜底链(live_room.dart:677)—effectivePopularity →
    // effectiveTotalViewers → effectiveOnlineViewers → legacy watching。
    // preferRealOnline:false 表示不启用「真实在线」平台策略(纯展示,与
    // 排序口径解耦);该链会把遗留哨兵 '0' 与 'null' 判空,不会误渲染 0。
    final onlineText = room.audienceValue(preferRealOnline: false, platformEnabled: false);
    final coverUrl = normalizeNetworkImageUrl(room.cover);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: context.tokens.surfaceSoft,
            child: coverUrl.isEmpty
                ? _CoverPlaceholder(room: room)
                : CachedNetworkImage(
                    imageUrl: coverUrl,
                    fit: BoxFit.cover,
                    httpHeaders: networkImageHeaders(coverUrl),
                    cacheManager: CustomImageCacheManager.instance,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    useOldImageOnUrlChange: true,
                    placeholder: (_, _) => ColoredBox(color: context.tokens.surfaceRaised),
                    errorWidget: (_, _, _) => _CoverPlaceholder(room: room),
                  ),
          ),
          if (!live && !replay) const Positioned.fill(key: Key('room-card-offline'), child: CoverOfflineOverlay()),
          Positioned(
            left: 0,
            top: 0,
            child: CoverCategoryBadge(
              key: const Key('cover-badge-category'),
              corner: CoverCorner.topLeft,
              category: room.area ?? '',
              site: room.platform ?? '',
            ),
          ),
          if (anchor.isNotEmpty)
            Positioned(
              left: 0,
              bottom: 0,
              child: CoverBadge(
                key: const Key('cover-badge-anchor'),
                corner: CoverCorner.bottomLeft,
                background: brand?.color,
                foreground: brand?.chipForeground,
                child: Text(anchor, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          if (live && onlineText.isNotEmpty)
            Positioned(
              right: 0,
              bottom: 0,
              child: CoverOnlineBadge(
                key: const Key('cover-badge-online'),
                corner: CoverCorner.bottomRight,
                online: onlineText,
              ),
            ),
          if (replay)
            Positioned(
              right: 0,
              bottom: 0,
              child: CoverBadge(
                key: const Key('room-card-replay'),
                corner: CoverCorner.bottomRight,
                background: context.tokens.brandBright,
                child: Text(
                  i18n('replay'),
                  style: context.textCaption.copyWith(color: context.tokens.surfaceSoft, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.room});

  final LiveRoom room;

  @override
  Widget build(BuildContext context) {
    final category = room.area ?? '';
    return ColoredBox(
      color: context.tokens.surfaceRaised,
      child: Center(child: Text(category.isEmpty ? (room.platform ?? '') : category, style: context.textSecondary)),
    );
  }
}
