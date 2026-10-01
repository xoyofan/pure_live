part of '../app_shell.dart';

/// 移动端平台条:对齐 SFVideoLive `NavPlatformStrip.vue` + `responsive-chrome.css`
/// 的两条方向分支(源码真源,不按截图目测):
///
/// - **竖屏**:`nav-platform-strip__item` 为 `flex: 1 1 15%` 折行宫格 ——
///   12 项平分两行、隐藏平台文字、图标 1.75rem、箭头列 1.8rem、不滚动;
/// - **横屏**:高度稀缺,`flex-wrap: nowrap` 改**单行横向滚动**,图标 1.5rem、
///   箭头列 1.7rem,条高 `--nav-platform-strip-height`(= safe-top + 3.25rem)。
///
/// 每格 = 品牌图标入口(锚点 `platform-tab-{site}`)+ 独立分类箭头,各自语义
/// 动作分离;平台清单来自 `PlatformBrandCatalog.navigationPlatforms`。
///
/// 箭头锚点有两套:`platform-strip-cat-{site}` 是新契约(打开分类面板),
/// 外层 `KeyedSubtree` 保留旧锚点 `platform-category-{site}` 供既有响应式
/// 用例继续断言存在性 —— 一个控件两个名字是刻意的过渡期兼容,勿删。
class _PlatformStrip extends StatelessWidget {
  const _PlatformStrip({required this.currentSite});

  final String currentSite;

  /// 竖屏宫格图标:1.75rem ≈ 28px(web `[data-platform=phone][portrait]`)。
  static const double _kIconSize = 28;

  /// 横屏单行图标:1.5rem ≈ 24px。
  static const double _kIconSizeLandscape = 24;

  /// 分类箭头列宽:竖屏 1.8rem ≈ 28.8px,横屏 1.7rem ≈ 27.2px。
  static const double _kArrowWidth = 28.8;
  static const double _kArrowWidthLandscape = 27.2;

  /// 宫格单行高度(图标 + 上下内边距)。
  static const double _kRowHeight = 44;

  /// 竖屏宫格内容高度(单行高 × 2 + 行距)。
  static const double _kGridHeight = _kRowHeight * 2 + 8;

  /// 横屏单行条高:web `--nav-platform-strip-height: safe-top + 3.25rem`。
  static const double _kStripHeight = 52;

