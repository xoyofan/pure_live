// 抖音首页推荐流诊断:对比无签名现状与 zishu 参照的全参数签名请求。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/shared/platforms/douyin/douyin_site.dart' as shared;
import 'package:pure_live/shared/platforms/douyin/douyin_utils.dart';

Future<void> _dump(String label, dynamic payload) async {
  final text = payload is String ? payload : jsonEncode(payload);
  // ignore: avoid_print
  print('[$label] bytes=${text.length} head=${text.substring(0, text.length > 180 ? 180 : text.length)}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('douyin feed diag', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      // 1) 现状:适配器无签名推荐流
      try {
        final rooms = await shared.DouyinSite().getRecommendRooms(page: 1, pageSize: 10);
        // ignore: avoid_print
        print('[适配器现状] rooms=${rooms.length}');
        for (final r in rooms.take(8)) {
          // ignore: avoid_print
          print('  - ${r.roomId} ${(r.title ?? '').substring(0, (r.title ?? '').length > 24 ? 24 : (r.title ?? '').length)}');
        }
      } catch (e) {
        // ignore: avoid_print
        print('[适配器现状] ERROR: $e');
      }

      // 2) zishu 参照口径:全参数+签名
      final signedUrl = DouyinUtils.buildRequestUrl('https://live.douyin.com/webcast/feed/', <String, dynamic>{
        'aid': '6383',
        'app_name': 'douyin_web',
        'live_id': '1',
        'language': 'zh-CN',
        'channel': 'channel_pc_web',
        'need_map': '1',
        'liveid': '1',
        'is_draw': '1',
        'inner_from_drawer': '0',
        'custom_count': '10',
        'action': 'load_more',
        'action_type': 'loadmore',
        'enter_source': 'web_homepage_hot_web_live_card',
        'source_key': 'web_homepage_hot_web_live_card',
        'is_ssr': 'true',
        'maxtime': '0',
      });
      final resp = await HttpClient.instance.dio.get(signedUrl);
      await _dump('签名请求', resp.data is String ? resp.data : jsonEncode(resp.data));
      final body = resp.data is String ? jsonDecode(resp.data as String) : resp.data;
      if (body is Map) {
        // ignore: avoid_print
        print('[签名请求] status_code=${body['status_code']} data类型=${body['data'].runtimeType}');
        final data = body['data'];
        if (data is List) {
          var n = 0;
          for (final env in data) {
            if (n >= 8) break;
            final inner = env is Map ? env['data'] : null;
            if (inner is Map && '${inner['id_str']}' != 'null') {
              // ignore: avoid_print
              print('  - ${inner['id_str']} ${('${inner['title'] ?? ''}').substring(0, ('${inner['title'] ?? ''}').length > 24 ? 24 : ('${inner['title'] ?? ''}').length)}');
              n++;
            }
          }
        }
      }
    }, _RealNetwork());
  }, skip: Platform.environment['PURELIVE_DOUYIN_FEED_DIAG'] != '1');
}

class _RealNetwork extends HttpOverrides {}
