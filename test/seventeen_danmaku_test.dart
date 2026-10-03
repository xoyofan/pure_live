import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/shared/platforms/seventeenlive/seventeen_danmaku.dart';

void main() {
  group('SeventeenDanmaku.parseFrame(Ably action15 信封)', () {
    Uint8List gzipOf(Map<String, Object?> json) => Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(json))));

    test('type3 commentMsg 解码为聊天消息(实测 gzip 载荷形态)', () {
      final data = base64.encode(
        gzipOf({
          'type': 3,
          'content': 'はじめまして!',
          'displayUser': {'userID': 'u-1', 'displayName': '視聴者さん'},
        }),
      );
      final frame = jsonEncode({
        'action': 15,
        'channel': '26411787',
        'messages': [
          {'id': 'm1', 'data': data},
        ],
      });
      final messages = SeventeenDanmaku.parseFrame(frame);
      expect(messages, hasLength(1));
      expect(messages.single.type, LiveMessageType.chat);
      expect(messages.single.userName, '視聴者さん');
      expect(messages.single.message, 'はじめまして!');
    });

    test('type38 在线人数/type18 进场忽略(实测帧均为非 3)', () {
      final viewers = base64.encode(
        gzipOf({
          'type': 38,
          'liveinfo': {'liveViewerCount': 9},
        }),
      );
      final enter = base64.encode(gzipOf({'type': 18, 'content': 'entered'}));
      expect(
        SeventeenDanmaku.parseFrame(
          jsonEncode({
            'action': 15,
            'messages': [
              {'data': viewers},
            ],
          }),
        ),
        isEmpty,
      );
      expect(
        SeventeenDanmaku.parseFrame(
          jsonEncode({
            'action': 15,
            'messages': [
              {'data': enter},
            ],
          }),
        ),
        isEmpty,
      );
    });

    test('非 action15 帧(ATTACHED 11/心跳 0)忽略', () {
      expect(SeventeenDanmaku.parseFrame('{"action":11,"channel":"x"}'), isEmpty);
      expect(SeventeenDanmaku.parseFrame('{"action":0}'), isEmpty);
      expect(SeventeenDanmaku.parseFrame('garbage'), isEmpty);
    });

    test('明文 JSON 载荷(未压缩形态)也支持', () {
      final data = base64.encode(
        utf8.encode(
          jsonEncode({
            'type': 3,
            'content': 'plain',
            'displayUser': {'displayName': 'u'},
          }),
        ),
      );
      final messages = SeventeenDanmaku.parseFrame(
        jsonEncode({
          'action': 15,
          'messages': [
            {'data': data},
          ],
        }),
      );
      expect(messages.single.message, 'plain');
    });
  });

  group('SeventeenDanmakuArgs 序列化', () {
    test('toJson/fromJson 往返', () {
      final args = SeventeenDanmakuArgs(liveStreamID: '26411787');
      final restored = SeventeenDanmakuArgs.fromJson(args.toJson());
      expect(restored.liveStreamID, args.liveStreamID);
    });
  });
}
