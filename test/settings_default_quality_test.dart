import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/src/features/follow/application/settings_provider.dart';

SettingsState _settings({Map<String, String> bySite = const {}}) {
  return SettingsState(
    themeMode: ThemeModeChoice.dark,
    defaultQuality: '最高',
    danmakuEnabled: true,
    chatEnabled: true,
    preferredLineFormat: PreferredLineFormat.auto,
    serverUrl: SettingsState.defaultServerUrl,
    defaultQualityBySite: bySite,
  );
}

void main() {
  group('effectiveDefaultQuality(默认全平台最高档,2026-10-02 用户口径)', () {
    test('未单独配置的平台(含原低档提速平台)一律回落「最高」', () {
      final settings = _settings();
      for (final site in ['douyu', 'huya', 'bilibili', 'douyin', 'kuaishou', 'soop', 'twitch', 'youtube', 'yy']) {
        expect(settings.effectiveDefaultQuality(site), '最高', reason: site);
      }
    });

    test('用户显式的平台单独配置仍然优先', () {
      final settings = _settings(bySite: {'twitch': '720p'});
      expect(settings.effectiveDefaultQuality('twitch'), '720p');
      expect(settings.effectiveDefaultQuality('douyu'), '最高');
    });

    test('「最高」在全局画质候选内(设置下拉/持久化校验可用)', () {
      expect(SettingsState.qualityOptions.first, '最高');
    });

    test('平台强制默认档已清空(原 soop/twitch/youtube 低档条目移除)', () {
      expect(SettingsState.platformDefaultQuality, isEmpty);
    });
  });
}
