import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/shared/platforms/pandalive/pandalive_danmaku.dart';

void main() {
  group('PandaliveDanmaku.parseFrame(Centrifugo pub 帧)', () {
    test('push.pub.data 聊天解析', () {
      const frame = '{"push":{"channel":"12345","pub":{"data":{"userNick":"한국팬","message":"안녕하세요","time":"12:00"}}}}';
      final messages = PandaliveDanmaku.parseFrame(frame);
      expect(messages, hasLength(1));
      expect(messages.single.type, LiveMessageType.chat);
      expect(messages.single.userName, '한국팬');
      expect(messages.single.message, '안녕하세요');
    });

    test('message 键变体防御解析(msg/text/content)', () {
      for (final key in ['msg', 'text', 'content']) {
        final frame = '{"push":{"pub":{"data":{"nick":"u","$key":"hi"}}}}';
        final messages = PandaliveDanmaku.parseFrame(frame);
        expect(messages, hasLength(1), reason: key);
        expect(messages.single.message, 'hi');
      }
    });

    test('connect/subscribe 应答与非 pub 帧忽略', () {
      expect(PandaliveDanmaku.parseFrame('{"id":1,"connect":{}}'), isEmpty);
      expect(PandaliveDanmaku.parseFrame('{"id":2,"subscribe":{}}'), isEmpty);
      expect(PandaliveDanmaku.parseFrame('{"push":{"join":{"data":{}}}}'), isEmpty);
    });

    test('坏 JSON 与空文本忽略', () {
      expect(PandaliveDanmaku.parseFrame('not json'), isEmpty);
      expect(PandaliveDanmaku.parseFrame('{"push":{"pub":{"data":{"message":"  "}}}}'), isEmpty);
    });
  });

  group('PandaliveDanmakuArgs 序列化', () {
    test('toJson/fromJson 往返', () {
      final args = PandaliveDanmakuArgs(token: 'tok', channel: '12345');
      final restored = PandaliveDanmakuArgs.fromJson(args.toJson());
      expect(restored.token, args.token);
      expect(restored.channel, args.channel);
    });
  });
}
