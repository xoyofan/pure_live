import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/areas/areas_list_controller.dart';
import 'package:pure_live/zishu/domain/category_display.dart';
import 'package:pure_live/zishu/domain/category_sections.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/shell/flyouts/zishu_flyout_panel.dart';

/// 平台 tab hover 出的分类浮层(移植 zishu 真源
/// `lib/src/app/shell/category_flyout.dart` 的 `_PlatformCategoryFlyout` +
/// `_CategoryBoard`,容器规格同 [ZishuFlyoutPanel])。
///
/// 数据源:pure_live `AreasListController.categories`(当前站点真实目录,
/// 分组 = [AppLiveCategory],条目 = [LiveArea]);分组进看板前统一走
/// [buildCategorySections](与侧栏热门分类区**共用**的一级分区构建,
/// 见 `lib/zishu/domain/category_sections.dart`:douyin/douyu/huya 过滤
/// 排序、空组滤除、不限条数);布局对齐真源 —— 多分组一组一列、单组
/// 平铺封顶 5 列,列内超高纵向滚动(列宽 67.2 = 4.2rem)。
/// 点分类条目由壳层注入的 [onOpenCategory] 跳分类详情(先收浮层)。
class ZishuPlatformCategoryFlyout extends StatelessWidget {
  const ZishuPlatformCategoryFlyout({
    super.key,
    required this.groups,
    required this.onEnter,
    required this.onExit,
    this.siteId = '',
    this.onOpenCategory,
    this.emptyHint,
  });

  /// 当前浮层挂的站点 id(壳层 hover 的平台 tab,如 `douyin`)——
  /// [buildCategorySections] 的归一 key;空串时归一退化为原样返回。
  final String siteId;

  // ---- 布局规格(对齐 zishu 真源 app_shell.dart 顶部常量) ----

  /// 浮层最小宽(12rem)。
  static const double minFlyoutWidth = 192;

  /// 浮层最大宽(56rem)。
  static const double maxFlyoutWidth = 896;

  /// 面板左右内边距(9.6×2)+ 左右各 1px 边框。
  static const double panelChrome = 9.6 * 2 + 2;

  /// 分类列宽 4.2rem ≈ 67.2px(同真源 `.nav-platform-menu__column`)。
  static const double columnWidth = 67.2;

  /// 单组平铺的列数上限(真源用户口径:twitch 的 hover 不要这么多列)。
  static const int flatMaxColumns = 5;

  /// 面板内容最大高度:_FlyoutPanel maxHeight(416)减面板上下 padding。
  static const double boardContentMax = 396;

  /// 面板宽度:列数与看板同源 —— 分组先过 [buildCategorySections]
  /// (与 [ZishuPlatformCategoryFlyout.siteId] 同一归一,滤空组后列数
  /// 才对得上),列数 = 实际 section 数(单组时按条目数封顶 5),宽度 =
  /// 列宽×列数 + 内边距,再夹到 `[12rem, 56rem]`(真源
  /// `_platformFlyoutLayoutFor` 的「列数 → 宽度」同源推导)。
  static double widthFor(List<AppLiveCategory> groups, {String siteId = ''}) {
    var maxColumns = ((maxFlyoutWidth - panelChrome) / columnWidth).floor();
    if (maxColumns < 1) maxColumns = 1;
    final sections = buildCategorySections(siteId, groups);
    var columns = 1;
    if (sections.length > 1) {
      columns = sections.length;
    } else if (sections.isNotEmpty) {
      columns = sections.first.items.length;
      if (columns > flatMaxColumns) columns = flatMaxColumns;
      if (columns < 1) columns = 1;
    }
    if (columns > maxColumns) columns = maxColumns;
    final width = panelChrome + columns * columnWidth;
    if (width < minFlyoutWidth) return minFlyoutWidth;
    if (width > maxFlyoutWidth) return maxFlyoutWidth;
    return width;
  }

  final List<AppLiveCategory> groups;
  final VoidCallback onEnter;
  final VoidCallback onExit;

  /// 点分类条目跳分类详情;为 null 时条目只展示不可点(站点对象缺失)。
  final void Function(LiveArea area)? onOpenCategory;

  /// 目录为空时的提示文案(壳层按加载中/失败/无数据传入);
  /// 缺省回退既有 key zishu_category_flyout_empty(原构造默认字面量
  /// 「暂无分类」已迁移,const 默认参数无法调用 i18n,故改为可空 + 回退)。
  final String? emptyHint;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onEnter(),
      onExit: (_) => onExit(),
      child: ZishuFlyoutPanel(
        child: _CategoryBoard(
          siteId: siteId,
          groups: groups,
          onOpenCategory: onOpenCategory,
          emptyHint: emptyHint ?? i18n('zishu_category_flyout_empty'),
        ),
      ),
    );
  }
}

/// 分类看板(真源 `_CategoryBoard` 同构):分组入口统一走
/// [buildCategorySections](与侧栏同源的一级分区构建),多分组横向
/// 一区一列(组标题 + 条目列),单大组平铺网格;列内容超高时列内
/// 纵向滚动。
class _CategoryBoard extends StatefulWidget {
  const _CategoryBoard({required this.siteId, required this.groups, this.onOpenCategory, required this.emptyHint});

