import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/shared/platforms/twitcasting/twitcasting_danmaku.dart';

void main() {
  group('TwitcastingDanmaku.parseFrame(pubsub 评论帧)', () {
    test('评论数组解析为聊天消息', () {
      const frame = '[{"message":"Hello World!","from_user":{"name":"TestUser","id":"123"}}]';
      final messages = TwitcastingDanmaku.parseFrame(frame);
      expect(messages, hasLength(1));
      expect(messages.single.type, LiveMessageType.chat);
      expect(messages.single.userName, 'TestUser');
      expect(messages.single.message, 'Hello World!');
    });

    test('首帧空数组返回空列表(连接成功即发 [])', () {
      expect(TwitcastingDanmaku.parseFrame('[]'), isEmpty);
    });

    test('多行多评论帧逐条解析', () {
      const frame = '[{"message":"First"}]\n[{"message":"Second"},{"message":"Third","from_user":{"name":"u"}}]';
      final messages = TwitcastingDanmaku.parseFrame(frame);
      expect(messages, hasLength(3));
      expect(messages[0].userName, '');
      expect(messages[2].userName, 'u');
    });

    test('非评论控制帧/坏 JSON 忽略', () {
      expect(TwitcastingDanmaku.parseFrame('{"connected":true}'), isEmpty);
      expect(TwitcastingDanmaku.parseFrame('garbage'), isEmpty);
      expect(TwitcastingDanmaku.parseFrame('[{"from_user":{"name":"x"}}]'), isEmpty);
    });
  });

  group('TwitcastingDanmakuArgs 序列化', () {
    test('toJson/fromJson 往返', () {
      final args = TwitcastingDanmakuArgs(movieId: '841706370', password: 'pw');
      final restored = TwitcastingDanmakuArgs.fromJson(args.toJson());
      expect(restored.movieId, args.movieId);
      expect(restored.password, args.password);
    });
  });
}
