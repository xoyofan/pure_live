import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/areas/areas_list_controller.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/zishu/domain/category_display.dart';
import 'package:pure_live/zishu/domain/cross_categories_data_models.dart';
import 'package:pure_live/zishu/domain/cross_categories_data.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/platform_brands.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/play/my_category_controller.dart';
import 'package:pure_live/zishu_app/shell/flyouts/zishu_flyout_panel.dart';
import 'package:pure_live/zishu_app/shell/zishu_shell_top_bar.dart';

// 「我的分类」飞出面板(移植 zishu 真源
// `lib/src/app/shell/my_category_flyout.dart` 的 `_MyCategoryFlyout`,
// 对齐 SFVideoLive `NavMyCategoryMenu.vue`):右上角「管理分类」入口 +
// 收藏 chip 折行区(max-height 11rem≈176px),空集合显示「暂无收藏分类」。
//
// 数据层按 pure_live 落地:chips = MyCategoryController.categories
// (GetX RxList,UI 侧 `Obx` 直读,替代真源 Riverpod
// ref.watch(myCategoriesProvider))。chip 点击**恒跳跨平台分类页**
// (真源 2ba199d 口径,对齐 web `NavMyCategoryMenu` 的 all-category-rooms):
// 按跨平台 key(crossKeyForPlatformCategory,soop 韩文名经静态表桥接)
// 打开 kZishuCrossCategory 聚合页;平台私有分类(未命中映射表)才退回
// 收藏时刻平台的原生分类页(resolveMyCategoryArea 按名称匹配
// `AreasListController(tag=entry.site)` 目录,命中 onOpenCategory 注入或
// AppNavigator.toCategoryDetail,未命中 toast 提示)。管理 =
// ZishuMyCategoryManageDialog:已收藏列表移除 + 目录点选收藏
// (目录默认「全平台」跨平台映射,顶部站点 chips 可切各可见平台原生目录)。
//
// 复用口径:
// - ZishuMyCategoryFlyout:296px 飞出面板本尊(ZishuFlyoutPanel 容器,
//   供 hover 浮层挂载,规格同真源 `_HoverOverlay(width: 296)`);
// - ZishuMyCategoryPanel:面板内容(管理入口 + chips),窄屏底栏弹层
//   showZishuMyCategorySheet 与宽屏侧栏「我的分类」内嵌展开共用;
// - ZishuMyCategoryChips:纯 chips 折行区。

/// 我的分类飞出面板宽度:对齐 web `.nav-my-cat-flyout
/// { width: min(92vw, 18.5rem) }` —— 18.5rem @16px ≈ 296px(真源
/// `app_shell.dart` 的 `_kMyCategoryFlyoutWidth`)。
const double kZishuMyCategoryFlyoutWidth = 296;

/// chips 区最大高度:11rem @16px ≈ 176px(同真源 `.nav-my-cat-menu__tags`)。
const double kZishuMyCategoryTagsMaxHeight = 176;

/// 收藏条目 → 收藏时刻平台的原生分区条目:遍历
/// `AreasListController(tag=entry.site).categories` 全部子分类,按
/// `areaName` 精确匹配(收藏快照存的就是平台原生名,与目录同源)。控制器
/// 未注册(该平台分区页从未打开)或目录未命中时返回 null,由调用方 toast。
LiveArea? resolveMyCategoryArea(MyCategoryEntry entry) {
  final site = entry.site.trim();
  final name = entry.name.trim();
  if (site.isEmpty || name.isEmpty) return null;
  if (!Get.isRegistered<AreasListController>(tag: site)) return null;
  final categories = Get.find<AreasListController>(tag: site).categories;
  for (final category in categories) {
    for (final child in category.children) {
      if ((child.areaName ?? '').trim() == name) return child;
    }
  }
  return null;
}

/// 296px 飞出面板:[ZishuFlyoutPanel] 容器(padding 覆写为真源
/// `_MyCategoryFlyout` 给 `_FlyoutPanel` 的 fromLTRB(6.4, 5.6, 6.4, 6.4))
/// + [ZishuMyCategoryPanel] 内容。挂 [ZishuHoverOverlay] 使用时传入
/// [onEnter]/[onExit] 桥接 hover 延迟关门,以及 [onClose](跳转/开管理弹窗
/// 前收起浮层)。
class ZishuMyCategoryFlyout extends StatelessWidget {
  const ZishuMyCategoryFlyout({super.key, this.onEnter, this.onExit, this.onClose});

