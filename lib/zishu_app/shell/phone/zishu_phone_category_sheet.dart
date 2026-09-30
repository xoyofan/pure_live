import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/areas/areas_list_controller.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/zishu/domain/category_display.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/platform_brands.dart';
import 'package:pure_live/zishu/presentation/widgets/empty_view.dart' as zishu;
import 'package:pure_live/zishu/presentation/widgets/retry_button.dart' as zishu;
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

/// 打开平台分类底部面板(移植 zishu_flutter `shell/category_flyout.dart` 的
/// `_PlatformCategorySheet`,即 web `nav-cat-sheet`:Teleport 到 body 的底部抽屉)。
Future<void> showZishuPhoneCategorySheet(BuildContext context, String siteId) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => ZishuPhoneCategorySheet(siteId: siteId),
  );
}

/// 平台分类底部面板:标题「{平台} · 分类」+ 关闭;分组标题 + 子分类 chips,
/// 点选后 `AppNavigator.toCategoryDetail` 进该平台子分类的房间流(与
/// pure_live 分区页同一导航入口)。
///
/// 数据层不用 zishu 的 `browseCategoriesProvider`(Riverpod),改 pure_live
/// 既有 `AreasListController(tag=siteId)`:`categories`(`RxList<AppLiveCategory>`)
/// 按「分组标题 + children」天然对应真源的分组/chips 结构。控制器未注册时
/// 按 `AreasController._registerListController` 同参(tag/fenix)lazyPut,
/// AreasController 之后初始化会直接复用这一份,不产生双实例。
class ZishuPhoneCategorySheet extends StatefulWidget {
  const ZishuPhoneCategorySheet({super.key, required this.siteId});

  final String siteId;

  @override
  State<ZishuPhoneCategorySheet> createState() => _ZishuPhoneCategorySheetState();
}

class _ZishuPhoneCategorySheetState extends State<ZishuPhoneCategorySheet> {
  AreasListController? _controller;
  final RxBool _loadFailed = false.obs;

  @override
  void initState() {
    super.initState();
    _controller = _resolveController(widget.siteId);
    unawaited(_ensureLoaded());
  }

  AreasListController? _resolveController(String siteId) {
    if (Get.isRegistered<AreasListController>(tag: siteId)) {
      return Get.find<AreasListController>(tag: siteId);
    }
    Site? found;
    for (final candidate in Sites().availableSites()) {
      if (candidate.id == siteId) {
        found = candidate;
        break;
      }
    }
    if (found == null) return null;
    final site = found;
    Get.lazyPut(() => AreasListController(site), tag: siteId, fenix: true);
    return Get.find<AreasListController>(tag: siteId);
  }

  /// 该平台不是分区页当前 tab 时,AreasController 不会替它预取目录,
  /// 面板自行触发一次(与 AreasController._loadCurrentTabData 同款判空)。
  Future<void> _ensureLoaded() async {
    final controller = _controller;
    if (controller == null || controller.categories.isNotEmpty) return;
    try {
      await controller.loadData();
    } catch (_) {
      _loadFailed.value = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final brand = PlatformBrandCatalog.byId(widget.siteId);
    final siteName = brand?.name ?? widget.siteId;
    return Container(
      key: const Key('platform-cat-sheet'),
      height: MediaQuery.sizeOf(context).height * 0.72,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$siteName · 分类',
                    style: TextStyle(
                      fontSize: AppFontSize.body,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('platform-cat-sheet-close'),
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
          Expanded(child: _buildBody(context, tokens)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, ZishuTokens tokens) {
    final controller = _controller;
    if (controller == null) {
      return Center(
        child: Text(
          i18n('empty_areas_title'),
          style: TextStyle(fontSize: AppFontSize.bodySecondary, color: tokens.textSecondary),
        ),
      );
    }
    return Obx(() {
      final categories = controller.categories;
      if (categories.isEmpty) {
        if (_loadFailed.value) {
          return zishu.EmptyView(
            icon: Icons.apps_rounded,
            message: i18n('empty_areas_title'),
            action: zishu.RetryButton(
              label: i18n('retry'),
              onRetry: () {
                _loadFailed.value = false;
                unawaited(_ensureLoaded());
              },
            ),
          );
        }
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      }
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final category in categories) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                // 分组名统一走跨平台中文映射(已有中文名原样返回,海外平台归一)。
                displayCategoryGroupName(widget.siteId, category.name),
                style: TextStyle(
                  fontSize: AppFontSize.bodySecondary,
                  fontWeight: FontWeight.w700,
                  color: tokens.textSecondary,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final area in category.children)
                  if ((area.areaName ?? '').isNotEmpty)
                    // chip 底色不透明:InkWell 的叠色必须画在填色之上,
                    // 故用 `Ink` 把底色铺进 Material 的 ink 层(真源同款)。
                    Ink(
                      decoration: BoxDecoration(
                        color: tokens.surfaceRaised,
                        borderRadius: AppRadius.allMd,
                        border: Border.all(color: tokens.border),
                      ),
                      child: InkWell(
                        // 组 id 拼进锚点:不同分组的子分类可能重 id,
                        // 直接用 areaId 会在同树上撞 duplicate key。
                        key: Key('platform-cat-item-${category.id}-${area.areaId ?? ''}'),
                        borderRadius: AppRadius.allMd,
                        // 底色已是抬升顶档 surfaceRaised:hover 改走强调色
                        // 12% 淡染;焦点取 AppFocus 环的光晕色(真源同口径)。
                        hoverColor: tokens.accent.withValues(alpha: AppDirectoryDrawer.activeChipAlpha),
                        focusColor: AppFocus.ring(tokens.accent).first.color,
                        splashColor: AppStateLayer.splashOf(tokens.accent),
                        highlightColor: AppStateLayer.pressedOf(tokens.accent),
                        onTap: () {
                          Navigator.of(context).pop();
                          AppNavigator.toCategoryDetail(site: controller.site, category: area);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Text(
                            // chip 名同走映射,areaId 当 cid(soop 等按分类号反查中文名)。
                            displayCategoryName(widget.siteId, area.areaName, area.areaId),
                            style: TextStyle(fontSize: AppFontSize.bodySecondary, color: tokens.textPrimary),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      );
    });
  }
}
