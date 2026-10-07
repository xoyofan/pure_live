import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/src/shared/application/purelive_line_format.dart';
import 'package:pure_live/src/shared/application/purelive_backend.dart' show pureliveDeclaredIngest;
import 'package:pure_live/shared/platforms/live_site.dart' show LiveStreamFacts, LiveStreamFormat;

/// 线路格式判定契约:签名 query 不得吞掉 path 后缀(2026-10-02 猫耳全档
/// 起播失败根因——HLS 带 `?sign=…` 被整串 endsWith 误判成 flv,进而被包进
/// FLV 专用本地代理,m3u8 文本当 FLV 喂 mpv、分片 404)。
void main() {
  group('pureLiveLineFormat(桥接层线路格式判定)', () {
    test('带签名 query 的 m3u8 识别为 hls(猫耳 HLS)', () {
      const url =
          'https://d1-missevan104.bilivideo.com/live-bvc/821625/maoer_14833815_868888435.m3u8'
          '?cdn=missevan104&oi=1972919680&pt=web&expires=1790940484&sign=a51e1c2d';
      expect(pureLiveLineFormat(url), 'hls');
    });

    test('带 wsSecret query 的 flv 识别为 flv(虎牙)', () {
      const url =
          'https://hw.flv.huya.com/src/1394833162-1394833162-5996925477007155200.flv'
          '?wsSecret=abc&wsTime=687d0c3d';
      expect(pureLiveLineFormat(url), 'flv');
    });

    test('Twitcasting 带签名 m3u8 识别为 hls', () {
      const url = 'https://203-137-131-19.twitcasting.tv/nilou_443/chunklist.m3u8?twccdn=411';
      expect(pureLiveLineFormat(url), 'hls');
    });

    test('rtmp/rtmps 直链单独归类(不落入 flv 被包进本地流代理)', () {
      expect(pureLiveLineFormat('rtmp://tencent-global-pull-rtmp.17app.co/live/123456'), 'rtmp');
      expect(pureLiveLineFormat('rtmps://pull.example.com/live/key'), 'rtmp');
    });

    test('无 query 的裸路径后缀仍生效', () {
      expect(pureLiveLineFormat('https://cdn.example.com/live/index.m3u8'), 'hls');
      expect(pureLiveLineFormat('https://cdn.example.com/live/index.flv'), 'flv');
    });

    test('大小写不敏感(上游大写扩展名)', () {
      expect(pureLiveLineFormat('https://cdn.example.com/live/INDEX.M3U8'), 'hls');
    });
  });

  group('pureliveDeclaredIngest(上游 LiveStreamFacts 声明桥接)', () {
    test('未声明 → null(播放层按清单实测兜底)', () {
      expect(pureliveDeclaredIngest(null), isNull);
    });

    test('声明 HLS 且子行需解析 → relay(零探测直接起中继)', () {
      const facts = (format: LiveStreamFormat.hls, codec: null, unresolvedChildren: true);
      expect(pureliveDeclaredIngest(facts), 'relay');
    });

    test('声明 HLS 子行完整 / 声明 other → direct(零探测直通)', () {
      const hls = (format: LiveStreamFormat.hls, codec: null, unresolvedChildren: false);
      const other = (format: LiveStreamFormat.other, codec: null, unresolvedChildren: false);
      expect(pureliveDeclaredIngest(hls), 'direct');
      expect(pureliveDeclaredIngest(other), 'direct');
    });
  });
}