  final VoidCallback? onEnter;
  final VoidCallback? onExit;

  /// 立即收起宿主浮层(跳转/开管理弹窗前调用,同真源 `onClose`)。
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final panel = ZishuFlyoutPanel(
      padding: const EdgeInsets.fromLTRB(6.4, 5.6, 6.4, 6.4),
      child: ZishuMyCategoryPanel(onClose: onClose),
    );
    if (onEnter == null && onExit == null) return panel;
    return MouseRegion(onEnter: (_) => onEnter?.call(), onExit: (_) => onExit?.call(), child: panel);
  }
}

/// 面板内容(管理入口行 + chips 折行区),容器由调用方决定:飞出面板
/// [ZishuMyCategoryFlyout] / 窄屏底栏弹层 [showZishuMyCategorySheet] /
/// 宽屏侧栏内嵌展开(「我的分类」行下方)。
class ZishuMyCategoryPanel extends StatelessWidget {
  const ZishuMyCategoryPanel({super.key, this.onClose, this.onOpenCategory});

  /// chip 跳转 / 开管理弹窗前收起宿主(浮层 pop、底栏弹层 pop);侧栏内嵌
  /// 展开等无宿主可收时留空。
  final VoidCallback? onClose;

  /// 注入的分类跳转(宽屏外壳把自身 selectAreaCategory 传进来:收藏 chip
  /// 直接入外壳内嵌分类详情);为 null 时维持既有路由跳转(窄屏外壳,
  /// 见 zishu_phone_shell)。
  final void Function(Site site, LiveArea area)? onOpenCategory;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            height: 22,
            child: TextButton(
              onPressed: () {
                onClose?.call();
                unawaited(showZishuMyCategoryManageDialog(context));
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: context.tokens.accent,
                textStyle: const TextStyle(fontSize: AppFontSize.bodySecondary),
              ),
              child: Text(i18n('my_category_manage')),
            ),
          ),
        ),
        ZishuMyCategoryChips(
          maxHeight: kZishuMyCategoryTagsMaxHeight,
          onClose: onClose,
          onOpenCategory: onOpenCategory,
        ),
      ],
    );
  }
}

/// 收藏 chip 折行区:`Obx` 订阅 [MyCategoryController.categories],空集合
/// 提示「暂无收藏分类」。chip 点击恒跳跨平台分类页(命中跨平台映射经
/// [crossKeyForPlatformCategory] 取 key 进 [RoutePath.kZishuCrossCategory]
/// 聚合页);平台私有分类退回 [resolveMyCategoryArea] 按名称匹配该平台
/// 目录,命中先 [onClose] 收起宿主再进分类详情([onOpenCategory] 注入时
/// 走外壳内嵌详情,否则旧路由);未命中 toast 并保留面板(用户可直接
/// 改选其他分类)。
class ZishuMyCategoryChips extends StatelessWidget {
  const ZishuMyCategoryChips({
    super.key,
    this.maxHeight = kZishuMyCategoryTagsMaxHeight,
    this.onClose,
    this.onOpenCategory,
  });

  final double maxHeight;
  final VoidCallback? onClose;

  /// 注入的分类跳转(宽屏外壳内嵌详情;null = 旧路由跳转)。
  final void Function(Site site, LiveArea area)? onOpenCategory;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final entries = [
        for (final entry in MyCategoryController.to.categories)
          if (entry.isValid) entry,
      ];
      if (entries.isEmpty) {
        return ZishuFlyoutHint(i18n('my_category_empty'));
      }
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 5.12,
            runSpacing: 4.48,
            children: [
              for (final entry in entries) _MyCategoryChip(entry: entry, onTap: () => _openEntryCategory(entry)),
            ],
          ),
        ),
      );
    });
  }

  void _openEntryCategory(MyCategoryEntry entry) {
    // 对齐真源 2ba199d:收藏 chip 恒跳跨平台分类页(web `all-category-rooms`
    // 同口径),按跨平台 key 打开 kZishuCrossCategory 聚合页;平台私有分类
    // (未命中映射表)才退回收藏时平台的原生分类页。
    final key = crossKeyForPlatformCategory(entry.site, '', entry.name);
    if (key.isNotEmpty) {
      onClose?.call();
      unawaited(Get.toNamed(RoutePath.kZishuCrossCategory, arguments: key));
      return;
    }
    final area = resolveMyCategoryArea(entry);
    if (area == null) {
      ToastUtil.show(i18n('go_category_failed'));
      return;
    }
    onClose?.call();
    final open = onOpenCategory;
    if (open != null) {
      // 宽屏外壳:直接进外壳内嵌分类详情(CC 官方入口由外壳回落外链)。
      open(Sites.of(entry.site), area);
      return;
    }
    unawaited(AppNavigator.toCategoryDetail(site: Sites.of(entry.site), category: area));
  }
}

