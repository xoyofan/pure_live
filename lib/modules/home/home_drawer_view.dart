import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/home/home_nav_items.dart';

/// Narrow (≤680px) home shell: the page body wrapped in a Scaffold whose
/// `NavigationDrawer` carries the same destinations as the wide sidebar.
class HomeDrawerView extends StatelessWidget {
  /// The tab pages live in nested Scaffolds, so `Scaffold.of` from an AppBar
  /// leading button resolves to the page scaffold and can never reach this
  /// shell's drawer. [HomeDrawerButton] opens the drawer through this key.
  static final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>(debugLabel: 'home-drawer-scaffold');

  final Widget body;
  final int index;
  final List<String> activeMenuIds;
  final void Function(int) onDestinationSelected;

  const HomeDrawerView({
    super.key,
    required this.body,
    required this.index,
    required this.activeMenuIds,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final primary = buildHomePrimaryNavItems(activeMenuIds);

    return Scaffold(
      key: scaffoldKey,
      drawer: Obx(() {
        final secondary = buildHomeSecondaryNavItems();

        return NavigationDrawer(
          // Drawer stays reachable even with zero primary menus so the user
          // can always reach 设置→导航 to re-enable entries.
          selectedIndex: _selectedDrawerIndex(primary),
          onDestinationSelected: (int drawerIndex) {
            Navigator.pop(context);
            if (drawerIndex >= 0 && drawerIndex < primary.length) {
              final menuIndex = primary[drawerIndex].menuIndex;
              if (menuIndex != null) {
                onDestinationSelected(menuIndex);
              }
            }
          },
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 16, 10),
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
            ListTile(
              leading: Icon(homeSearchNavItem.icon),
              title: Text(i18n(homeSearchNavItem.labelKey)),
              onTap: () {
                Navigator.pop(context);
                homeSearchNavItem.onTap?.call();
              },
            ),
            const Divider(),
            // NavigationDrawerDestination numbering skips non-destination
            // children, so [drawerIndex] maps straight onto `primary`.
            for (final HomeNavItem item in primary)
              NavigationDrawerDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: Text(i18n(item.labelKey)),
              ),
            const Divider(),
            for (final HomeNavItem item in secondary)
              ListTile(
                leading: Icon(item.icon),
                title: Text(i18n(item.labelKey)),
                onTap: () {
                  Navigator.pop(context);
                  item.onTap?.call();
                },
              ),
          ],
        );
      }),
      body: body,
    );
  }

  /// Position of [index] among the primary destinations, or null when the
  /// active page is not a primary destination (drawer highlights nothing).
  int? _selectedDrawerIndex(List<HomeNavItem> primary) {
    for (int i = 0; i < primary.length; i++) {
      if (primary[i].menuIndex == index) {
        return i;
      }
    }
    return null;
  }
}
