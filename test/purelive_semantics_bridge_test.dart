// 上游语义桥接契约(2026-10-03 合并轮):开播时间直读/受限口径透传/轮播状态/
// 弹幕表情分段/撤回目标映射。零网络,纯函数。
import 'package:flutter_test/flutter_test.dart';
import 'package:live_parser/live_parser.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/src/shared/application/purelive_backend.dart';

LiveRoom _room({LiveStatus? status, LiveRestriction? restriction, Map<String, dynamic>? data, DateTime? startedAt}) {
  final room = LiveRoom(roomId: '42', platform: 'bilibili');
  room.liveStatus = status;
  room.restriction = restriction;
  room.startedAt = startedAt;
  room.data = data;
  return room;
}

LiveMessage _msg(LiveMessageType type, {String text = '', List<LiveEmote> emotes = const [], dynamic data}) {
  return LiveMessage(
    type: type,
    userName: 'u',
    message: text,
    color: LiveMessageColor.white,
    emotes: emotes,
    data: data,
  );
}

void main() {
  group('pureliveDanmakuSegmentsFromEmotes', () {
    test('编码按出现位置切分文本段与表情段,拼接与原文一致', () {
      final segments = pureliveDanmakuSegmentsFromEmotes('哈哈[笑哭]真好[干燥]啊', const [
        LiveEmote(code: '[笑哭]', url: 'https://i0.hdslb.com/x1.png'),
        LiveEmote(code: '[干燥]', url: 'https://i0.hdslb.com/x2.png'),
      ]);
      expect(segments, hasLength(5));
      expect(segments[0].type, DanmakuSegmentType.text);
      expect(segments[0].text, '哈哈');
      expect(segments[1].type, DanmakuSegmentType.emoji);
      expect(segments[1].url, 'https://i0.hdslb.com/x1.png');
      expect(segments[1].text, '[笑哭]');
      expect(segments[3].text, '[干燥]');
      expect(segments[4].text, '啊');
      expect(segments.map((s) => s.text).join(), '哈哈[笑哭]真好[干燥]啊');
    });

    test('同一编码多次出现全部分段', () {
      final segments = pureliveDanmakuSegmentsFromEmotes('[Hi][Hi]', const [LiveEmote(code: '[Hi]', url: 'u')]);
      expect(segments.where((s) => s.type == DanmakuSegmentType.emoji), hasLength(2));
    });

    test('无 url 的表情条目跳过(整段回退纯文本)', () {
      final segments = pureliveDanmakuSegmentsFromEmotes('a[no]b', const [LiveEmote(code: '[no]', url: '')]);
      expect(segments, isEmpty);
    });

    test('编码未出现/空文本返回空', () {
      expect(pureliveDanmakuSegmentsFromEmotes('没有', const [LiveEmote(code: '[x]', url: 'u')]), isEmpty);
      expect(pureliveDanmakuSegmentsFromEmotes('', const [LiveEmote(code: '[x]', url: 'u')]), isEmpty);
      expect(pureliveDanmakuSegmentsFromEmotes('纯文本', const []), isEmpty);
    });
  });

  group('pureliveDanmakuRetractionFrom', () {
    test('非撤回消息恒 null', () {
      expect(pureliveDanmakuRetractionFrom(_msg(LiveMessageType.chat, text: 'hi')), isNull);
      expect(pureliveDanmakuRetractionFrom(_msg(LiveMessageType.gift)), isNull);
    });

    test('按观众/按消息/全部三种目标映射', () {
      final user = pureliveDanmakuRetractionFrom(
        _msg(LiveMessageType.retraction, data: const LiveRetraction.user('123')),
      );
      expect(user?.userId, '123');
      expect(user?.all, isFalse);

      final message = pureliveDanmakuRetractionFrom(
        _msg(LiveMessageType.retraction, data: const LiveRetraction.message('bilibili:9')),
      );
      expect(message?.messageId, 'bilibili:9');

      final all = pureliveDanmakuRetractionFrom(_msg(LiveMessageType.retraction, data: const LiveRetraction.all()));
      expect(all?.all, isTrue);
    });

    test('data 非 LiveRetraction 时安全返回 null(防御解析)', () {
      expect(pureliveDanmakuRetractionFrom(_msg(LiveMessageType.retraction, data: 'junk')), isNull);
    });
  });

  group('pureliveRoomToPayload 语义透传', () {
    test('轮播房映射 RoomState.carousel(不再压成 offline)', () {
      final payload = pureliveRoomToPayload(_room(status: LiveStatus.carousel), 'bilibili');
      expect(payload.roomState, RoomState.carousel);
      expect(payload.isLive, isFalse);
    });

    test('受限口径按枚举名透传,none 为空串', () {
      expect(pureliveRoomToPayload(_room(restriction: LiveRestriction.paid), 'bilibili').restriction, 'paid');
      expect(
        pureliveRoomToPayload(_room(restriction: LiveRestriction.subscribersOnly), 'bilibili').restriction,
        'subscribersOnly',
      );
      expect(pureliveRoomToPayload(_room(), 'bilibili').restriction, isEmpty);
    });

    test('startedAt 直读优先,斗鱼遗留 startedAtMs 兜底,两者皆无为 null', () {
      final direct = DateTime.parse('2026-10-03T12:00:00Z');
      expect(
        pureliveRoomToPayload(_room(startedAt: direct, data: {'startedAtMs': 1000}), 'bilibili').startedAt,
        direct,
      );
      expect(
        pureliveRoomToPayload(_room(data: {'startedAtMs': 1759500000000}), 'douyu').startedAt,
        DateTime.fromMillisecondsSinceEpoch(1759500000000),
      );
      expect(pureliveRoomToPayload(_room(), 'bilibili').startedAt, isNull);
    });

    test('轮播起播偏移 startAtMs 桥接与序列化往返', () {
      // 桥层从 raw 契约取 startAt;payload 序列化按毫秒携带,0 不写键。
      final payload = pureliveRoomToPayload(_room(status: LiveStatus.carousel), 'bilibili');
      expect(payload.startAtMs, 0); // 默认零,非轮播源无偏移
      final restored = RoomPayload.fromJson(payload.copyWith(startAtMs: 905).toJson());
      expect(restored.startAtMs, 905);
      expect(RoomPayload.fromJson(payload.toJson()).startAtMs, 0);
    });

    test('播放在播/回放状态不回归', () {
      expect(pureliveRoomToPayload(_room(status: LiveStatus.live), 'bilibili').roomState, RoomState.live);
      expect(pureliveRoomToPayload(_room(status: LiveStatus.replay), 'bilibili').roomState, RoomState.replay);
      expect(pureliveRoomToPayload(_room(status: LiveStatus.offline), 'bilibili').roomState, RoomState.offline);
    });
  });

  group('restrictionDisplayText 播放页文案', () {
    test('九类受限口径各有文案,未知/空为 null(不伪造)', () {
      expect(restrictionDisplayText('needsLogin'), '需要登录');
      expect(restrictionDisplayText('paid'), '付费直播');
      expect(restrictionDisplayText('subscribersOnly'), '订阅可见');
      expect(restrictionDisplayText('private'), '私密直播');
      expect(restrictionDisplayText('appOnly'), '仅App内可看');
      expect(restrictionDisplayText('regionBlocked'), '地区限制');
      expect(restrictionDisplayText('password'), '密码房间');
      expect(restrictionDisplayText('adult'), '成人内容');
      expect(restrictionDisplayText('unplayable'), '平台未提供播放');
      expect(restrictionDisplayText(''), isNull);
      expect(restrictionDisplayText('junk'), isNull);
    });
  });
}