/// 收藏 chip:对齐真源 `.nav-my-cat-menu__tag`(描边 pill,hover 转金色)。
class _MyCategoryChip extends StatefulWidget {
  const _MyCategoryChip({required this.entry, required this.onTap});

  final MyCategoryEntry entry;
  final VoidCallback onTap;

  @override
  State<_MyCategoryChip> createState() => _MyCategoryChipState();
}

class _MyCategoryChipState extends State<_MyCategoryChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final gold = _hovering;
    // 底色/描边铺进 ink 层(`Ink`),InkWell 的 hover/按下叠色才能画在它之上;
    // `_hovering` 只负责描边与星形/文字转品牌色(真源同款注释:web
    // `.nav-my-cat-menu__tag:hover` 的「金描边 + 金字」,hover 底色由
    // InkWell 的 hoverColor 承担)。
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Ink(
        decoration: BoxDecoration(
          color: context.tokens.surfaceSoft,
          border: Border.all(color: gold ? context.tokens.brand.withValues(alpha: 0.55) : context.tokens.border),
          borderRadius: AppRadius.allPill,
        ),
        child: InkWell(
          borderRadius: AppRadius.allPill,
          onTap: widget.onTap,
          hoverColor: context.tokens.brand.withValues(alpha: 0.1),
          focusColor: AppStateLayer.focusOf(context.tokens.accent),
          splashColor: AppStateLayer.splashOf(context.tokens.brandBright),
          highlightColor: AppStateLayer.pressedOf(context.tokens.brandBright),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9.6, vertical: 4.8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 12,
                  color: gold ? context.tokens.brandBright : context.tokens.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  // 旧快照可能存的是英文/韩文原名:渲染时再映射一次中文名,
                  // 不重写存储(与真源展示层归一同口径)。
                  displayCategoryName(widget.entry.site, widget.entry.name),
                  style: TextStyle(
                    fontSize: AppFontSize.subtitle,
                    fontWeight: FontWeight.w500,
                    color: gold ? context.tokens.brandBright : context.tokens.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 打开「我的分类」管理弹窗(flyout 面板「管理分类」入口 / 窄屏底栏共用)。
Future<void> showZishuMyCategoryManageDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (_) => const ZishuMyCategoryManageDialog());
}

/// 我的分类管理弹窗:已收藏列表(叉号移除)+ 目录点选收藏。目录默认
/// 「全平台」—— 跨平台映射目录([kCrossCategories],条目 name 为 canonical
/// 中文名、跨平台 key 即收藏 key),对齐真源 2ba199d:打开即
/// `activeSite = "all"`(web `MyCategoryManageSheet` 同口径),顶部站点
/// chips 可切各可见平台原生目录。收藏/取消与选中态走**跨平台口径**
/// ([MyCategoryController.toggle] / [isFavorited] 内建:命中同跨平台 key
/// 的任一平台收藏一并命中),上限 [MyCategoryController.maxCount],超限
/// toast 提示(既有 key `my_category_limit`)。
class ZishuMyCategoryManageDialog extends StatefulWidget {
  const ZishuMyCategoryManageDialog({super.key});

  @override
  State<ZishuMyCategoryManageDialog> createState() => _ZishuMyCategoryManageDialogState();
}

class _ZishuMyCategoryManageDialogState extends State<ZishuMyCategoryManageDialog> {
  /// 目录当前站点:默认全平台(跨平台映射),与 web 管理抽屉一致。
  String _pickSite = 'all';

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AlertDialog(
      backgroundColor: tokens.surface,
      title: Obx(() {
        return Text(
          '${i18n('my_category_title')}(${MyCategoryController.to.categories.length}/${MyCategoryController.maxCount})',
          style: TextStyle(fontSize: AppFontSize.subtitle, color: tokens.textPrimary),
        );
      }),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 已收藏区(真源同款:非空才占位)。
            Obx(() {
              final entries = [
                for (final entry in MyCategoryController.to.categories)
                  if (entry.isValid) entry,
              ];
              if (entries.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final entry in entries)
                      _RemovableChip(
                        label: displayCategoryName(entry.site, entry.name),
                        onRemove: () => MyCategoryController.to.toggle(entry.site, entry.name),
                      ),
                  ],
                ),
              );
            }),
            // 目录站点切换 chips:全平台(跨平台映射)+ 各可见平台
            // (savedPlatformIds 口径,与跨平台分类页聚合范围同源),对齐
            // 真源 PlatformTabs(web `MyCategoryManageSheet`)。
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _SiteTabChip(
                  label: PlatformBrandCatalog.all.name,
                  selected: _pickSite == 'all',
                  onTap: () => setState(() => _pickSite = 'all'),
                ),
                for (final site in visibleTopBarSites())
                  _SiteTabChip(
                    label: site.name,
                    selected: _pickSite == site.id,
                    onTap: () => setState(() => _pickSite = site.id),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(child: _CatalogSection(pickSite: _pickSite)),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n('done')))],
    );
  }
}

