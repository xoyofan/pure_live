import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/src/app/app_router.dart';

/// 启动路由/搜索入口的 URL 平台推断表:域名命中即给平台,不命中回空串
/// (纯数字房间号/别名不做联网探测)。猫耳 2026-10-02 真机验证时发现
/// `--room https://fm.missevan.com/live/N` 因表缺猫耳域名静默回落首页。
void main() {
  group('siteHintFromInput(URL 平台推断)', () {
    test('猫耳直播间 URL 推断为 missevan', () {
      expect(siteHintFromInput('https://fm.missevan.com/live/868888435'), 'missevan');
      expect(siteHintFromInput('http://fm.missevan.com/live/123'), 'missevan');
    });

    test('niconico 观察页 URL 推断为 niconico', () {
      expect(siteHintFromInput('https://live.nicovideo.jp/watch/lv351393299'), 'niconico');
    });

    test('既有头部平台域名不回归', () {
      expect(siteHintFromInput('https://www.douyu.com/8682569'), 'douyu');
      expect(siteHintFromInput('https://live.bilibili.com/1'), 'bilibili');
      expect(siteHintFromInput('https://www.twitch.tv/jinnytty'), 'twitch');
      expect(siteHintFromInput('https://17.live/en/live/29725277'), '17live');
    });

    test('纯房间号/未知域名返回空串(不做联网探测)', () {
      expect(siteHintFromInput('868888435'), '');
      expect(siteHintFromInput('https://example.com/live/1'), '');
      expect(siteHintFromInput(''), '');
    });
  });
}
