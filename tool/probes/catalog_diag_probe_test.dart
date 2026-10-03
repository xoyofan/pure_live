// One-off catalog diagnostic: run the real site adapters for the currently
// failing sites inside the probe harness and print the full error + stack.
//
//   PURELIVE_CATALOG_DIAG=1 flutter test tool/probes/catalog_diag_probe_test.dart
//   PURELIVE_CATALOG_SITES=showroom,missevan
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/core/models/live_area.dart';

const _timeout = Duration(seconds: 60);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'catalog diagnostic',
    () async {
      final wanted = (Platform.environment['PURELIVE_CATALOG_SITES'] ?? 'showroom,missevan')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet();
      await HttpOverrides.runWithHttpOverrides(() async {
        for (final id in wanted) {
          // ignore: avoid_print
          print('=== $id');
          try {
            final categories = await Sites.of(id).liveSite.getCategores(1, 100).timeout(_timeout);
            for (final category in categories) {
              // ignore: avoid_print
              print('  GROUP ${category.name}');
              // ignore: avoid_print
              print(
                '  ${category.name}: ${category.children.length} children '
                '${category.children.take(6).map((a) => a.areaName).toList()}',
              );
            }
            // 分类房间抽验优先选真实分类(跳过 total 类入口,如 chzzk popular 总榜),
            // 否则退回首组首项。
            final firstArea = categories
                .expand((category) => category.children)
                .cast<LiveArea?>()
                .firstWhere(
                  (area) => (area?.areaType ?? '') != '' && area!.areaType != 'directory',
                  orElse: () {
                    for (final category in categories) {
                      if (category.children.isNotEmpty) return category.children.first;
                    }
                    return null;
                  },
                );
            // 分类房间抽验:首个非空子分类拉一页,验证 cid→房间链路。
            if (firstArea != null) {
              final rooms = await Sites.of(id).liveSite
                  .getCategoryRooms(firstArea, page: 1, pageSize: 3)
                  .timeout(_timeout);
              // ignore: avoid_print
              print(
                '  rooms[${firstArea.areaId}]: ${rooms.length} '
                '${rooms.take(3).map((r) => '${r.nick}:${r.area}').toList()}',
              );
            }
            // 推荐流分类名抽样(soop 英文化等数据层口径验证)。
            final recommend = await Sites.of(id).liveSite.getRecommendRooms(page: 1, pageSize: 5).timeout(_timeout);
            // ignore: avoid_print
            print('  recommend areas: ${recommend.take(5).map((r) => r.area).toList()}');
          } catch (error, stack) {
            // ignore: avoid_print
            print('  ERROR $error');
            // ignore: avoid_print
            print(stack.toString().split('\n').take(14).join('\n'));
          }
        }
      }, _RealNetwork());
    },
    skip: Platform.environment['PURELIVE_CATALOG_DIAG'] != '1',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

class _RealNetwork extends HttpOverrides {}
