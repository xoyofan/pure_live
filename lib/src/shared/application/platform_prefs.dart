/// 平台可见/排序偏好:目录来自 pure_live `Sites.supportSites`(id/name/logo),
/// 用户在设置对话框「平台」分区里隐藏平台、上下移动排序;顶栏平台 tab、
/// 侧栏平台块与浏览路由守卫共用同一份可见列表。
///
/// 持久化:SharedPreferencesAsync 存**可见平台 id 的有序列表**(顺序即展示
/// 次序)。默认全部可见,按 lib/core/sites.dart `_supportedSites` 的目录序;
/// 读盘失败/存量非法项静默丢弃。注意存量只含「可见」id:pure_live 未来新增
/// 的平台不会自动出现,需用户在设置里手动开启。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../presentation/platform_brands.dart';

/// 平台条目:从 pure_live [Sites.supportSites] 投影。
///
/// [logo] 是 `assets/images/*.png`(pure_live 站点素材),顶栏/侧栏/设置行
/// 用 `Image.asset` 直读;`assets/ui/platform-icons/` 只覆盖 9 个平台,盖不住
/// 全量目录,文字字形兜底不再适用。
class PlatformEntry {
  const PlatformEntry({required this.id, required this.name, required this.logo});

  final String id;
  final String name;
  final String logo;
}

/// 平台偏好状态:可见平台 id 的有序列表(不在列表里 = 隐藏)。
///
/// id 一律是 **zishu 契约 id**([_catalogId] 归一后),与品牌目录/路由一致。
class PlatformPrefs {
  const PlatformPrefs({required this.visibleIds});

  /// 可见平台 id,顺序即顶栏/侧栏的展示次序。
  final List<String> visibleIds;

  /// 默认态:全部可见,按 pure_live `_supportedSites` 目录序。
  static final PlatformPrefs defaults = PlatformPrefs(
    visibleIds: [for (final site in Sites.supportSites) _catalogId(site.id)],
  );

  /// 目录内的全量契约 id(校验存量/入参用)。
  static final Set<String> allIds = Sites.supportSites.map((site) => _catalogId(site.id)).toSet();

  bool isVisible(String id) => visibleIds.contains(id);
}

/// pure_live 站点 id → zishu 契约 id 别名。品牌目录(platform_brands)与
/// 路由守卫(`/:site` 的 supportsBrowse)都只按契约 id 寻址;小红书在
/// pure_live 侧是 `xiaohongshu`(lib/core/common/site_ids.dart:24),zishu
/// 侧是 `xhs` —— 投影时必须归一,否则入口点上去被守卫弹回 /all 成死入口;
/// 存量偏好里已写入的旧 id 由 [_sanitize] 走同一映射迁移。
const Map<String, String> _kCatalogIdAlias = {'xiaohongshu': 'xhs'};

/// 取站点在 zishu 契约下的 id(无别名时原样返回)。
String _catalogId(String siteId) => _kCatalogIdAlias[siteId] ?? siteId;

/// 全量平台目录(`_supportedSites` 顺序投影),设置「平台」分区的行来源。
final platformCatalogProvider = Provider<List<PlatformEntry>>((ref) {
  return [
    for (final site in Sites.supportSites)
      PlatformEntry(id: _catalogId(site.id), name: _siteName(site), logo: site.logo),
  ];
});

/// 显示名:优先取 zishu 平台色表的中文条目(真源,含未上 pure_live 名的
/// 各站);pure_live 侧的 `site.name` 走 easy_localization,而 zishu 入口
/// 未初始化它(i18n 键会原样返回),只在色表未收录时兜底,再退 id。
String _siteName(Site site) {
  final branded = PlatformBrandCatalog.byId(_catalogId(site.id))?.name;
  if (branded != null) return branded;
  // 未初始化 easy_localization 时 i18n 键会原样返回,此时退 id 而非裸键。
  final name = site.name;
  return name.startsWith('site_') ? site.id : name;
}

/// 平台可见/排序偏好控制器:同步内存态 + 异步恢复/持久化。
///
/// 启动先以默认态(全可见)渲染,读盘完成后无缝替换 —— 与
/// sidebar_pref_provider 同一套路,UI 与路由守卫都不必等异步结果。
class PlatformPrefsController extends Notifier<PlatformPrefs> {
  /// SharedPreferencesAsync 存储键(带前缀与模块名避免冲突)。
  static const String _kVisibleIds = 'zishu.platform.visibleIds.v1';

