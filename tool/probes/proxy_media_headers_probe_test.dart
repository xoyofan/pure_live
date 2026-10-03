// Opt-in live probe: 端到端验证「站点媒体头 → 本地流代理转发 → 真实 CDN 取流」。
//
// 背景(2026-10-03 17LIVE 事故):wansu CDN 强校验 Referer,本地代理裸取上游
// 403。本探针防止该类 CDN 头校验回归:PlaybackHeaderResolver 产出的站点头
// 必须经 StreamProxySession 到达上游,且能拉到真实媒体字节。
//
//   PURELIVE_PROXY_HEADERS_DIAG=1 \
//   PURELIVE_PROXY_HEADERS_SITE=17live \
//   PURELIVE_PROXY_HEADERS_ROOM=27484154 \
//   flutter test tool/probes/proxy_media_headers_probe_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/core/network/playback_header_resolver.dart';
import 'package:pure_live/platforms/sites.dart';
import 'package:pure_live/src/platforms/common/playback/local_stream_proxy.dart';

void main() {
  test(
    'proxy forwards site media headers to the real CDN upstream',
    () async {
      final site = Platform.environment['PURELIVE_PROXY_HEADERS_SITE'] ?? '17live';
      final roomId = Platform.environment['PURELIVE_PROXY_HEADERS_ROOM'] ?? '';
      await HttpOverrides.runWithHttpOverrides(() async {
        // 1) 站点头部契约:必须含 user-agent;17live/pandalive 等还含 referer。
        final headers = await PlaybackHeaderResolver.resolve(platform: site, roomId: roomId);
        // ignore: avoid_print
        print('resolved headers: $headers');
        expect(headers['user-agent'], isNotEmpty);
        expect(headers['referer'], isNotEmpty, reason: '$site CDN 按 Referer 强校验,契约缺 referer 即回归');

        // 2) 经站点适配器解析出真实首线路(FLV 直链)。
        final liveSite = Sites.of(site).liveSite;
        final detail = await liveSite.getRoomDetail(LiveRoom(roomId: roomId, platform: site));
        final qualities = await liveSite.getPlayQualites(liveroom: detail);
        expect(qualities, isNotEmpty, reason: '$site 房间 $roomId 无可用档位');
        final urls = await liveSite.getPlayUrls(liveroom: detail, quality: qualities.first);
        final flvUrls = urls.where((url) => url.toString().toLowerCase().endsWith('.flv')).toList();
        expect(flvUrls, isNotEmpty, reason: '$site 首档无 FLV 直链: $urls');
        // ignore: avoid_print
        print('upstream line: ${flvUrls.first}');

        // 3) 本地代理携带头部取上游:期望 200 且字节为 FLV 流。
        final proxy = LocalStreamProxy();
        await proxy.start();
        final session = proxy.openSession(flvUrls.first.toString(), headers: headers);
        try {
          final client = HttpClient();
          final request = await client.getUrl(Uri.parse(session.localUrl));
          final response = await request.close().timeout(const Duration(seconds: 20));
          expect(response.statusCode, 200);
          final first = await response.first.timeout(const Duration(seconds: 30));
          // ignore: avoid_print
          print('local proxy bytes: ${first.length} head=${first.take(3).toList()}');
          expect(first.length, greaterThan(0));
          expect(first[0], 0x46, reason: 'FLV magic F');
          expect(first[1], 0x4C, reason: 'FLV magic L');
          expect(first[2], 0x56, reason: 'FLV magic V');
          client.close(force: true);
        } finally {
          await session.dispose();
          await proxy.stop();
        }
      }, _RealNetwork());
    },
    skip: Platform.environment['PURELIVE_PROXY_HEADERS_DIAG'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _RealNetwork extends HttpOverrides {}
