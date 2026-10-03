// 播放页「网页」外链构造:sourceUrl 优先 + 上游站点 resolver 全量契约
// (2026-10-03 前只手拼 douyu/huya/bilibili 三站)。零网络。
import 'package:flutter_test/flutter_test.dart';
import 'package:live_parser/live_parser.dart';
import 'package:pure_live/src/features/play/widgets/play_side_panel.dart' show roomExternalUrl;

RoomPayload _payload({String sourceUrl = ''}) {
  return RoomPayload(
    site: 'douyu',
    roomId: '1',
    sourceUrl: sourceUrl,
    anchorName: 'a',
    title: 't',
    cover: '',
    avatar: '',
    category: '',
    cid: '',
    roomState: RoomState.live,
    streams: const [],
    availableQualities: const [],
    source: 'test',
    fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

void main() {
  test('sourceUrl 优先(解析器实际进入的页面最稳)', () {
    expect(
      roomExternalUrl('douyu', '999', _payload(sourceUrl: 'https://www.douyu.com/999?source=share')),
      'https://www.douyu.com/999?source=share',
    );
  });

  test('头部三站手拼路径不回归', () {
    expect(roomExternalUrl('douyu', '123', _payload()), 'https://www.douyu.com/123');
    expect(roomExternalUrl('huya', '456', _payload()), 'https://www.huya.com/456');
    expect(roomExternalUrl('bilibili', '789', _payload()), 'https://live.bilibili.com/789');
  });

  test('上游 resolver 契约点亮长尾站点(此前返回 null 按钮禁用)', () {
    // twitcasting 频道页 / SOOP 官方页 / SHOWROOM 官方页——各站 resolver 自报。
    final twit = roomExternalUrl('twitcasting', 'mel___t', _payload());
    expect(twit, contains('twitcasting.tv'));
    final soop = roomExternalUrl('soop', '12345', _payload());
    expect(soop, contains('sooplive.co.kr'));
    final showroom = roomExternalUrl('showroom', '9', _payload());
    expect(showroom, contains('showroom-live.com'));
  });

  test('空房间号与站点缺位安全返回 null(不伪造)', () {
    expect(roomExternalUrl('douyu', '', _payload()), isNull);
    expect(roomExternalUrl('not_a_site', '42', _payload()), isNull);
  });
}
