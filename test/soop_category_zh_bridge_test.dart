/// SOOP 分类中文链路(purelive 桥)回归:
/// * 解析层房间条目按 broad_cate_no 反查 zh_CN 分类进程表,未命中回落
///   category_name + remap(SoopSite.soopRoomArea);
/// * 桥接层 RoomPayload.cateNo / cid 承载契约(播放页收藏星依赖);
/// * 浏览列表 summary 的 cid 用请求分类号(推荐流为空)。
///
/// 进程表(rememberSoopZhCategory)是进程内全局态,与本文件内 setUp 写入
/// 的条目互查;跨测试文件互不影响(每文件独立 isolate)。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_parser/live_parser.dart' show rememberSoopZhCategory, remapCategoryName;
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/platforms/sites.dart';
import 'package:pure_live/platforms/soop/soop_site.dart';
import 'package:pure_live/src/shared/application/purelive_backend.dart';

void main() {
  setUp(() {
    // 模拟目录预热(zh_CN 分类表直出名 + remap 兜底名混合口径)。
    rememberSoopZhCategory('00040017', '我的世界');
    rememberSoopZhCategory('40070', 'FC Online');
    rememberSoopZhCategory('00130000', remapCategoryName('soop', 'Talk/Cam'));
  });

  group('SoopSite.soopRoomArea(房间条目分类名)', () {
    test('broad_cate_no 无前导零仍命中进程表(分类流条目无 category_name)', () {
      expect(SoopSite.soopRoomArea({'broad_cate_no': '40017'}), '我的世界');
    });

    test('推荐流条目带前导零 + 韩文 category_name,进程表优先', () {
      expect(SoopSite.soopRoomArea({'broad_cate_no': '00040017', 'category_name': '마인크래프트'}), '我的世界');
    });

    test('进程表未命中回落 category_name + remap 归一', () {
      expect(SoopSite.soopRoomArea({'category_name': 'PUBG: Battlegrounds'}), '绝地求生');
      // 预热写入的就是 remap 后显示名(Talk/Cam → 聊天/秀场)。
      expect(SoopSite.soopRoomArea({'broad_cate_no': '00130000'}), '聊天/秀场');
    });

    test('双未命中回落原样(角标按原名/空串隐藏,不造数字)', () {
      expect(SoopSite.soopRoomArea({'category_name': '토크/캠방'}), '토크/캠방');
      expect(SoopSite.soopRoomArea(<dynamic, dynamic>{}), '');
    });
  });

  group('pureliveRoomToPayload(播放页收藏星契约)', () {
    test('soop:data.cateNo 进 payload.cateNo,cid 承载房间号', () {
      final payload = pureliveRoomToPayload(
        LiveRoom(
          roomId: 'khm11903',
          platform: Sites.soopSite,
          area: '我的世界',
          data: {'bno': '297538099', 'cateNo': '00040017'},
        ),
        Sites.soopSite,
      );
      expect(payload.cateNo, '00040017');
      expect(payload.cid, 'khm11903');
      expect(payload.category, '我的世界');
    });

    test('soop:无 data 时 cateNo 空、cid 仍非空(星标渲染判据)', () {
      final payload = pureliveRoomToPayload(LiveRoom(roomId: 'khm11903', platform: Sites.soopSite), Sites.soopSite);
      expect(payload.cateNo, '');
      expect(payload.cid, 'khm11903');
    });

    test('非 soop 平台拿不到分类上下文,cid 维持空串', () {
      final payload = pureliveRoomToPayload(
        LiveRoom(roomId: '1', platform: 'bilibili', area: '英雄联盟', data: {'cateNo': 'x'}),
        'bilibili',
      );
      expect(payload.cid, '');
      expect(payload.category, '英雄联盟');
    });

    test('streams/availableQualities 原样透传', () {
      final payload = pureliveRoomToPayload(
        LiveRoom(roomId: 'r', platform: Sites.soopSite),
        Sites.soopSite,
        streams: const [],
        availableQualities: const [],
      );
      expect(payload.streams, isEmpty);
      expect(payload.availableQualities, isEmpty);
    });
  });

  group('pureliveBrowseSummary(浏览列表 cid 口径)', () {
    test('分类流:cid 用请求的分类号,category 用解析层反查名', () {
      final summary = pureliveBrowseSummary(
        LiveRoom(roomId: 'khm11903', platform: Sites.soopSite, area: '我的世界'),
        Sites.soopSite,
        cid: '00040017',
      );
      expect(summary.cid, '00040017');
      expect(summary.category, '我的世界');
    });

    test('推荐流:无分类上下文,cid 为空', () {
      final summary = pureliveBrowseSummary(
        LiveRoom(roomId: 'khm11903', platform: Sites.soopSite, area: 'FC Online'),
        Sites.soopSite,
        cid: '',
      );
      expect(summary.cid, '');
    });
  });
}
