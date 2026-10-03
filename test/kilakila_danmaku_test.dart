import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/shared/platforms/kilakila/kilakila_danmaku.dart';

void main() {
  group('KilakilaDanmaku.parseRows(latestQuery 行)', () {
    test('评论行解析为聊天消息并按 relativeTime 去重', () {
      final rows = [
        {
          'roomId': 2270573219083714676,
          'relativeTime': 859060,
          'bizType': 1,
          'content': jsonEncode({'nickname': '听众A', 'content': '晚上好'}),
        },
        {
          'roomId': 2270573219083714676,
          'relativeTime': 859060,
          'bizType': 1,
          'content': jsonEncode({'nickname': '听众A', 'content': '晚上好'}),
        },
      ];
      final seen = <String>{};
      final messages = KilakilaDanmaku.parseRows(rows, seenKeys: seen);
      expect(messages, hasLength(1));
      expect(messages.single.userName, '听众A');
      expect(messages.single.message, '晚上好');

      // 轮询去重: 同键行再次出现不再回调。
      final repeat = KilakilaDanmaku.parseRows([rows.first], seenKeys: seen);
      expect(repeat, isEmpty);
    });

    test('bizType2 问答卡无顶级昵称/文本键, 天然过滤', () {
      final rows = [
        {
          'relativeTime': 859061,
          'bizType': 2,
          'content': jsonEncode({'answerNickname': '主播', 'questionNickname': '01', 'question': '困了'}),
        },
      ];
      expect(KilakilaDanmaku.parseRows(rows), isEmpty);
    });

    test('坏信封/坏 JSON/空文本忽略', () {
      expect(KilakilaDanmaku.envelopeRows('not json'), isNull);
      expect(
        KilakilaDanmaku.envelopeRows({
          'h': {'code': 1},
        }),
        isNull,
      );
      expect(
        KilakilaDanmaku.parseRows([
          {'relativeTime': 1, 'content': 'not json'},
        ]),
        isEmpty,
      );
      expect(
        KilakilaDanmaku.parseRows([
          {
            'relativeTime': 1,
            'content': jsonEncode({'nickname': 'a'}),
          },
        ]),
        isEmpty,
      );
    });
  });

  group('KilakilaDanmakuArgs 序列化', () {
    test('toJson/fromJson 往返', () {
      final args = KilakilaDanmakuArgs(roomId: '2270573219083714676');
      final restored = KilakilaDanmakuArgs.fromJson(args.toJson());
      expect(restored.roomId, args.roomId);
    });
  });
}
