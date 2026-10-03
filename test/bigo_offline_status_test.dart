/// Bigo 未开播房形状回归(2026-10-03:1081931220 未开播房被当 schema 错误)。
/// 上游离线响应把 needLogin/passRoom 给 null——null 视为未受限,
/// 其余非 bool 形状漂移仍拒绝。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/shared/platforms/bigo/bigo_api.dart';

void main() {
  test('未开播房(needLogin/passRoom=null)不再抛 schema, access=public', () {
    final status = BigoApi.parseStudioStatus(
      const {
        'code': 0,
        'msg': 'success',
        'flag': null,
        'data': {
          'sid': 2865297440,
          'siteId': '1081931220',
          'uid': 851580122,
          'needLogin': null,
          'passRoom': null,
          'isPaidShow': '',
          'alive': 1,
          'roomStatus': 0,
          'roomType': 0,
          'clientBigoId': '1081931220',
          'roomId': '7533192526300772384',
          'hls_src': '',
          'cdn_src': <dynamic>[],
        },
      },
      siteId: '1081931220',
      expectedOwnerId: 851580122,
    );
    expect(status.access, BigoAccess.public);
    expect(status.roomStatus, 0);
  });

  test('needLogin/passRoom 非 bool 形状漂移仍拒绝', () {
    expect(
      () => BigoApi.parseStudioStatus(
        const {
          'code': 0,
          'data': {
            'uid': 1,
            'needLogin': 'yes',
            'passRoom': null,
            'isPaidShow': '',
            'alive': 1,
            'roomStatus': 0,
            'roomType': 0,
            'clientBigoId': '2',
          },
        },
        siteId: '2',
        expectedOwnerId: 1,
      ),
      throwsA(isA<BigoException>()),
    );
  });

  test('未开播房完整 studio 响应 → parseStudioRoom 出房(hls 空)', () {
    final room = BigoApi.parseStudioRoom(const {
      'code': 0,
      'msg': 'success',
      'flag': null,
      'data': {
        'sid': 2865297440,
        'siteId': '1081931220',
        'uid': 851580122,
        'avatar': 'http://esx.bigo.sg/na/live_pic/luz/1wSRSt00y2IH3Aw04pN9U_4.jpg?type=20',
        'nick_name': 'Shirley',
        'country_code': '',
        'gameTitle': '',
        'gameId': 0,
        'roomTopic': '#Dance Dancing',
        'snapshot': 'http://esx.bigo.sg/na/live_pic/luz/snapshot.jpg',
        'alive': 1,
        'roomId': '7533192526300772384',
        'roomStatus': 0,
        'covers': null,
        'client_ip': '',
        'hls_src': '',
        'cdn_src': <dynamic>[],
        'needLogin': null,
        'passRoom': null,
        'reserver': 4108,
        'clientBigoId': '1081931220',
        'roomType': 0,
        'isPaidShow': '',
      },
    }, siteId: '1081931220');
    expect(room.hls, isNull);
    expect(room.status.access, BigoAccess.public);
  });
}
