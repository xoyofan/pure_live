import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/shared/platforms/missevan/missevan_danmaku.dart';

void main() {
  group('MissevanDanmaku.parseFrame(im 网关 JSON 帧)', () {
    test('message/new 帧解析为聊天消息', () {
      const frame =
          '{"type":"message","event":"new","room_id":869125333,'
          '"message":{"message":"今晚播什么"},"msg_id":"m1",'
          '"user":{"user_id":42,"username":"听众甲","iconurl":"https://x/y.png"}}';
      final messages = MissevanDanmaku.parseFrame(frame);
      expect(messages, hasLength(1));
      expect(messages.single.type, LiveMessageType.chat);
      expect(messages.single.userName, '听众甲');
      expect(messages.single.message, '今晚播什么');
    });

    test('礼物/进场/统计等非 message·new 帧忽略', () {
      expect(MissevanDanmaku.parseFrame('{"type":"gift","event":"send"}'), isEmpty);
      expect(MissevanDanmaku.parseFrame('{"type":"member","event":"join"}'), isEmpty);
      expect(MissevanDanmaku.parseFrame('{"type":"message","event":"leave"}'), isEmpty);
    });

    test('服务端心跳 ❤️ 与坏 JSON 忽略', () {
      expect(MissevanDanmaku.parseFrame('❤️'), isEmpty);
      expect(MissevanDanmaku.parseFrame('not json'), isEmpty);
    });

    test('空文本评论跳过, user 缺失时用户名为空串', () {
      expect(MissevanDanmaku.parseFrame('{"type":"message","event":"new","message":{"message":"  "}}'), isEmpty);
      final anonymous = MissevanDanmaku.parseFrame('{"type":"message","event":"new","message":{"message":"hi"}}');
      expect(anonymous.single.userName, '');
    });
  });

  group('MissevanDanmakuArgs 序列化', () {
    test('toJson/fromJson 往返', () {
      final args = MissevanDanmakuArgs(roomId: '869125333');
      final restored = MissevanDanmakuArgs.fromJson(args.toJson());
      expect(restored.roomId, args.roomId);
    });
  });
}
