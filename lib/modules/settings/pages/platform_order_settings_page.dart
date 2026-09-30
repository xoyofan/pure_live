import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/platform_icon.dart';

/// 外壳平台入口(顶栏平台 tab + 侧栏色块)的排序与可见性设置。
///
/// 交互与 `NavigationSettingsPage` 同源:开关 = 是否可见,拖拽把手 =
/// 调整顺序;持久化在 `SettingsService.to.app.savedPlatformIds`(本机
/// Hive,并随备份/恢复配置走)。
class PlatformOrderSettingsPage extends StatelessWidget {
  const PlatformOrderSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allSites = Sites().availableSites();

    return Scaffold(
      appBar: AppBar(title: Text(i18n("platform_order_settings"))),
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
                  const _ZishuTipBanner(),
                  const SizedBox(height: AppSpacing.lg),
                  _ZishuGroup(
                    title: i18n("platform_order_settings"),
                    children: [
                      Obx(() {
                        final savedOrder = AppSettingsController.normalizePlatformIds(
                          SettingsService.to.app.savedPlatformIds.v,
                        );
                        // 保存顺序优先;新增站点(未入保存表)按 availableSites 原序追加在后。
                        final sortedSites = List<Site>.from(allSites);
                        sortedSites.sort((a, b) {
                          final indexA = savedOrder.indexOf(a.id);
                          final indexB = savedOrder.indexOf(b.id);
                          if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
                          if (indexA != -1) return -1;
                          if (indexB != -1) return 1;
                          return 0;
                        });

                        return ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: sortedSites.length,
                          onReorderItem: (oldIndex, newIndex) {
                            if (oldIndex < 0 || oldIndex >= sortedSites.length) return;
                            final movedId = sortedSites[oldIndex].id;
                            final currentOrder = List<String>.from(savedOrder);
                            final oldVisibleIndex = currentOrder.indexOf(movedId);
                            // 隐藏行没有持久化顺序,不可拖拽。
                            if (oldVisibleIndex < 0) return;
                            if (newIndex > oldIndex) newIndex -= 1;
                            currentOrder.removeAt(oldVisibleIndex);
                            final insertIndex = newIndex.clamp(0, currentOrder.length);
                            currentOrder.insert(insertIndex, movedId);
                            SettingsService.to.app.savedPlatformIds.v = currentOrder;
                          },
                          itemBuilder: (context, index) {
                            final site = sortedSites[index];
                            final isVisible = SettingsService.to.app.savedPlatformIds.v.contains(site.id);

                            Widget buildControls() => Row(
                              key: ValueKey('platform-controls-${site.id}'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  key: ValueKey('platform-switch-${site.id}'),
                                  value: isVisible,
                                  activeThumbColor: theme.colorScheme.primary,
                                  onChanged: (value) {
                                    if (!value &&
                                        AppSettingsController.normalizePlatformIds(
                                              SettingsService.to.app.savedPlatformIds.v,
                                            ).length <=
                                            1) {
                                      ToastUtil.show(i18n("at_least_one_platform_required"));
                                      return;
                                    }
                                    SettingsService.to.app.togglePlatformVisibility(site.id, value);
                                  },
                                ),
                                if (isVisible && savedOrder.length > 1) ...[
                                  const SizedBox(width: 8),
                                  Tooltip(
                                    message: i18n('drag_menu_to_sort_tip'),
                                    child: ReorderableDragStartListener(
                                      key: ValueKey('platform-drag-${site.id}'),
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
                              key: ValueKey(site.id),
                              color: Colors.transparent,
                              child: ListTile(
                                key: ValueKey('platform-tile-${site.id}'),
                                contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                leading: _ZishuIconBlock(child: PlatformIcon(id: site.id, size: 20)),
                                title: Text(site.name, style: context.textBody.copyWith(fontWeight: FontWeight.w600)),
                                subtitle: Text(site.id, style: context.textCaption),
                                trailing: buildControls(),
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
          Expanded(child: Text(i18n('platform_order_settings_desc'), style: context.textCaption.copyWith(height: 1.4))),
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
