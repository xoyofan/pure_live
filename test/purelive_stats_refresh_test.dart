import 'package:flutter_test/flutter_test.dart';
import 'package:live_parser/live_parser.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/src/shared/application/purelive_backend.dart';

class _StubStatsRefresher implements RoomSummaryRefresher {
  _StubStatsRefresher(this._record);

  final RoomRecord _record;
  RoomRequest? lastRequest;

  @override
  Future<RoomRecord> refreshRoomSummary(RoomRequest request) async {
    lastRequest = request;
    return _record;
  }

  @override
  Future<RoomPayload> resolveRoom(RoomRequest request) async {
    throw UnimplementedError('stub 不提供播放解析');
  }
}

void main() {
  group('pureliveStatsRecord(pure_live 统计快照)', () {
    test('legacy watching 非空透出,粉丝数非空透出', () {
      final room = LiveRoom(platform: 'chzzk', roomId: '1', watching: '3456', followers: '1.2万');
      final record = pureliveStatsRecord(room, 'chzzk');
      expect(record.audience, '3456');
      expect(record.followers, '1.2万');
    });

    test("watching '0' 哨兵回落新口径测量值(totalViewers)", () {
      final room = LiveRoom(
        platform: 'jdlive',
        roomId: '2',
        watching: '0',
        totalViewers: '789',
        audienceMetricType: AudienceMetricType.totalViewers,
      );
      expect(pureliveStatsRecord(room, 'jdlive').audience, '789');
    });

    test('无任何测量值时 audience 为 null(不冒充)', () {
      final room = LiveRoom(platform: 'inke', roomId: '3');
      expect(pureliveStatsRecord(room, 'inke').audience, isNull);
    });

    test('vip/svip 无数据源恒为 null(数据诚实性,由 native 委托补全)', () {
      final room = LiveRoom(platform: 'douyu', roomId: '4', watching: '100');
      final record = pureliveStatsRecord(room, 'douyu');
      expect(record.vip, isNull);
      expect(record.svip, isNull);
    });
  });

  group('native 统计刷新委托(buildPureLiveRegistration)', () {
    test('传入 native refresher 时 refreshRoomSummary 原样委托', () async {
      final sentinel = RoomRecord(site: 'huya', roomId: '99', roomState: RoomState.live, vip: '7', svip: '3');
      final stub = _StubStatsRefresher(sentinel);
      final registration = buildPureLiveRegistration('huya', nativeStatsRefresher: stub);
      final request = RoomRequest(site: 'huya', roomIdOrUrl: '99');
      final record = await (registration.resolver as RoomSummaryRefresher).refreshRoomSummary(request);
      expect(record.vip, '7');
      expect(record.svip, '3');
      expect(stub.lastRequest?.roomIdOrUrl, '99');
    });

    test('未传入时保持 purelive 解析器类型', () {
      final registration = buildPureLiveRegistration('huya');
      expect(registration.resolver, isA<PureLiveRoomResolver>());
    });
  });
}
