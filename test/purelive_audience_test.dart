import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/src/shared/application/purelive_audience.dart';

void main() {
  group('audienceDisplayOf(桥接层观看数取值)', () {
    test('legacy watching 非空时原样透出(抖音"1.2万"类格式串)', () {
      final room = LiveRoom(platform: 'douyin', watching: '1.2万', audienceMetricType: AudienceMetricType.totalViewers);
      expect(audienceDisplayOf(room), '1.2万');
    });

    test("legacy '0' 哨兵回落 totalViewers(京东/niconico 口径)", () {
      final room = LiveRoom(
        platform: 'jdlive',
        watching: '0',
        totalViewers: '3456',
        audienceMetricType: AudienceMetricType.totalViewers,
      );
      expect(audienceDisplayOf(room), '3456');
    });

    test('totalViewers 显式值不依赖 metric 类型', () {
      final room = LiveRoom(platform: 'niconico', watching: '0', totalViewers: '500');
      expect(audienceDisplayOf(room), '500');
    });

    test("legacy '0' 哨兵回落 onlineViewers(CHZZK/17LIVE/PandaTV 口径)", () {
      final room = LiveRoom(
        platform: 'chzzk',
        watching: '0',
        onlineViewers: '88',
        audienceMetricType: AudienceMetricType.onlineViewers,
      );
      expect(audienceDisplayOf(room), '88');
    });

    test('popularity 有值时作为热度展示', () {
      final room = LiveRoom(
        platform: 'kilakila',
        watching: '0',
        popularity: '9999',
        audienceMetricType: AudienceMetricType.popularity,
      );
      expect(audienceDisplayOf(room), '9999');
    });

    test("legacy 'null' 串视为空并回落", () {
      final room = LiveRoom(platform: 'weibo', watching: 'null', onlineViewers: '7');
      expect(audienceDisplayOf(room), '7');
    });

    test('无任何测量值时返回空串(不虚构 0)', () {
      final room = LiveRoom(platform: 'xiaohongshu');
      expect(audienceDisplayOf(room), '');
    });

    test('kilakila watchNumber 透出后走 legacy 直通', () {
      final room = LiveRoom(platform: 'kilakila', watching: '1234', audienceMetricType: AudienceMetricType.unknown);
      expect(audienceDisplayOf(room), '1234');
    });
  });
}
