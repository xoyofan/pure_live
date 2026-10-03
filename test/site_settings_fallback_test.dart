import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/shared/platforms/soop/soop_site.dart';
import 'package:pure_live/shared/platforms/twitch/twitch_site.dart';
import 'package:pure_live/shared/platforms/yy/yy_site.dart';

/// 适配器在宿主未注册 GetX `SettingsService` 时必须降级而不是整链失败:
/// cookie 视为空(游客态解析)、代理视为直连。2026-10-02 真机日志:twitch
/// 进房 resolve_fail("SettingsService" not found),zishu 播放链不初始化
/// 旧 UI 的 GetX 服务栈。
void main() {
  group('适配器在 SettingsService 未注册时降级', () {
    test('Twitch 请求头不抛异常,匿名态无 Cookie/Authorization', () {
      final site = TwitchSite();
      expect(site.getRequestHeaders, returnsNormally);
      expect(site.headers.containsKey('Cookie'), isFalse);
      expect(site.headers.containsKey('Authorization'), isFalse);
      expect(site.headers['Device-Id'], isNotEmpty);
    });

    test('SOOP 请求头 Cookie 为空串', () {
      expect(SoopSite.getHeaders, returnsNormally);
    });

    test('YY 请求头不抛异常且 Cookie 为空', () {
      final headers = YYSite().getHeaders();
      expect(headers['Cookie'] ?? '', '');
    });
  });
}