/// 目录点选区:[pickSite] 为 `all` 时铺跨平台映射表(全量 canonical 中文名
/// chips);为具体平台时铺该站目录分组(`AreasListController(tag)` 分组
/// 标题 + 子分类 chips,懒加载口径与侧栏热门分类同款:已注册且目录为空
/// 才 postFrame 补 `loadData()`,幂等)。收藏/取消走跨平台口径:快照存
/// 中文展示名([displayCategoryName],soop 韩文名经静态表桥接,与 chip
/// 渲染同源),选中态按 [_CatalogSectionState._favoriteMatchKeys]
/// ([MyCategoryController.isFavorited] 同语义)跨平台 key 一并命中。
class _CatalogSection extends StatefulWidget {
  const _CatalogSection({required this.pickSite});

  final String pickSite;

  @override
  State<_CatalogSection> createState() => _CatalogSectionState();
}

class _CatalogSectionState extends State<_CatalogSection> {
  /// 全平台目录 chips 的 (跨平台 key → 条目) 预解析表:映射表是静态常量,
  /// key 归一只算一次(逐 build × 逐 chip 重扫 329 条映射表不可接受)。
  Map<String, CrossCategoryEntry>? _crossEntriesByKey;

  @override
  void initState() {
    super.initState();
    _ensureCatalogLoaded();
  }

