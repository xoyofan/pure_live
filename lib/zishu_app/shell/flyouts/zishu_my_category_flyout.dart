import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/areas/areas_list_controller.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/zishu/domain/category_display.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/play/my_category_controller.dart';
import 'package:pure_live/zishu_app/shell/flyouts/zishu_flyout_panel.dart';

// 「我的分类」飞出面板(移植 zishu 真源
// `lib/src/app/shell/my_category_flyout.dart` 的 `_MyCategoryFlyout`,
// 对齐 SFVideoLive `NavMyCategoryMenu.vue`):右上角「管理分类」入口 +
// 收藏 chip 折行区(max-height 11rem≈176px),空集合显示「暂无收藏分类」。
//
// 数据层按 pure_live 落地:chips = MyCategoryController.categories
// (GetX RxList,UI 侧 `Obx` 直读,替代真源 Riverpod
// ref.watch(myCategoriesProvider))。chip 点击进**收藏时刻平台**的原生
// 分类:按名称匹配 `AreasListController(tag=entry.site)` 目录(resolveMyCategoryArea),
// 命中 AppNavigator.toCategoryDetail,未命中 toast 提示(真源恒跳全平台
// 分类页,pure_live 无全平台分类路由,按任务口径退回平台目录)。管理 =
// ZishuMyCategoryManageDialog 列表移除(controller 只有 toggle,
// 移除即对已收藏条目 toggle 同义)。
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
  const ZishuMyCategoryPanel({super.key, this.onClose});

  /// chip 跳转 / 开管理弹窗前收起宿主(浮层 pop、底栏弹层 pop);侧栏内嵌
  /// 展开等无宿主可收时留空。
  final VoidCallback? onClose;

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
        ZishuMyCategoryChips(maxHeight: kZishuMyCategoryTagsMaxHeight, onClose: onClose),
      ],
    );
  }
}

/// 收藏 chip 折行区:`Obx` 订阅 [MyCategoryController.categories],空集合
/// 提示「暂无收藏分类」。chip 点击 → [resolveMyCategoryArea] 按名称匹配
/// 该平台目录,命中先 [onClose] 收起宿主再进分类详情;未命中 toast 并保留
/// 面板(用户可直接改选其他分类)。
class ZishuMyCategoryChips extends StatelessWidget {
  const ZishuMyCategoryChips({super.key, this.maxHeight = kZishuMyCategoryTagsMaxHeight, this.onClose});

  final double maxHeight;
  final VoidCallback? onClose;

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
    final area = resolveMyCategoryArea(entry);
    if (area == null) {
      ToastUtil.show(i18n('go_category_failed'));
      return;
    }
    onClose?.call();
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

/// 我的分类管理弹窗:已收藏列表 + 叉号移除。真源管理弹窗还有「全平台 +
/// 各平台目录点选收藏」区,依赖 Riverpod `browseCategoriesProvider`;本版
/// 按任务口径只做列表移除(controller 只有 toggle,移除 = 对已收藏条目
/// toggle 取消,同义;追加收藏走播放页收藏星)。上限提示文案对齐真源。
class ZishuMyCategoryManageDialog extends StatelessWidget {
  const ZishuMyCategoryManageDialog({super.key});

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
        child: Obx(() {
          final entries = [
            for (final entry in MyCategoryController.to.categories)
              if (entry.isValid) entry,
          ];
          if (entries.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                i18n('my_category_empty'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: AppFontSize.body, color: tokens.textSecondary),
              ),
            );
          }
          return SingleChildScrollView(
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
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n('done')))],
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
