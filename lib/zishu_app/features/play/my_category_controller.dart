import 'dart:convert';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/zishu/domain/category_display.dart';

/// 跨平台「我的分类」收藏(GetX 版),移植自 zishu_flutter
/// `lib/src/features/browse/application/my_category_provider.dart`
/// (对齐 SFVideoLive 导航「我的分类」)。
///
/// **收藏语义按跨平台分类**:「英雄联盟」是一个分类,不区分虎牙/斗鱼各自的
/// 分类号 —— 判定「已收藏」优先比较跨平台 key
/// ([crossKeyForPlatformCategory],lib/zishu/domain/category_display.dart:267,
/// 签名 `String crossKeyForPlatformCategory(String? site, String? cid, String? name)`);
/// 未命中映射表的平台私有分类退回 (site, name) 精确比较。存储仍存首次收藏时
/// 所在平台的 (site, name) 快照(展示名),不迁移旧数据。
///
/// 与真源(Riverpod + SharedPreferencesAsync)的差异按 pure_live 惯例落地:
/// - GetX:[GetxController] + [RxList],UI 侧 `Obx` 直读 [categories];
/// - 持久化:Hive 设置盒([HivePrefUtil]),存 JSON 字符串;`getAnyPref`
///   是同步读,故 onInit 恢复即完成,不存在真源「迟到读盘回放覆盖用户
///   动作」的竞态,无需 `_userMutated` 闩锁。
///
/// 注册方式由接线阶段决定(如 `Get.put(MyCategoryController(), permanent: true)`);
/// 本文件不主动 Get.put。
class MyCategoryController extends GetxController {
  /// 存储键(独立命名空间,与 zishu 的 `zishu.myCategories.v3` 不共用)。
  static const String storeKey = 'zishu_app.myCategories.v1';

  /// 上限:对齐 SFVideoLive `MAX_MY_CROSS_CATEGORIES`。
  static const int maxCount = 12;

  /// 收藏集合(Rx;UI 侧 Obx 直读)。
  final RxList<MyCategoryEntry> categories = <MyCategoryEntry>[].obs;

  /// `SettingsService.to` 同款快捷读取。
  static MyCategoryController get to => Get.find<MyCategoryController>();

  @override
  void onInit() {
    super.onInit();
    _restore();
  }

  /// 条目/目标的唯一 key:命中跨平台映射用 `cross|<key>`,
  /// 未命中退回 `raw|<site>|<name>`(平台私有分类)。
  /// 两段前缀保证两类 key 永不相交,对齐真源
  /// [isCategoryFavorited] 的「优先跨平台、未命中回退精确」口径。
  static String _keyOf(String site, String name) {
    final cross = crossKeyForPlatformCategory(site, '', name);
    return cross.isNotEmpty ? 'cross|$cross' : 'raw|$site|$name';
  }

  /// 是否已收藏(跨平台口径):收藏任一平台的「英雄联盟」,所有平台的
  /// 英雄联盟都算已收藏。
  bool isFavorited(String site, String categoryName) {
    final key = _keyOf(site.trim(), categoryName.trim());
    if (key == 'raw||') return false;
    return categories.any((entry) => _keyOf(entry.site, entry.name) == key);
  }

  /// 收藏/取消收藏;已达上限且是新增时返回 false(UI 侧提示)。
  /// 取消时移除**全部**同跨平台 key 的条目,新增落当前平台快照。
  Future<bool> toggle(String site, String categoryName) async {
    final entry = MyCategoryEntry(site: site.trim(), name: categoryName.trim());
    if (!entry.isValid) return false;
    final key = _keyOf(entry.site, entry.name);
    final matched = categories.where((item) => _keyOf(item.site, item.name) == key).toList(growable: false);
    if (matched.isNotEmpty) {
      categories.removeWhere((item) => _keyOf(item.site, item.name) == key);
      await _persist();
      return true;
    }
    if (categories.length >= maxCount) return false;
    categories.add(entry);
    await _persist();
    return true;
  }

  /// 启动恢复:Hive 同步读,onInit 内即完成;数据损坏保持空集合不阻塞 UI。
  void _restore() {
    try {
      final raw = HivePrefUtil.getString(storeKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final restored = <MyCategoryEntry>[
        for (final item in decoded)
          if (MyCategoryEntry.fromJson(item).isValid) MyCategoryEntry.fromJson(item),
      ];
      categories.assignAll(restored);
    } catch (_) {
      categories.clear();
    }
  }

  Future<void> _persist() async {
    try {
      final payload = jsonEncode([for (final entry in categories) entry.toJson()]);
      await HivePrefUtil.setString(storeKey, payload);
    } catch (_) {
      // 写盘失败:内存态仍生效。
    }
  }
}

/// 一条收藏分类(site + 分类名快照)。
class MyCategoryEntry {
  const MyCategoryEntry({required this.site, required this.name});

  /// 站点 id(如 huya/douyu/bilibili)。
  final String site;

  /// 分类名(收藏时刻的快照)。
  final String name;

  bool get isValid => site.isNotEmpty && name.isNotEmpty;

  Map<String, dynamic> toJson() => {'site': site, 'name': name};

  factory MyCategoryEntry.fromJson(Object? raw) {
    if (raw is! Map) {
      return const MyCategoryEntry(site: '', name: '');
    }
    return MyCategoryEntry(site: raw['site']?.toString() ?? '', name: raw['name']?.toString() ?? '');
  }
}