  /// 归一 key,透传 [ZishuPlatformCategoryFlyout.siteId]。
  final String siteId;

  final List<AppLiveCategory> groups;
  final void Function(LiveArea area)? onOpenCategory;

  /// 目录为空时的提示文案(透传壳层判断:加载中/加载失败/无数据)。
  final String emptyHint;

  @override
  State<_CategoryBoard> createState() => _CategoryBoardState();
}

class _CategoryBoardState extends State<_CategoryBoard> {
  /// 每个纵向滚动视图独立 controller:Scrollbar(thumbVisibility) 在
  /// PrimaryScrollController 上多 ScrollPosition 会直接报错(真源实测注释)。
  final _scrollControllers = <int, ScrollController>{};

  ScrollController _controllerFor(int index) => _scrollControllers.putIfAbsent(index, () => ScrollController());

  @override
  void dispose() {
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 与侧栏同源的一级分区构建(过滤排序 + 空组滤除,不限条数):
    // sections 空即空目录,文案由壳层按 加载中(pageError=false)/
    // 失败(pageError=true) 传入。
    final sections = buildCategorySections(widget.siteId, widget.groups);
    if (sections.isEmpty) {
      return ZishuFlyoutHint(widget.emptyHint);
    }
    if (sections.length == 1) {
      // 单一大组(真源 isFlatCategoryGroups 口径:归一滤空后只剩一区):
      // 平铺网格,对齐 `.nav-platform-menu__hot-track`。
      return _buildFlat(context, sections.first);
    }
    return _buildColumns(context, sections);
  }

  /// 单大组:平铺网格(对齐真源 `.nav-platform-menu__hot-track`),限高内
  /// 纵向滚动 + 常驻滚动条。
  Widget _buildFlat(BuildContext context, ZishuCategorySection section) {
    final items = section.items;
    if (items.isEmpty) return ZishuFlyoutHint(widget.emptyHint);
    final controller = _controllerFor(0);
    return ZishuFlyoutScrollbar(
      controller: controller,
      child: SingleChildScrollView(
        controller: controller,
        child: Wrap(
          children: [
            for (final item in items)
              SizedBox(
                width: ZishuPlatformCategoryFlyout.columnWidth,
                child: _CategoryChip(area: item, onOpenCategory: widget.onOpenCategory),
              ),
          ],
        ),
      ),
    );
  }

  /// 多分组:横向分栏,一区一列(超出 maxColumns 时看板横向滚动)。
  Widget _buildColumns(BuildContext context, List<ZishuCategorySection> sections) {
    final tokens = context.tokens;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < sections.length; i++)
            Container(
              width: ZishuPlatformCategoryFlyout.columnWidth,
              padding: const EdgeInsets.only(left: 2.4),
              constraints: const BoxConstraints(maxHeight: ZishuPlatformCategoryFlyout.boardContentMax),
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: tokens.border)),
              ),
              child: _buildColumnBody(context, i, sections[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildColumnBody(BuildContext context, int index, ZishuCategorySection section) {
    final tokens = context.tokens;
    final controller = _controllerFor(index);
    return ZishuFlyoutScrollbar(
      controller: controller,
      child: SingleChildScrollView(
        controller: controller,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 3.8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: tokens.border)),
              ),
              child: Text(
                // 分组名统一走跨平台中文映射(已有中文名原样返回,海外平台归一)。
                displayCategoryGroupName(widget.siteId, section.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppFontSize.bodySecondary,
                  fontWeight: FontWeight.w700,
                  color: tokens.textSecondary,
                ),
              ),
            ),
            for (final item in section.items) _CategoryChip(area: item, onOpenCategory: widget.onOpenCategory),
          ],
        ),
      ),
    );
  }
}

/// 分类条目(真源 `_CategoryChip` 同构):hover 文字转 accent
/// (web `.nav-platform-menu__item:hover` 的「金底 + 金字」:金底走
/// InkWell hoverColor,金字走这里),点击跳分类详情。
class _CategoryChip extends StatefulWidget {
  const _CategoryChip({required this.area, this.onOpenCategory});

  final LiveArea area;
  final void Function(LiveArea area)? onOpenCategory;

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    // 条目名统一走跨平台中文映射:站点取条目自带 platform,areaId 当 cid
    // (soop 等按分类号反查中文名);空名/未命中映射时函数内原样兜底。
    final label = displayCategoryName(widget.area.platform, widget.area.areaName, widget.area.areaId);
    final onTap = widget.onOpenCategory == null ? null : () => widget.onOpenCategory!(widget.area);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: onTap,
        hoverColor: tokens.accent.withValues(alpha: AppDirectoryDrawer.activeChipAlpha),
        focusColor: AppStateLayer.focusOf(tokens.accent),
        splashColor: AppStateLayer.splashOf(tokens.accent),
        highlightColor: AppStateLayer.pressedOf(tokens.accent),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0.64, vertical: 1.28),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppFontSize.bodySecondary,
              color: _hovering ? tokens.accent : tokens.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
