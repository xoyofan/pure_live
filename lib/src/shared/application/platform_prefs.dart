import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_parser/live_parser.dart';
import 'package:pure_live/core/sites.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 平台条目:从 pure_live Sites.supportSites 投影,加图标路径与分类徽标。
class PlatformEntry {
  const PlatformEntry({
    required this.id,
    required this.name,
    required this.logo,
  });

  final String id;
  final String name;
  final String logo;
}

/// 用户偏好:可见平台(id 有序列表)+ 隐藏集合。localStorage 持久化。
class PlatformPrefs {
  const PlatformPrefs({required this.visibleIds});
  final List<String> visibleIds;

  static const PlatformPrefs defaults = PlatformPrefs(visibleIds: []);
}

final platformCatalogProvider = Provider<List<PlatformEntry>>((ref) {
  return [
    for (final site in Sites.supportSites)
      PlatformEntry(id: site.id, name: site.name, logo: site.logo),
  ];
});

const String _kVisibleIds = 'purelive.platform.visibleIds.v1';

Future<PlatformPrefs> loadPlatformPrefs() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kVisibleIds);
    if (list == null || list.isEmpty) return PlatformPrefs.defaults;
    // 只保留有效 id,按用户排序。
    final all = Sites.supportSites.map((s) => s.id).toSet();
    return PlatformPrefs(
      visibleIds: list.where((id) => all.contains(id)).toList(),
    );
  } catch (_) {
    return PlatformPrefs.defaults;
  }
}

Future<void> savePlatformPrefs(List<String> visibleIds) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kVisibleIds, visibleIds);
  } catch (_) {}
}
