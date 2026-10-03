import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/src/features/search/application/search_provider.dart';

/// 搜索页直达识别契约(纯函数)。2026-10-02:niconico 节目号/观察页链接
/// 此前不识别(lv351393299 报"解析失败",实为搜索页直达链缺口——房间
/// ON_AIR、purelive 解析层健康)。
void main() {
  group('resolveSearchDirect(搜索直达识别)', () {
    test('纯数字 → 房间号直达(既有行为不回归)', () {
      final target = resolveSearchDirect('douyu', '8682569');
      expect(target?.kind, DirectKind.roomId);
      expect(target?.roomId, '8682569');
    });

    test('douyu 链接 → 链接直达(既有行为不回归)', () {
      final target = resolveSearchDirect('douyu', 'https://www.douyu.com/8682569');
      expect(target?.kind, DirectKind.link);
      expect(target?.roomId, '8682569');
    });

    test('niconico 观察页链接 → 链接直达(任意平台档下识别)', () {
      for (final site in ['all', 'douyu', 'niconico']) {
        final target = resolveSearchDirect(site, 'https://live.nicovideo.jp/watch/lv351393299');
        expect(target?.kind, DirectKind.link, reason: 'site=$site');
        expect(target?.roomId, 'lv351393299', reason: 'site=$site');
        expect(target?.url, 'https://live.nicovideo.jp/watch/lv351393299');
      }
    });

    test('niconico 节目号裸输入 → 仅选定 niconico 平台时房间号直达', () {
      expect(resolveSearchDirect('niconico', 'lv351393299')?.kind, DirectKind.roomId);
      expect(resolveSearchDirect('niconico', 'lv351393299')?.roomId, 'lv351393299');
      // 全站/其他平台档下不识别:避免普通搜索词误判为直达。
      expect(resolveSearchDirect('all', 'lv351393299'), isNull);
      expect(resolveSearchDirect('douyu', 'lv351393299'), isNull);
    });

    test('17.live 直播页链接 → 链接直达(任意平台档下识别,含语言前缀)', () {
      for (final url in [
        'https://17.live/en/live/29725277',
        'https://17.live/live/29725277',
        'https://www.17.live/zh-tw/live/29725277',
      ]) {
        final target = resolveSearchDirect('douyu', url);
        expect(target?.kind, DirectKind.link, reason: url);
        expect(target?.roomId, '29725277', reason: url);
        expect(target?.url, url, reason: url);
      }
      // 非直播页路径(如 profile)不识别。
      expect(resolveSearchDirect('douyu', 'https://17.live/en/profile/r/29725277'), isNull);
    });

    test('twitcasting 频道根 URL → 链接直达(任意平台档下识别)', () {
      for (final url in [
        'https://twitcasting.tv/mel___t',
        'https://www.twitcasting.tv/mel___t/',
        'https://twitcasting.tv/mel___t?ref=share',
      ]) {
        final target = resolveSearchDirect('douyu', url);
        expect(target?.kind, DirectKind.link, reason: url);
        expect(target?.roomId, 'mel___t', reason: url);
      }
      // 电影/回放链接不直达(与 pure_live「不静默替换旧场次」口径一致)。
      expect(resolveSearchDirect('douyu', 'https://twitcasting.tv/mel___t/movie/841737342'), isNull);
      // 非频道名形状不识别。
      expect(resolveSearchDirect('douyu', 'https://twitcasting.tv/'), isNull);
    });

    test('twitcasting c:/g:/f:/ig: 前缀频道根 URL → 链接直达(2026-10-03:c:tbk_1 打不开,直达正则漏前缀)', () {
      for (final (url, roomId) in [
        ('https://twitcasting.tv/c:tbk_1', 'c:tbk_1'),
        ('https://www.twitcasting.tv/c:tbk_1/', 'c:tbk_1'),
        ('https://twitcasting.tv/g:external_group', 'g:external_group'),
      ]) {
        final target = resolveSearchDirect('twitcasting', url);
        expect(target?.kind, DirectKind.link, reason: url);
        // roomId 保留前缀与原始大小写,解析层 channelName 负责归一小写。
        expect(target?.roomId, roomId, reason: url);
      }
      // 电影/回放多段路径依旧不直达。
      expect(resolveSearchDirect('twitcasting', 'https://twitcasting.tv/c:tbk_1/movie/841760967'), isNull);
    });

    test('twitch 频道根 URL → 链接直达(统一解析器,平台随解析给出)', () {
      for (final url in [
        'https://www.twitch.tv/siaohu_0124',
        'https://twitch.tv/siaohu_0124/',
        'https://m.twitch.tv/siaohu_0124',
      ]) {
        final target = resolveSearchDirect('douyu', url);
        expect(target?.kind, DirectKind.link, reason: url);
        expect(target?.roomId, 'siaohu_0124', reason: url);
        expect(target?.site, 'twitch', reason: url);
      }
      // 站点自身段落(videos/directory 等)不是频道。
      expect(resolveSearchDirect('douyu', 'https://www.twitch.tv/directory'), isNull);
      expect(resolveSearchDirect('douyu', 'https://www.twitch.tv/videos/1234567'), isNull);
    });

    test('非法 lv 形态不识别(与 validateProgramId 同口径)', () {
      expect(resolveSearchDirect('niconico', 'lv0'), isNull);
      expect(resolveSearchDirect('niconico', 'lv'), isNull);
    });

    test('普通关键词不误判', () {
      expect(resolveSearchDirect('niconico', 'うちの弟'), isNull);
      expect(resolveSearchDirect('douyu', '英雄联盟'), isNull);
    });
  });
}