  /// 竖屏每行平台数:12 项 → 6 × 2(web `flex: 1 1 15%` 在 375px 下的实际落位)。
  static const int _kColumns = 6;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    // 形态按方向切换,与 web 的 `[data-platform=phone][data-orientation]` 分支同源:
    // 竖屏折行宫格(标签隐藏、宽度平分),横屏 `flex-wrap: nowrap` 单行横向滚动
    // —— 横屏高度稀缺,单行才能把平台压进 52px。
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final platforms = PlatformBrandCatalog.navigationPlatforms;
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
                    for (final brand in platforms)
                      _StripItem(
                        brand: brand,
                        selected: brand.id == currentSite,
                        landscape: true,
                      ),
                  ],
                ),
              ),
            )
          : SizedBox(
              height: _kGridHeight,
              child: Column(
                children: [
                  for (
                    int r = 0;
                    r < (platforms.length / _kColumns).ceil();
                    r++
                  )
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            for (int c = 0; c < _kColumns; c++)
                              if (r * _kColumns + c < platforms.length)
                                Expanded(
                                  child: _StripItem(
                                    brand: platforms[r * _kColumns + c],
                                    selected:
                                        platforms[r * _kColumns + c].id ==
                                        currentSite,
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

/// 平台条单格(web `.nav-platform-strip__item`):左侧平台 tab + 右侧独立 ▼ 按钮。
///
/// ▼ 不是「跳分类页」的快捷方式,而是打开该平台的**分类底部面板**
/// (web `.nav-cat-sheet` + `NavPlatformCategoryMenu`):手机没有 hover,
/// 分类只能在面板里选。
class _StripItem extends StatelessWidget {
  const _StripItem({
    required this.brand,
    required this.selected,
    this.landscape = false,
  });

  final PlatformBrand brand;
  final bool selected;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final iconSize = landscape
        ? _PlatformStrip._kIconSizeLandscape
        : _PlatformStrip._kIconSize;
    final arrowWidth = landscape
        ? _PlatformStrip._kArrowWidthLandscape
        : _PlatformStrip._kArrowWidth;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.6),
      child: DecoratedBox(
        // web:item 有 1px 边框 + 圆角,选中项边框转品牌色。
        decoration: BoxDecoration(
          border: Border.all(color: selected ? brand.color : tokens.border),
          borderRadius: AppRadius.allSm,
          color: selected
              ? brand.color.withValues(alpha: 0.12)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Tooltip(
                message: brand.name,
                child: InkWell(
                  // 测试锚点:平台入口(既有契约,勿改)。
                  key: Key('platform-tab-${brand.id}'),
                  onTap: () => context.go(_platformRoute(brand.id)),
                  hoverColor: tokens.surfaceRaised,
                  focusColor: AppStateLayer.focusOf(tokens.accent),
                  splashColor: AppStateLayer.splashOf(context.tokens.accent),
                  highlightColor: AppStateLayer.pressedOf(
                    context.tokens.accent,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4.8,
                      vertical: 6,
                    ),
                    child: PlatformIcon(id: brand.id, size: iconSize),
                  ),
                ),
              ),
            ),
            Container(width: 1, height: iconSize, color: tokens.border),
            // 旧锚点 `platform-category-{id}`:既有响应式用例仍按它断言入口
            // 可达,故用 KeyedSubtree 继续提供(点击落到下面的 InkWell)。
            KeyedSubtree(
              key: Key('platform-category-${brand.id}'),
              child: Tooltip(
                message: '${brand.name}分类',
                child: InkWell(
                  // 测试锚点:▼ 打开该平台分类面板。
                  key: Key('platform-strip-cat-${brand.id}'),
                  onTap: () => _openCategorySheet(context, brand.id),
                  hoverColor: tokens.surfaceRaised,
                  focusColor: AppStateLayer.focusOf(tokens.accent),
                  splashColor: AppStateLayer.splashOf(context.tokens.accent),
                  highlightColor: AppStateLayer.pressedOf(
                    context.tokens.accent,
                  ),
                  child: SizedBox(
                    width: arrowWidth,
                    height: iconSize + 12,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: landscape ? 17 : 20,
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 打开平台分类底部面板(web `nav-cat-sheet`:Teleport 到 body 的底部抽屉)。
Future<void> _openCategorySheet(BuildContext context, String site) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _PlatformCategorySheet(site: site),
  );
}

/// 桌面顶栏平台 tab:固定「全平台」入口 + 用户可见的 pure_live 各站
/// (设置对话框「平台」分区可隐藏/排序,经 [visiblePlatformsProvider] 同步;
/// 顶栏/侧栏/路由守卫共用同一份列表)。站点图标改用 pure_live 素材
/// ([PlatformEntry.logo],`assets/images/*.png`):既有 platform-icons 目录
/// 只覆盖 9 站,全量目录下其余站不再落文字字形兜底。
class _PlatformTabs extends ConsumerWidget {
  const _PlatformTabs({
    required this.currentSite,
    required this.onHover,
    required this.onHoverEnd,
  });

  final String currentSite;

  /// hover 平台 tab → `(平台 id, 触发点中心 x)`;移出触发 800ms 后关闭。
  final void Function(String id, double centerX) onHover;
  final VoidCallback onHoverEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platforms = ref.watch(visiblePlatformsProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PlatformTab(
            entry: const PlatformEntry(id: 'all', name: '全平台', logo: ''),
            selected: currentSite == 'all',
            onHover: onHover,
            onHoverEnd: onHoverEnd,
          ),
          for (final entry in platforms)
            _PlatformTab(
              entry: entry,
              selected: currentSite == entry.id,
              onHover: onHover,
              onHoverEnd: onHoverEnd,
            ),
        ],
      ),
    );
  }
}

/// 顶栏单个平台 tab(34px 点击盒 + 28px 站点 logo,品牌色描边选中态)。
class _PlatformTab extends StatelessWidget {
  const _PlatformTab({
    required this.entry,
    required this.selected,
    required this.onHover,
    required this.onHoverEnd,
  });

  final PlatformEntry entry;
  final bool selected;

  /// hover 平台 tab → `(平台 id, 触发点中心 x)`;移出触发 800ms 后关闭。
  final void Function(String id, double centerX) onHover;
  final VoidCallback onHoverEnd;

  /// 选中态描边/光晕的品牌色:色表未收录的站退 accent。
  Color _brandColor(ZishuTokens tokens) =>
      PlatformBrandCatalog.byId(entry.id)?.color ?? tokens.accent;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Builder(
        builder: (hoverContext) {
          // 触发点中心 x:与 _NavAction 同法,RenderBox 快照按需取。
          RenderBox? box;
          double centerX() {
            final target =
                box ??= hoverContext.findRenderObject() as RenderBox?;
            if (target == null) return 0;
            final dx = target.localToGlobal(Offset.zero).dx;
            return dx + target.size.width / 2;
          }

          return MouseRegion(
            onEnter: (_) => onHover(entry.id, centerX()),
            onExit: (_) => onHoverEnd(),
            child: Tooltip(
              message: entry.name,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: Key('platform-tab-${entry.id}'),
                  borderRadius: AppRadius.allSm,
                  hoverColor: tokens.surfaceSoft,
                  focusColor: AppStateLayer.focusOf(tokens.accent),
                  splashColor: AppStateLayer.splashOf(tokens.accent),
                  highlightColor: AppStateLayer.pressedOf(tokens.accent),
                  onTap: () => context.go(_platformRoute(entry.id)),
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    curve: AppMotion.curve,
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? tokens.surfaceRaised
                          : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? _brandColor(tokens)
                            : Colors.transparent,
                      ),
                      borderRadius: AppRadius.allSm,
                      boxShadow: selected
                          ? AppElevation.accentGlow(_brandColor(tokens))
                          : null,
                    ),
                    child: _PlatformTabLogo(entry: entry, size: 28),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 站点 logo:直接读 pure_live 素材;素材缺失时退既有 [PlatformIcon]
/// (全平台四象限 / 品牌色字形),顶栏/侧栏/设置行共用同一兜底口径。
class _PlatformTabLogo extends StatelessWidget {
  const _PlatformTabLogo({required this.entry, required this.size});

  final PlatformEntry entry;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (entry.id == 'all') return PlatformIcon(id: 'all', size: size);
    return Image.asset(
      entry.logo,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => PlatformIcon(id: entry.id, size: size),
    );
  }
}