  @override
  void didUpdateWidget(covariant _CatalogSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pickSite != widget.pickSite) {
      _ensureCatalogLoaded();
    }
  }

  /// 平台目录为空且控制器已注册 → 一帧后补跑 loadData(不在 build 期间
  /// 触发 Rx 通知;loadData 幂等,进行中复用同一 Future,已有数据不重拉)。
  void _ensureCatalogLoaded() {
    final siteId = widget.pickSite;
    if (siteId == 'all') return;
    if (!Get.isRegistered<AreasListController>(tag: siteId)) return;
    final controller = Get.find<AreasListController>(tag: siteId);
    if (controller.categories.isNotEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!Get.isRegistered<AreasListController>(tag: siteId)) return;
      final latest = Get.find<AreasListController>(tag: siteId);
      if (latest.categories.isEmpty) unawaited(latest.loadData());
    });
  }

  /// 收藏/取消目录条目;超限新增 toast 提示(文案对齐真源上限口径)。
  Future<void> _toggleCatalogCategory(String siteId, String displayName) async {
    final ok = await MyCategoryController.to.toggle(siteId, displayName);
    if (!ok) ToastUtil.show(i18n('my_category_limit'));
  }

  /// 收藏集合的选中判据,与 [MyCategoryController.isFavorited] 同语义:
  /// 命中跨平台映射的条目按跨平台 key 一并命中;私有分类退回
  /// (site, name) 精确比较。收藏 key 集合每 build 算一次(条目 ≤ 上限),
  /// chips 逐条 O(1) 查集合,不做「逐 chip × 逐收藏」的映射表重扫。
  ({Set<String> crossKeys, List<MyCategoryEntry> rawEntries}) _favoriteMatchKeys() {
    final crossKeys = <String>{};
    final rawEntries = <MyCategoryEntry>[];
    for (final entry in MyCategoryController.to.categories) {
      if (!entry.isValid) continue;
      final key = crossKeyForPlatformCategory(entry.site, '', entry.name);
      if (key.isNotEmpty) {
        crossKeys.add(key);
      } else {
        rawEntries.add(entry);
      }
    }
    return (crossKeys: crossKeys, rawEntries: rawEntries);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pickSite == 'all') return _crossCatalog(context);
    if (!Get.isRegistered<AreasListController>(tag: widget.pickSite)) {
      return _CatalogHint(message: i18n('empty_areas_title'));
    }
    final controller = Get.find<AreasListController>(tag: widget.pickSite);
    return Obx(() {
      // 读 categories 即被追踪:目录到位/变化触发重建。
      final groups = [
        for (final group in controller.categories)
          if (group.children.isNotEmpty) group,
      ];
      final match = _favoriteMatchKeys();
      if (groups.isEmpty) {
        // 目录未就绪(懒加载在途/拉取失败):占位提示,Obx 跟随目录到位重建。
        return _CatalogHint(message: i18n('empty_areas_title'));
      }
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < groups.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              Text(
                displayCategoryGroupName(widget.pickSite, groups[i].name),
                style: TextStyle(
                  fontSize: AppFontSize.bodySecondary,
                  fontWeight: FontWeight.w700,
                  color: context.tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final area in groups[i].children)
                    if ((area.areaName ?? '').trim().isNotEmpty) _pickableChipFor(widget.pickSite, area, match),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }

  /// 全平台目录:跨平台映射表全量 chips(条目即 canonical 中文名,
  /// `displayCategoryName('all', …)` 恒等返回,无需再映射)。chips 的
  /// 跨平台 key 是静态量,initState 预解析一次,build 只做集合判选中。
  Widget _crossCatalog(BuildContext context) {
    final entriesByKey = _crossEntriesByKey ??= {
      for (final entry in kCrossCategories)
        if (entry.key.isNotEmpty) entry.key: entry,
    };
    return Obx(() {
      final match = _favoriteMatchKeys();
      return SingleChildScrollView(
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final chipKey in entriesByKey.keys)
              _PickableChip(
                label: entriesByKey[chipKey]!.name,
                selected: match.crossKeys.contains(chipKey),
                onTap: () => unawaited(_toggleCatalogCategory('all', entriesByKey[chipKey]!.name)),
              ),
          ],
        ),
      );
    });
  }

  /// 平台目录 chip:展示名统一走跨平台中文映射(快照与渲染同源);
  /// 选中态 = 跨平台 key 命中任一平台收藏,或私有分类 (site, name) 全等。
  Widget _pickableChipFor(
    String siteId,
    LiveArea area,
    ({Set<String> crossKeys, List<MyCategoryEntry> rawEntries}) match,
  ) {
    final label = displayCategoryName(siteId, area.areaName, area.areaId);
    final chipKey = crossKeyForPlatformCategory(siteId, '', label);
    final selected = chipKey.isNotEmpty
        ? match.crossKeys.contains(chipKey)
        : match.rawEntries.any((entry) => entry.site == siteId && entry.name == label);
    return _PickableChip(
      label: label,
      selected: selected,
      onTap: () => unawaited(_toggleCatalogCategory(siteId, label)),
    );
  }
}

/// 目录占位提示(未就绪/无数据)。
class _CatalogHint extends StatelessWidget {
  const _CatalogHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: TextStyle(fontSize: AppFontSize.bodySecondary, color: context.tokens.textSecondary),
      ),
    );
  }
}

