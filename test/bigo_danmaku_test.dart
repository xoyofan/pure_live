import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/shared/platforms/bigo/bigo_danmaku.dart';

void main() {
  group('BigoDanmaku 协议纯函数', () {
    test('challenge 应答体含 MD5 签名(固定时间戳确定性)', () {
      final body = BigoDanmaku.challengeBody('abcdefgh12345678', timestampSec: '1690000000');
      expect(body['timeStamp'], '1690000000');
      expect(body['appId'], '60');
      final sign = body['sign'] as String;
      expect(sign, matches(RegExp(r'^[0-9a-f]{32}$')));
      // 确定性:同 challenge+时间戳签名一致
      final again = BigoDanmaku.challengeBody('abcdefgh12345678', timestampSec: '1690000000');
      expect(again['sign'], sign);
    });

    test('eid 帧坏 content 安全返回空', () {
      expect(
        BigoDanmaku.parseNormalText({
          'payload': {'tag': 1, 'uid': '9', 'content': 'not-base64-json'},
        }),
        isEmpty,
      );
    });

    test('2584 tag1 聊天解码', () {
      // base64(JSON) of {"n":"nick甲","m":"晚上好"}
      final content = base64Encode(utf8.encode('{"n":"nick甲","m":"晚上好"}'));
      final messages = BigoDanmaku.parseNormalText({
        'payload': {'tag': 1, 'uid': '7', 'content': content},
      });
      expect(messages, hasLength(1));
      expect(messages.single.userName, 'nick甲');
      expect(messages.single.message, '晚上好');
    });

    test('2584 tag6 礼物与坏 content 忽略', () {
      final content = base64Encode(utf8.encode('{"n":"u","m":"gift"}'));
      expect(
        BigoDanmaku.parseNormalText({
          'payload': {'tag': 6, 'content': content},
        }),
        isEmpty,
      );
      expect(
        BigoDanmaku.parseNormalText({
          'payload': {'tag': 1, 'content': '!!!'},
        }),
        isEmpty,
      );
      expect(BigoDanmaku.parseNormalText({}), isEmpty);
    });
  });

  group('BigoDanmakuArgs 序列化', () {
    test('toJson/fromJson 往返', () {
      final args = BigoDanmakuArgs(siteId: '80104', roomId: '123456');
      final restored = BigoDanmakuArgs.fromJson(args.toJson());
      expect(restored.siteId, args.siteId);
      expect(restored.roomId, args.roomId);
    });
  });
}