  @override
  PlatformPrefs build() {
    // 启动时异步恢复;完成前 UI 先使用默认值(全可见)。
    Future<void>.microtask(_restore);
    return PlatformPrefs.defaults;
  }

  /// 从本地存储恢复:只保留有效 id、去重、按用户次序;空列表同样是合法
  /// 存量(用户隐藏了全部平台),不得回退默认。
  Future<void> _restore() async {
    try {
      final stored = await SharedPreferencesAsync().getStringList(_kVisibleIds);
      if (stored == null) return;
      state = PlatformPrefs(visibleIds: _sanitize(stored));
    } catch (_) {
      // 平台存储不可用等异常:保持默认(全可见),页面不崩溃。
    }
  }

  /// 设置单个平台可见性。
  ///
  /// 重新显示时按目录序插回(落在同类平台旁,次序稳定可预期)。
  Future<void> setVisibility(String id, bool visible) async {
    if (!PlatformPrefs.allIds.contains(id)) return;
    if (visible) {
      if (state.isVisible(id)) return;
      final ids = [...state.visibleIds];
      ids.insert(_catalogInsertIndex(ids, id), id);
      _update(ids);
    } else {
      if (!state.isVisible(id)) return;
      _update([
        for (final visibleId in state.visibleIds)
          if (visibleId != id) visibleId,
      ]);
    }
  }

  /// 用给定次序整体替换可见列表(非法/重复 id 丢弃)。
  Future<void> reorder(List<String> orderedIds) async {
    _update(_sanitize(orderedIds));
  }

  /// 目录序插入位置:第一个目录位次比 [id] 靠后的可见项之前,没有则末尾。
  int _catalogInsertIndex(List<String> ids, String id) {
    final catalogIds = [for (final site in Sites.supportSites) _catalogId(site.id)];
    final target = catalogIds.indexOf(id);
    for (var i = 0; i < ids.length; i++) {
      if (catalogIds.indexOf(ids[i]) > target) return i;
    }
    return ids.length;
  }

  /// 归一化(契约 id 别名迁移)+ 只保留有效 id + 按首次出现去重。
  List<String> _sanitize(Iterable<String> ids) {
    final seen = <String>{};
    final result = <String>[];
    for (final rawId in ids) {
      final id = _catalogId(rawId);
      if (PlatformPrefs.allIds.contains(id) && seen.add(id)) {
        result.add(id);
      }
    }
    return result;
  }

  /// 先改内存态(UI 即时生效),再落盘;写盘失败不影响本次会话。
  void _update(List<String> ids) {
    state = PlatformPrefs(visibleIds: List.unmodifiable(ids));
    unawaited(_persist());
  }

  Future<void> _persist() async {
    try {
      await SharedPreferencesAsync().setStringList(_kVisibleIds, state.visibleIds);
    } catch (_) {
      // 写盘失败:下次启动回旧值。
    }
  }
}

/// 平台偏好 provider(默认全可见,读盘后为用户次序)。
final platformPrefsProvider = NotifierProvider<PlatformPrefsController, PlatformPrefs>(PlatformPrefsController.new);

/// 当前**可见**平台(按用户次序):设置「平台」分区开关/排序的直接投影。
final visiblePlatformsProvider = Provider<List<PlatformEntry>>((ref) {
  final catalog = ref.watch(platformCatalogProvider);
  final visibleIds = ref.watch(platformPrefsProvider).visibleIds;
  final byId = {for (final entry in catalog) entry.id: entry};
  return [
    for (final id in visibleIds)
      if (byId[id] != null) byId[id]!,
  ];
});

/// 导航入口清单:「全平台」固定首位 + 用户可见平台。顶栏平台 tab、手机
/// 平台条与侧栏平台块**共用**这一个 provider,设置里的隐藏/排序三处同步。
final navigationPlatformsProvider = Provider<List<PlatformEntry>>(
  (ref) => [const PlatformEntry(id: 'all', name: '全平台', logo: ''), ...ref.watch(visiblePlatformsProvider)],
);
