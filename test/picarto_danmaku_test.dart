import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/shared/platforms/picarto/picarto_danmaku.dart';

void main() {
  group('PicartoDanmaku.parseFrame(chat 批次帧)', () {
    test('t=c 批次解析为聊天消息', () {
      const frame =
          '{"t":"c","m":[{"t":"c","c":"123","rn":"somechannel","u":"9","n":"画师粉丝","m":"hello!","k":"#fff","d":1690000000000}]}';
      final messages = PicartoDanmaku.parseFrame(frame);
      expect(messages, hasLength(1));
      expect(messages.single.type, LiveMessageType.chat);
      expect(messages.single.userName, '画师粉丝');
      expect(messages.single.message, 'hello!');
    });

    test('channelName 过滤其他频道条目', () {
      const frame = '{"t":"c","m":[{"t":"c","rn":"a","n":"u1","m":"for a"},{"t":"c","rn":"b","n":"u2","m":"for b"}]}';
      final filtered = PicartoDanmaku.parseFrame(frame, channelName: 'a');
      expect(filtered, hasLength(1));
      expect(filtered.single.message, 'for a');
    });

    test('非聊天事件(nk/ns/nf)与坏 JSON 忽略', () {
      expect(PicartoDanmaku.parseFrame('{"t":"nk","m":[]}'), isEmpty);
      expect(PicartoDanmaku.parseFrame('garbage'), isEmpty);
      expect(PicartoDanmaku.parseFrame('{"t":"c","m":[{"t":"nk","n":"x","m":"donated"}]}'), isEmpty);
    });

    test('空文本条目跳过', () {
      expect(PicartoDanmaku.parseFrame('{"t":"c","m":[{"t":"c","rn":"a","n":"u","m":" "}]}'), isEmpty);
    });
  });

  group('PicartoDanmakuArgs 序列化', () {
    test('toJson/fromJson 往返', () {
      final args = PicartoDanmakuArgs(channelName: 'somechannel', jwt: 'jwt-token');
      final restored = PicartoDanmakuArgs.fromJson(args.toJson());
      expect(restored.channelName, args.channelName);
      expect(restored.jwt, args.jwt);
    });
  });
}
