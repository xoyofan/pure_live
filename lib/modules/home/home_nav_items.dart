import 'dart:io';

import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/common/utils/windows_multi_instance_launcher.dart';
import 'package:pure_live/routes/app_navigation.dart';

/// One entry of the home shell navigation, shared by the wide-layout sidebar
/// and the narrow-layout drawer so both always offer the same destinations.
///
/// Primary entries map to a real [HomeMenu.index] and are routed through the
/// shell's `onDestinationSelected`; secondary entries navigate directly and
/// replace the former `MenuButton` popup, `CommonAppBarActions` popup and
/// rail leading icon column entries.
class HomeNavItem {
  final String id;
  final IconData icon;
  final IconData selectedIcon;
  final String labelKey;

  /// Non-null for primary entries: the real [HomeMenu.index] handed to
  /// `onDestinationSelected`. Null for secondary entries, which use [onTap].
  final int? menuIndex;
  final void Function()? onTap;

  const HomeNavItem._({
    required this.id,
    required this.icon,
    required this.selectedIcon,
    required this.labelKey,
    this.menuIndex,
    this.onTap,
  });
}

// Menu entries are built at runtime: `HomeMenu.xxx.index` is not a
// constant expression, so these stay non-const.
HomeNavItem homeNavItemForMenu(HomeMenu menu) {
  switch (menu) {
    case HomeMenu.favorites:
      return HomeNavItem._(
        id: HomeMenu.favorites.id,
        icon: Remix.heart_3_line,
        selectedIcon: Remix.heart_3_fill,
        labelKey: 'favorites_title',
        menuIndex: HomeMenu.favorites.index,
      );
    case HomeMenu.popular:
      return HomeNavItem._(
        id: HomeMenu.popular.id,
        icon: Remix.fire_line,
        selectedIcon: Remix.fire_fill,
        labelKey: 'popular_title',
        menuIndex: HomeMenu.popular.index,
      );
    case HomeMenu.areas:
      return HomeNavItem._(
        id: HomeMenu.areas.id,
        icon: Remix.apps_2_line,
        selectedIcon: Remix.apps_2_fill,
        labelKey: 'areas_title',
        menuIndex: HomeMenu.areas.index,
      );
    case HomeMenu.record:
      return HomeNavItem._(
        id: HomeMenu.record.id,
        icon: Remix.download_2_line,
        selectedIcon: Remix.download_2_fill,
        labelKey: 'record_center',
        menuIndex: HomeMenu.record.index,
      );
  }
}

/// Search lives above the primary section in both shells.
const HomeNavItem homeSearchNavItem = HomeNavItem._(
  id: 'search',
  icon: Remix.search_line,
  selectedIcon: Remix.search_line,
  labelKey: 'search_live',
  onTap: _openSearch,
);

void _openSearch() => Get.toNamed(RoutePath.kSearch);

/// Primary entries follow the order and visibility configured by
/// 设置→导航 (`savedMenuIds`); no hard-coded menu list here.
List<HomeNavItem> buildHomePrimaryNavItems(List<String> activeMenuIds) {
  final items = <HomeNavItem>[];
  for (final String id in activeMenuIds) {
    final menu = HomeMenu.fromId(id);
    if (menu != null) {
      items.add(homeNavItemForMenu(menu));
    }
  }
  return items;
}

/// Secondary entries covering every former `MenuButton` (settings/about/
/// history/backup/new window), `CommonAppBarActions` (search/toolbox/
/// multiview) and rail-leading entry.
///
/// Reads `enableMultiView` / `enableNewWindowPlay`, so call inside `Obx`.
List<HomeNavItem> buildHomeSecondaryNavItems() {
  return [
    const HomeNavItem._(
      id: 'history',
      icon: Remix.history_line,
      selectedIcon: Remix.history_line,
      labelKey: 'history',
      onTap: _openHistory,
    ),
    if (SettingsService.to.app.enableMultiView.v)
      const HomeNavItem._(
        id: 'multiview',
        icon: Remix.layout_grid_line,
        selectedIcon: Remix.layout_grid_line,
        labelKey: 'multiview_title',
        onTap: AppNavigator.toMultiview,
      ),
    const HomeNavItem._(
      id: 'toolbox',
      icon: Remix.link,
      selectedIcon: Remix.link,
      labelKey: 'open_link',
      onTap: _openToolbox,
    ),
    const HomeNavItem._(
      id: 'backup',
      icon: Remix.cloud_line,
      selectedIcon: Remix.cloud_line,
      labelKey: 'backup_recover',
      onTap: _openBackup,
    ),
    const HomeNavItem._(
      id: 'about',
      icon: Remix.information_line,
      selectedIcon: Remix.information_line,
      labelKey: 'about',
      onTap: _openAbout,
    ),
    const HomeNavItem._(
      id: 'settings',
      icon: Remix.settings_5_line,
      selectedIcon: Remix.settings_5_line,
      labelKey: 'settings_title',
      onTap: _openSettings,
    ),
    if (Platform.isWindows && SettingsService.to.app.enableNewWindowPlay.v)
      const HomeNavItem._(
        id: 'new_window',
        icon: Icons.add_to_photos_outlined,
        selectedIcon: Icons.add_to_photos_outlined,
        labelKey: 'open_new_window',
        onTap: _openNewWindow,
      ),
  ];
}

void _openHistory() => Get.toNamed(RoutePath.kHistory);
void _openToolbox() => Get.toNamed(RoutePath.kToolbox);
void _openBackup() => Get.toNamed(RoutePath.kBackup);
void _openAbout() => Get.toNamed(RoutePath.kAbout);
void _openSettings() => Get.toNamed(RoutePath.kSettings);

Future<void> _openNewWindow() async {
  try {
    await WindowsMultiInstanceLauncher.launch();
  } catch (_) {
    ToastUtil.show(i18n('open_new_window_failed'));
  }
}
