// 迭代16:CategoryController 瞬态失败自动重试(一次)单测。
//
// 站点目录接口偶发抖动(灰度页/边缘重置)不应把 hover 浮层缓存成常驻错误:
// 第一次失败 → 延迟重试 → 成功;持续失败 → 重试恰好一次后进错误态。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_parser/live_parser.dart';
import 'package:pure_live/src/features/browse/application/browse_provider.dart';
import 'package:pure_live/src/shared/application/browse_source.dart';
import 'package:pure_live/src/shared/application/providers.dart';

class _FlakySource implements BrowseSource {
  _FlakySource(this.failTimes);

  final int failTimes;
  int calls = 0;

  @override
  Future<CategoryResult> fetchCategories(String site) async {
    calls++;
    if (calls <= failTimes) throw StateError('transient-$calls');
    return CategoryResult(site: site, groups: const []);
  }

  @override
  Future<RoomListResult> fetchRooms({required String site, String? cid, int page = 1, int? limit}) async {
    return RoomListResult(rooms: const [], page: page, hasMore: false);
  }
}

void main() {
  test('首次失败后自动重试一次并成功', () async {
    final source = _FlakySource(1);
    final container = ProviderContainer(overrides: [browseSourceProvider.overrideWithValue(source)]);
    addTearDown(container.dispose);

    final result = await container.read(browseCategoriesProvider('twitch').future);
    expect(result.site, 'twitch');
    expect(source.calls, 2, reason: '失败 1 次 + 重试 1 次');
  });

  test('持续失败时只重试一次,随后进错误态', () async {
    final source = _FlakySource(99);
    final container = ProviderContainer(overrides: [browseSourceProvider.overrideWithValue(source)]);
    addTearDown(container.dispose);

    await expectLater(container.read(browseCategoriesProvider('soop').future), throwsA(isA<StateError>()));
    expect(source.calls, 2, reason: '不无限重试');
  });
}
