import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/shared/platforms/showroom/showroom_danmaku.dart';

void main() {
  group('ShowroomDanmaku.parseFrame(实测协议帧)', () {
    // 探针实测帧(2026-10-01, wss://online.showroom-live.com/ SUB/MSG 协议)。
    const capturedComment =
        'MSG\t6f6975526b71637a:23500697\t{"t":1,"u":3547417,"ac":"アル","av":1022604,'
        '"cm":"4本目？","d":0,"at":0,"ua":3,"aft":4,"cl":39,'
        '"cifn":"87adbb8d960399045b3510dc62e55d1c.png","cbisc":"#158DE8",'
        '"cbiec":"#7B4FFF","created_at":1790873492}';

    test('MSG 评论帧解析为聊天消息', () {
      final message = ShowroomDanmaku.parseFrame(capturedComment);
      expect(message, isNotNull);
      expect(message!.type, LiveMessageType.chat);
      expect(message.userName, 'アル');
      expect(message.message, '4本目？');
    });

    test('MSG 礼物帧(t=2)不当作聊天', () {
      const gift =
          'MSG\t6f6975526b71637a:23500697\t'
          '{"ua":3,"n":1,"av":1,"d":0,"ac":"昵称","created_at":1790873492,"u":1,"h":1,"g":123,"gt":2,"at":0,"t":"2"}';
      expect(ShowroomDanmaku.parseFrame(gift), isNull);
    });

    test('ACK 订阅应答与非 MSG 帧忽略', () {
      expect(ShowroomDanmaku.parseFrame('ACK\tshowroom'), isNull);
      expect(ShowroomDanmaku.parseFrame('Could not decode a text frame as UTF-8.'), isNull);
    });

    test('坏 JSON / 空 cm / 缺帧头返回 null', () {
      expect(ShowroomDanmaku.parseFrame('MSG\tkey\t{not json'), isNull);
      expect(ShowroomDanmaku.parseFrame('MSG\tkey\t{"t":1,"ac":"a","cm":"  "}'), isNull);
      expect(ShowroomDanmaku.parseFrame('MSG\tkey-without-payload'), isNull);
    });
  });

  group('ShowroomDanmakuArgs 序列化', () {
    test('toJson/fromJson 往返', () {
      final args = ShowroomDanmakuArgs(host: 'online.showroom-live.com', port: 8080, key: 'ab12cd34:12345678');
      final restored = ShowroomDanmakuArgs.fromJson(args.toJson());
      expect(restored.host, args.host);
      expect(restored.port, args.port);
      expect(restored.key, args.key);
    });
  });
}
