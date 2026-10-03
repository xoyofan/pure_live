import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/shared/platforms/fc2live/fc2_danmaku.dart';

void main() {
  group('Fc2Danmaku.parseFrame(控制 socket comment 帧)', () {
    test('comment 批次解析为聊天消息', () {
      const frame =
          '{"name":"comment","arguments":{"comments":[{"user_name":"观众A","comment":"こんばんは","timestamp":1690000000},'
          '{"user_name":"观众B","comment":"hello","timestamp":1690000001}]}}';
      final messages = Fc2Danmaku.parseFrame(frame);
      expect(messages, hasLength(2));
      expect(messages.first.userName, '观众A');
      expect(messages.first.message, 'こんばんは');
      expect(messages.last.message, 'hello');
    });

    test('control 其他帧(connect_complete/hls 响应)忽略', () {
      expect(Fc2Danmaku.parseFrame('{"name":"connect_complete","arguments":{}}'), isEmpty);
      expect(Fc2Danmaku.parseFrame('{"name":"_response_","id":1,"arguments":{}}'), isEmpty);
      expect(Fc2Danmaku.parseFrame('{"name":"heartbeat","arguments":{},"id":2}'), isEmpty);
    });

    test('坏 JSON 与空评论忽略', () {
      expect(Fc2Danmaku.parseFrame('not json'), isEmpty);
      expect(
        Fc2Danmaku.parseFrame('{"name":"comment","arguments":{"comments":[{"user_name":"a","comment":" "}]}}'),
        isEmpty,
      );
    });
  });

  group('Fc2DanmakuArgs 序列化', () {
    test('toJson/fromJson 往返', () {
      final args = Fc2DanmakuArgs(channelId: '12345678');
      final restored = Fc2DanmakuArgs.fromJson(args.toJson());
      expect(restored.channelId, args.channelId);
    });
  });
}