/// 目录站点切换 chip(全平台 / 各平台,对齐真源 `_SiteTabChip`):无星标,
/// 选中金描边。
class _SiteTabChip extends StatelessWidget {
  const _SiteTabChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Ink(
      decoration: BoxDecoration(
        color: selected ? tokens.brand.withValues(alpha: 0.12) : tokens.surfaceSoft,
        border: Border.all(color: selected ? tokens.brand.withValues(alpha: 0.55) : tokens.border),
        borderRadius: AppRadius.allPill,
      ),
      child: InkWell(
        borderRadius: AppRadius.allPill,
        onTap: onTap,
        hoverColor: tokens.brand.withValues(alpha: 0.1),
        focusColor: AppStateLayer.focusOf(tokens.accent),
        splashColor: AppStateLayer.splashOf(tokens.brandBright),
        highlightColor: AppStateLayer.pressedOf(tokens.brandBright),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9.6, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppFontSize.body,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? tokens.brand : tokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 目录中的可选 chip(对齐真源 `_PickableChip`):选中为金描边 + 实心星,
/// 未选中为描边 pill + 空心星。
class _PickableChip extends StatelessWidget {
  const _PickableChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Ink(
      decoration: BoxDecoration(
        color: selected ? tokens.brand.withValues(alpha: 0.12) : tokens.surfaceSoft,
        border: Border.all(color: selected ? tokens.brand.withValues(alpha: 0.55) : tokens.border),
        borderRadius: AppRadius.allPill,
      ),
      child: InkWell(
        borderRadius: AppRadius.allPill,
        onTap: onTap,
        // 选中态底色已是品牌金 12%:hover/按下/焦点全部取品牌金淡染
        // (选中再叠金只是更深,不会把「已选」状态盖掉)。
        hoverColor: tokens.brand.withValues(alpha: 0.1),
        focusColor: AppStateLayer.focusOf(tokens.accent),
        splashColor: AppStateLayer.splashOf(tokens.brandBright),
        highlightColor: AppStateLayer.pressedOf(tokens.brandBright),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9.6, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.star_rounded : Icons.star_border_rounded,
                size: 13,
                color: selected ? tokens.brand : tokens.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontSize: AppFontSize.body, color: selected ? tokens.brand : tokens.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 已收藏 chip:带移除叉号(对齐真源 `_RemovableChip`)。
class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 9.6, right: 2),
      decoration: BoxDecoration(
        color: context.tokens.brand.withValues(alpha: 0.1),
        border: Border.all(color: context.tokens.brand.withValues(alpha: 0.55)),
        borderRadius: AppRadius.allPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: AppFontSize.body, color: context.tokens.brandBright),
          ),
          InkWell(
            borderRadius: AppRadius.allPill,
            onTap: onRemove,
            hoverColor: context.tokens.surfaceRaised,
            focusColor: AppStateLayer.focusOf(context.tokens.accent),
            splashColor: AppStateLayer.splashOf(context.tokens.accent),
            highlightColor: AppStateLayer.pressedOf(context.tokens.accent),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(Icons.close_rounded, size: 13, color: context.tokens.brandBright),
            ),
          ),
        ],
      ),
    );
  }
}

/// 窄屏底栏「我的分类」入口:flyout 同款内容的底部弹层。容器规格与
/// `ZishuPhoneCategorySheet`(平台分类底部面板)同款 —— surface 底 + 顶缘
/// 12px 圆角 + 标题行 + 1px 分隔线,内容直接嵌 [ZishuMyCategoryPanel]。
Future<void> showZishuMyCategorySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const ZishuMyCategorySheet(),
  );
}

/// 「我的分类」底部弹层:标题行(我的分类 + 关闭)+ 面板内容。
class ZishuMyCategorySheet extends StatelessWidget {
  const ZishuMyCategorySheet({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    i18n('my_category_title'),
                    style: TextStyle(
                      fontSize: AppFontSize.body,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: i18n('close'),
                  onPressed: () => Navigator.of(context).pop(),
                  hoverColor: tokens.surfaceRaised,
                  focusColor: AppStateLayer.focusOf(tokens.accent),
                  splashColor: AppStateLayer.splashOf(tokens.accent),
                  highlightColor: AppStateLayer.pressedOf(tokens.accent),
                  icon: Icon(Icons.close_rounded, size: 18, color: tokens.textSecondary),
                ),
              ],
            ),
          ),
          Container(height: 1, color: tokens.border),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: ZishuMyCategoryPanel(onClose: () => Navigator.of(context).pop()),
            ),
          ),
        ],
      ),
    );
  }
}
