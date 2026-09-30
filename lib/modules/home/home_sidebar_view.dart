import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/home/home_nav_items.dart';

/// Wide (>680px) home shell: a persistent ~200dp sidebar next to the full
/// page body. Primary entries come from `savedMenuIds`; secondary entries
/// replace the old rail leading icon column.
class HomeSidebarView extends StatelessWidget {
  final Widget body;
  final int index;
  final List<String> activeMenuIds;
  final void Function(int) onDestinationSelected;

  const HomeSidebarView({
    super.key,
    required this.body,
    required this.index,
    required this.activeMenuIds,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // One Obx covers both the sidebar entries and the empty-body switch:
        // secondary entries and primary visibility all read settings here.
        child: Obx(() {
          final primary = buildHomePrimaryNavItems(activeMenuIds);
          final secondary = buildHomeSecondaryNavItems();

          return Row(
            children: [
              SizedBox(
                width: 200,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(26, 14, 16, 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Pure Live',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    _NavTile(item: homeSearchNavItem, selected: false, onTap: homeSearchNavItem.onTap),
                    const _NavDivider(),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        children: [
                          for (final HomeNavItem item in primary)
                            _NavTile(
                              item: item,
                              selected: item.menuIndex == index,
                              onTap: item.menuIndex == null ? null : () => onDestinationSelected(item.menuIndex!),
                            ),
                        ],
                      ),
                    ),
                    const _NavDivider(),
                    ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 8),
                      children: [
                        for (final HomeNavItem item in secondary)
                          _NavTile(item: item, selected: false, onTap: item.onTap),
                      ],
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: primary.isEmpty
                    ? AppStatusView(
                        type: AppStatusType.empty,
                        icon: Remix.menu_2_fill,
                        title: i18n('no_menu_title'),
                        subtitle: i18n('no_menu_subtitle'),
                      )
                    : body,
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _NavDivider extends StatelessWidget {
  const _NavDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Divider(height: 1));
  }
}

/// Pill-shaped sidebar entry; the selected state uses the theme's
/// `secondaryContainer`, matching the app's M3 selection styling.
class _NavTile extends StatelessWidget {
  final HomeNavItem item;
  final bool selected;
  final void Function()? onTap;

  const _NavTile({required this.item, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? theme.colorScheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 22,
                  color: selected ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    i18n(item.labelKey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.onSurface,
                    ),
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
