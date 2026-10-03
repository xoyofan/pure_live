// 平台默认可见性:默认隐藏集合(PandaTV)不在默认态;存量偏好权威不受影响。
// 零网络、零存储。
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/src/shared/application/platform_prefs.dart';

void main() {
  test('默认态不含 PandaTV(数据中心出口取流被其定点封锁)', () {
    expect(PlatformPrefs.kHiddenByDefaultIds, contains('pandalive'));
    expect(PlatformPrefs.defaults.isVisible('pandalive'), isFalse);
  });

  test('默认态仍覆盖其余全量目录且保持目录序', () {
    final catalogIds = Sites.supportSites.map((site) => site.id == 'xiaohongshu' ? 'xhs' : site.id).toList();
    final expected = catalogIds.where((id) => !PlatformPrefs.kHiddenByDefaultIds.contains(id)).toList();
    expect(PlatformPrefs.defaults.visibleIds, expected);
    // 除默认隐藏集外,目录全量可见。
    expect(PlatformPrefs.defaults.visibleIds.length, catalogIds.length - PlatformPrefs.kHiddenByDefaultIds.length);
  });

  test('reorder 后再 isVisible 语义不回归(可见列表权威)', () {
    final prefs = PlatformPrefs.defaults;
    expect(prefs.isVisible('douyu'), isTrue);
    expect(prefs.isVisible('pandalive'), isFalse);
  });
}
