import 'package:pure_live/common/index.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/platform_brands.dart';
import 'package:pure_live/zishu/presentation/widgets/platform_icon.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

/// 窄屏(<768)顶部平台条:移植 zishu_flutter
/// `lib/src/app/shell/platform_strip.dart` 的 `_PlatformStrip` 两条方向分支:
///
/// - **竖屏**:`nav-platform-strip__item` 折行宫格 —— 每行 6 格、不滚动;
/// - **横屏**:高度稀缺,单行横向滚动(条高 52,同真源
///   `--nav-platform-strip-height: safe-top + 3.25rem`)。
///
/// 与真源的差异(pure_live 交付口径):每格 = 平台图标 + **平台名称**
/// (真源竖屏隐藏文字、仅 Tooltip,这里按任务口径渲染名称,因此不再挂
/// Tooltip —— 名称可见时 Tooltip 冗余,且避免它与新增的「长按弹分类面板」
/// 抢长按手势);点击格 = 切平台,长按格或点 ▼ = 打开该平台分类底部面板。
/// 平台数据用 pure_live `PopularController.sites`(不是 zishu 的
/// `PlatformBrandCatalog.navigationPlatforms`)。
class ZishuPhonePlatformStrip extends StatelessWidget {
  const ZishuPhonePlatformStrip({
    super.key,
    required this.sites,
    required this.currentSiteId,
    required this.onSelectSite,
    required this.onOpenCategories,
  });

  final List<Site> sites;
  final String? currentSiteId;
  final void Function(String siteId) onSelectSite;
  final void Function(String siteId) onOpenCategories;

  /// 竖屏宫格图标(真源 28 为纯图标格;加名称后收一档保行高)。
  static const double _kIconSize = 24;

  /// 横屏单行图标(真源 24,同样因带名称收一档)。
  static const double _kIconSizeLandscape = 20;

  /// 分类箭头列宽:竖屏 1.8rem ≈ 28.8px,横屏 1.7rem ≈ 27.2px(真源同值)。
  static const double _kArrowWidth = 28.8;
  static const double _kArrowWidthLandscape = 27.2;

  /// 宫格单行高度(图标 + 名称 + 上下内边距;真源 44 为纯图标格)。
  static const double _kRowHeight = 56;

  /// 横屏单行条高:web `--nav-platform-strip-height: safe-top + 3.25rem`。
  static const double _kStripHeight = 52;

  /// 竖屏每行平台数:web `flex: 1 1 15%` 在 375px 下的实际落位(真源同值)。
  static const int _kColumns = 6;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    // 形态按方向切换,与真源竖屏折行宫格 / 横屏单行横滚同构。
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final rows = (sites.length / _kColumns).ceil();
    return Container(
      padding: EdgeInsets.only(top: safeTop),
      decoration: BoxDecoration(
        color: context.tokens.surfaceSoft,
        border: Border(bottom: BorderSide(color: context.tokens.border)),
      ),
      child: isLandscape
          ? SizedBox(
              height: _kStripHeight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4.8),
                child: Row(
                  children: [
                    for (final site in sites)
                      _StripItem(
                        site: site,
                        selected: site.id == currentSiteId,
                        landscape: true,
                        onTap: () => onSelectSite(site.id),
                        onOpenCategories: () => onOpenCategories(site.id),
                      ),
                  ],
                ),
              ),
            )
          : SizedBox(
              // 行数随平台数增长(availableSites 可能超过 12),不写死两行,
              // 避免 3+ 行被 Expanded 压扁。
              height: rows * _kRowHeight,
              child: Column(
                children: [
                  for (int r = 0; r < rows; r++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            for (int c = 0; c < _kColumns; c++)
                              if (r * _kColumns + c < sites.length)
                                Expanded(
                                  child: _StripItem(
                                    site: sites[r * _kColumns + c],
                                    selected: sites[r * _kColumns + c].id == currentSiteId,
                                    onTap: () => onSelectSite(sites[r * _kColumns + c].id),
                                    onOpenCategories: () => onOpenCategories(sites[r * _kColumns + c].id),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// 平台条单格(真源 `.nav-platform-strip__item`):平台 tab + 右侧独立 ▼ 按钮。
///
/// ▼ 不是「跳分类页」的快捷方式,而是打开该平台的**分类底部面板**
/// (真源 `nav-cat-sheet` + `_PlatformCategorySheet`);手机没有 hover,
/// 分类只能在面板里选。长按平台 tab 走同一面板(任务口径新增,真源无)。
class _StripItem extends StatelessWidget {
  const _StripItem({
    required this.site,
    required this.selected,
    required this.onTap,
    required this.onOpenCategories,
    this.landscape = false,
  });

  final Site site;
  final bool selected;
  final bool landscape;
  final VoidCallback onTap;
  final VoidCallback onOpenCategories;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final iconSize = landscape ? ZishuPhonePlatformStrip._kIconSizeLandscape : ZishuPhonePlatformStrip._kIconSize;
    final arrowWidth = landscape ? ZishuPhonePlatformStrip._kArrowWidthLandscape : ZishuPhonePlatformStrip._kArrowWidth;
    final brandColor = PlatformBrandCatalog.byId(site.id)?.color ?? tokens.brand;
    final name = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(site.name, maxLines: 1, style: context.textCaption),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.6),
      child: DecoratedBox(
        // 真源:item 有 1px 边框 + 圆角,选中项边框转平台品牌色。
        decoration: BoxDecoration(
          border: Border.all(color: selected ? brandColor : tokens.border),
          borderRadius: AppRadius.allSm,
          color: selected ? brandColor.withValues(alpha: 0.12) : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InkWell(
                // 测试锚点:平台入口(真源契约,勿改)。
                key: Key('platform-tab-${site.id}'),
                onTap: onTap,
                onLongPress: onOpenCategories,
                hoverColor: tokens.surfaceRaised,
                focusColor: AppStateLayer.focusOf(tokens.accent),
                splashColor: AppStateLayer.splashOf(tokens.accent),
                highlightColor: AppStateLayer.pressedOf(tokens.accent),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.8, vertical: 5),
                  child: landscape
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PlatformIcon(id: site.id, size: iconSize),
                            const SizedBox(width: 2.4),
                            name,
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PlatformIcon(id: site.id, size: iconSize),
                            const SizedBox(height: 2),
                            name,
                          ],
                        ),
                ),
              ),
            ),
            Container(width: 1, height: iconSize + (landscape ? 0 : 14), color: tokens.border),
            // ▼ 打开该平台分类底部面板(锚点名沿用真源 `platform-strip-cat-{site}`)。
            InkWell(
              key: Key('platform-strip-cat-${site.id}'),
              onTap: onOpenCategories,
              onLongPress: onOpenCategories,
              hoverColor: tokens.surfaceRaised,
              focusColor: AppStateLayer.focusOf(tokens.accent),
              splashColor: AppStateLayer.splashOf(tokens.accent),
              highlightColor: AppStateLayer.pressedOf(tokens.accent),
              child: SizedBox(
                width: arrowWidth,
                height: iconSize + 12,
                child: Icon(Icons.keyboard_arrow_down_rounded, size: landscape ? 17 : 20, color: tokens.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
