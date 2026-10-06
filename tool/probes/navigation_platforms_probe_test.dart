// Opt-in 探针:首页导航平台条实际收录哪些平台(用户报告 youtube/liveme 首页无)。
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/src/shared/presentation/platform_brands.dart';

void main() {
  test('navigationPlatforms 实际内容', () {
    final ids = [for (final b in PlatformBrandCatalog.navigationPlatforms) b.id];
    // ignore: avoid_print
    print('navigationPlatforms(${ids.length}): ${ids.join(' ')}');
    // ignore: avoid_print
    print('youtube in nav: ${ids.contains('youtube')}, liveme in nav: ${ids.contains('liveme')}');
    final brand = PlatformBrandCatalog.byId('youtube');
    final liveme = PlatformBrandCatalog.byId('liveme');
    // ignore: avoid_print
    print('youtube brand browseSupported=${brand?.browseSupported}, liveme=${liveme?.browseSupported}');
  });
}
