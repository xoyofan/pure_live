import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

class NavigationSettingsPage extends StatelessWidget {
  const NavigationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 1. 定义所有菜单（固定不变）
    final allMenus = [HomeMenu.favorites, HomeMenu.popular, HomeMenu.areas, HomeMenu.record];

    return Scaffold(
      appBar: AppBar(title: Text(i18n("navigation_display_settings"))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (PlatformUtils.isWindows) ...[
                    _ZishuGroup(
                      title: i18n("multiview_title"),
                      children: [
                        _ZishuSwitchRow(
                          title: i18n("multiview_title"),
                          value: SettingsService.to.app.enableMultiView,
                          icon: Remix.layout_grid_line,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  const _ZishuTipBanner(),
                  const SizedBox(height: AppSpacing.lg),
                  _ZishuGroup(
                    title: i18n("navigation_display_settings"),
                    children: [
                      Obx(() {
                        // 2. 关键：按 savedMenuIds 的顺序给 allMenus 排序
                        final savedOrder = AppSettingsController.normalizeMenuIds(
                          SettingsService.to.app.savedMenuIds.v,
                        );
                        // 给每个菜单一个排序权重：在 savedMenuIds 里的位置，不在里面的排到最后
                        final sortedMenus = List<HomeMenu>.from(allMenus);
                        sortedMenus.sort((a, b) {
                          final indexA = savedOrder.indexOf(a.id);
                          final indexB = savedOrder.indexOf(b.id);
                          // 都在列表里：按 savedOrder 顺序排
                          if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
                          // 只有一个在列表里：在列表里的排前面
                          if (indexA != -1) return -1;
                          if (indexB != -1) return 1;
                          // 都不在：保持原始顺序
                          return 0;
                        });

                        return ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: sortedMenus.length,
                          onReorderItem: (oldIndex, newIndex) {
                            if (oldIndex < 0 || oldIndex >= sortedMenus.length) return;
                            final movedId = sortedMenus[oldIndex].id;
                            final currentOrder = List<String>.from(savedOrder);
                            final oldVisibleIndex = currentOrder.indexOf(movedId);
                            // Hidden rows have no persisted order and therefore no drag
                            // action. Older builds exposed their handle, then indexed
                            // past the shorter visible-id list.
                            if (oldVisibleIndex < 0) return;
                            if (newIndex > oldIndex) newIndex -= 1;
                            currentOrder.removeAt(oldVisibleIndex);
                            final insertIndex = newIndex.clamp(0, currentOrder.length);
                            currentOrder.insert(insertIndex, movedId);
                            SettingsService.to.app.savedMenuIds.v = currentOrder;
                          },
                          itemBuilder: (context, index) {
                            final menu = sortedMenus[index];
                            // 开关状态直接从 savedMenuIds 判断
                            final isVisible = SettingsService.to.app.savedMenuIds.v.contains(menu.id);

                            String titleText = "";
                            IconData menuIcon = Remix.question_line;
                            switch (menu) {
                              case HomeMenu.favorites:
                                titleText = i18n("favorites_title");
                                menuIcon = Remix.heart_3_fill;
                                break;
                              case HomeMenu.popular:
                                titleText = i18n("popular_title");
                                menuIcon = CustomIcons.popular;
                                break;
                              case HomeMenu.areas:
                                titleText = i18n("areas_title");
                                menuIcon = Remix.apps_2_line;
                                break;
                              case HomeMenu.record:
                                titleText = i18n("record_center");
                                menuIcon = Remix.download_2_fill;
                                break;
                            }

                            Widget buildControls() => Row(
                              key: ValueKey('navigation-menu-controls-${menu.id}'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  key: ValueKey('navigation-menu-switch-${menu.id}'),
                                  value: isVisible,
                                  activeThumbColor: theme.colorScheme.primary,
                                  onChanged: (value) {
                                    final savedMenus = AppSettingsController.normalizeMenuIds(
                                      SettingsService.to.app.savedMenuIds.v,
                                    );
                                    if (!value && savedMenus.length <= 1) {
                                      ToastUtil.show(i18n("at_least_one_menu_required"));
                                      return;
                                    }
                                    SettingsService.to.app.toggleMenuVisibility(menu, value);
                                  },
                                ),
                                if (isVisible && savedOrder.length > 1) ...[
                                  const SizedBox(width: 8),
                                  Tooltip(
                                    message: i18n('drag_menu_to_sort_tip'),
                                    child: ReorderableDragStartListener(
                                      key: ValueKey('navigation-menu-drag-${menu.id}'),
                                      index: index,
                                      child: const SizedBox.square(
                                        dimension: kMinInteractiveDimension,
                                        child: Center(child: Icon(RemixIcons.sort_asc, size: 20)),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );

                            return Material(
                              key: ValueKey(menu.id),
                              color: Colors.transparent,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final tokens = context.tokens;
                                  final title = Text(
                                    titleText,
                                    key: ValueKey('navigation-menu-title-${menu.id}'),
                                    style: context.textBody.copyWith(fontWeight: FontWeight.w600),
                                  );
                                  final controls = buildControls();
                                  final stackControls =
                                      constraints.maxWidth < 360 || MediaQuery.textScalerOf(context).scale(1) > 1.5;
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                    title: stackControls
                                        ? Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [title, const SizedBox(height: 6), controls],
                                          )
                                        : title,
                                    leading: _ZishuIconBlock(
                                      child: Icon(menuIcon, size: 18, color: tokens.textSecondary),
                                    ),
                                    trailing: stackControls ? null : controls,
                                  );
                                },
                              ),
                            );
                          },
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// zishu 分组卡片:surface + AppRadius.allMd + hairline tokens.border 描边,
/// elevation 0(无投影)。与 ZishuSettingsView 的 `_SettingsGroup` 同构,
/// 半径按本轨口径取 allMd。
class _ZishuGroup extends StatelessWidget {
  const _ZishuGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: AppRadius.allMd,
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: context.textBody.copyWith(fontWeight: FontWeight.w700, color: tokens.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

/// zishu 提示横幅:surface + accent 5% 淡底 + hairline 描边。
class _ZishuTipBanner extends StatelessWidget {
  const _ZishuTipBanner();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: Color.alphaBlend(tokens.accent.withValues(alpha: 0.05), tokens.surface),
        borderRadius: AppRadius.allMd,
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Remix.information_line, size: 18, color: tokens.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(i18n('drag_menu_to_sort_tip'), style: context.textCaption.copyWith(height: 1.4))),
        ],
      ),
    );
  }
}

/// zishu 行首图标块:36×36 surfaceRaised 圆角小底。
class _ZishuIconBlock extends StatelessWidget {
  const _ZishuIconBlock({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: tokens.surfaceRaised, borderRadius: AppRadius.allSm),
      child: Center(child: child),
    );
  }
}

/// zishu 开关行:行为与 `context.buildSwitchTile` 完全一致
/// (Obx 包裹 + `value.value = val` 自动提交 + 可选 onChanged 回调),
/// 仅替换行外观为 zishu 行样式 + 裸 Switch。
class _ZishuSwitchRow extends StatelessWidget {
  const _ZishuSwitchRow({this.icon, required this.title, required this.value});

  final IconData? icon;
  final String title;
  final RxBool value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Obx(
      () => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: tokens.surfaceRaised, borderRadius: AppRadius.allSm),
              child: Center(child: Icon(icon, size: 18, color: tokens.textSecondary)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textBody.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Switch(
              value: value.value,
              onChanged: (val) {
                value.value = val;
              },
            ),
          ],
        ),
      ),
    );
  }
}
