import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/utils/category_artwork.dart';
import 'package:pure_live/core/site/cc/cc_catalog.dart';
import 'package:pure_live/plugins/area_pic_mapper.dart';
import 'package:pure_live/plugins/cache_manager.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/cover_badges.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

/// zishu 分区封面格:断点定列([AppRoomGrid.columnsFor])、16/13.6 间距,
/// 方形封面 + 单行名称的等高 tile。几何逐项对齐 browse 目录的
/// `ZishuBrowseGrid`(LiveArea 签名不满足,故按约定在本目录写薄网格),
/// 卡片底色/圆角/状态层与 `ZishuRoomCard` 同口径。
class ZishuAreaGrid extends StatelessWidget {
  final List<LiveArea> areas;
  final ScrollController? scrollController;

  const ZishuAreaGrid({super.key, required this.areas, this.scrollController});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = AppRoomGrid.columnsFor(constraints.maxWidth);
        const crossSpacing = AppSpacing.gridCrossAxisSpacing;
        const mainSpacing = AppSpacing.gridMainAxisSpacing;
        final gridWidth = constraints.maxWidth - 2 * AppSpacing.lg;
        final cardWidth = (gridWidth - (columns - 1) * crossSpacing) / columns;
        // 方形封面(1:1)+ 单行名称;名称区预算 32px,大字体按
        // metaHeightFor 同步放大(同 ZishuBrowseGrid 的卡片等高契约)。
        final aspectRatio = cardWidth / (cardWidth + metaHeightFor(32, context));
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
                  (context, index) => ZishuAreaTile(
                    key: ValueKey('${areas[index].platform}:${areas[index].areaId}'),
                    area: areas[index],
                  ),
                  childCount: areas.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// zishu 风格分区 tile:方形封面(官方图,缺失回落 `AreaPicMapper`)+
/// 居中单行分区名。点击进入该分区的房间流(`toCategoryDetail`);
/// IPTV 分区即频道,直接合成房间打开(对齐 `AreaCard` 行为)。
class ZishuAreaTile extends StatelessWidget {
  final LiveArea area;

  const ZishuAreaTile({super.key, required this.area});

  void _open() {
    if (area.platform == Sites.iptvSite) {
      final channel = LiveRoom(
        roomId: area.areaId,
        title: area.typeName,
        cover: '',
        nick: area.areaName,
        watching: '',
        avatar: 'https://img95.699pic.com/xsj/0q/x6/7p.jpg%21/fw/700/watermark/url/L3hzai93YXRlcl9kZXRhaWwyLnBuZw/align/southeast',
        area: '',
        liveStatus: LiveStatus.live,
        status: true,
        platform: 'iptv',
      );
      AppNavigator.toLiveRoomDetail(liveRoom: channel);
      return;
    }
    AppNavigator.toCategoryDetail(site: Sites.of(area.platform!), category: area);
  }

  String _resolveCoverUrl() {
    final own = area.areaPic;
    if (own != null && own.isNotEmpty) return normalizeNetworkImageUrl(own);
    return normalizeNetworkImageUrl(AreaPicMapper.getPic(area.areaName));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final name = (area.areaName ?? '').trim().isEmpty ? i18n('unnamed_area') : area.areaName!.trim();
    final picUrl = _resolveCoverUrl();
    return Material(
      color: tokens.surface,
      borderRadius: AppRadius.allMd,
      child: InkWell(
        borderRadius: AppRadius.allMd,
        onTap: _open,
        hoverColor: tokens.surfaceRaised,
        splashColor: AppStateLayer.splashOf(tokens.accent),
        highlightColor: AppStateLayer.pressedOf(tokens.accent),
        focusColor: AppStateLayer.focusOf(tokens.accent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ColoredBox(
                    color: tokens.surfaceRaised,
                    child: picUrl.isEmpty
                        ? Center(child: Icon(Icons.live_tv_rounded, size: 28, color: tokens.textSecondary))
                        : CachedNetworkImage(
                            imageUrl: picUrl,
                            fit: BoxFit.cover,
                            alignment: categoryArtworkAlignment(picUrl),
                            httpHeaders: networkImageHeaders(picUrl),
                            cacheManager: CustomImageCacheManager.instance,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            useOldImageOnUrlChange: true,
                            placeholder: (_, _) => ColoredBox(color: tokens.surfaceRaised),
                            errorWidget: (_, _, _) => ColoredBox(color: tokens.surfaceRaised),
                          ),
                  ),
                ),
                // CC 官方入口提示:角标只做提示,导航仍走 toCategoryDetail
                // (对齐 AreaCard 的口径)。
                if (CCCatalog.isOfficialEntry(area))
                  Positioned(
                    top: 0,
                    right: 0,
                    child: CoverBadge(
                      corner: CoverCorner.topRight,
                      child: Icon(Icons.open_in_new_rounded, size: 12, color: tokens.coverScrimText),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.textBody.copyWith(fontSize: AppFontSize.bodySecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
