import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildTipBanner(theme),
          const SizedBox(height: 16),
          context.buildGroupTitle(i18n("platform_order_settings")),
          Obx(() {
            final savedOrder = AppSettingsController.normalizePlatformIds(SettingsService.to.app.savedPlatformIds.v);
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

            return Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05), width: 0.5),
              ),
              child: ReorderableListView.builder(
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
                              AppSettingsController.normalizePlatformIds(SettingsService.to.app.savedPlatformIds.v)
                                      .length <=
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: PlatformIcon(id: site.id, size: 26),
                      title: Text(site.name, style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600)),
                      subtitle: Text(site.id, style: AppTextStyles.t11),
                      trailing: buildControls(),
                    ),
                  );
                },
              ),
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTipBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Remix.information_line, size: 18, color: theme.colorScheme.primary.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              i18n('platform_order_settings_desc'),
              style: AppTextStyles.t13.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
