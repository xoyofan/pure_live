// 临时诊断探针(2026-10-07 分类加载失败排查):按 zishu app 的真实构造
// (ParserConfig 注入 + buildRegistryWithPureLive)走浏览链,复现
// 「顶栏 hover 分类 → 房间列表」调用。四个失败站点逐一打印分类数与
// 首个分类的房间数/异常。
//
//   PURELIVE_BROWSE_REPRO=1 flutter test tool/probes/browse_chain_repro_probe_test.dart
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/core/consts/platform_ids.dart';
import 'package:pure_live/core/config/settings_service.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/src/shared/application/parser_sources.dart';
import 'package:pure_live/src/shared/application/providers.dart' show buildRegistryWithPureLive;
import 'package:live_parser/live_parser.dart' show buildSiteRegistry;
import 'package:pure_live/core/network/parser_config.dart';
import 'package:pure_live/src/shared/application/zishu_parser_config.dart';

class _RealNetwork extends HttpOverrides {}

void main() {
  final enabled = Platform.environment['PURELIVE_BROWSE_REPRO'] == '1';
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final temp = await Directory.systemTemp.createTemp('browse-repro-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => temp.path,
    );
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
    Get.put(SettingsService(), permanent: true);
  });

  test(
    'app 同款构造的浏览链:分类→房间列表',
    () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        // 与 providers.dart browseSourceProvider 同款:注入 ParserConfig(空凭证
        // =匿名),再建注册表浏览源。
        final inject = Platform.environment['PURELIVE_BROWSE_REPRO_INJECT'] == '1';
        if (inject) ParserConfig.instance = ZishuParserConfig(const {});
        final phase = Platform.environment['PURELIVE_BROWSE_REPRO_PHASE'] ?? 'full';
        // bare:什么都不构建,只直调——矩阵探针的等价形态(应当通过)。
        if (phase == 'bare') {
          try {
            final direct = await Sites.of('missevan').liveSite.getCategores(1, 100);
            // ignore: avoid_print
            print('REPRO bare DIRECT categories=${direct.length}');
          } catch (e) {
            // ignore: avoid_print
            print('REPRO bare DIRECT FAIL error=$e');
          }
          return;
        }
        if (phase == 'sites-only' || phase == 'sites-limited') {
          final limit = int.tryParse(Platform.environment['PURELIVE_BROWSE_REPRO_LIMIT'] ?? '999') ?? 999;
          var i = 0;
          for (final s0 in Sites.supportSites) {
            if (i++ >= limit) break;
            // ignore: avoid_print
            print('INSTANTIATE #$i ${s0.id}');
            s0.liveSite;
          }
        } else if (phase == 'native-only') {
          buildSiteRegistry();
        }
        final source = ParserBrowseSource(registry: phase == 'full' ? buildRegistryWithPureLive() : null);

        final sites = (Platform.environment['PURELIVE_PROBE_SITES'] ?? 'twitcasting,missevan,niconico,showroom')
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList();

        for (final site in sites) {
          try {
            final categories = await source.fetchCategories(site);
            var tileCount = 0;
            String? firstCid;
            for (final group in categories.groups) {
              for (final tile in group.items) {
                tileCount++;
                firstCid ??= tile.cid;
              }
            }
            try {
              final rooms = await source.fetchRooms(site: site, cid: firstCid, page: 1, limit: 30);
              final chipCount = rooms.rooms.fold<int>(0, (sum, r) => sum + r.chips.length);
              final withChips = rooms.rooms.where((r) => r.chips.isNotEmpty).length;
              // ignore: avoid_print
              print(
                'REPRO $site categories-ok tiles=$tileCount firstRooms=${rooms.rooms.length} withChips=$withChips totalChips=$chipCount',
              );
            } catch (error) {
              // ignore: avoid_print
              print('REPRO $site ROOMS-FAIL cid=$firstCid error=$error');
            }
          } catch (error) {
            // ignore: avoid_print
            print('REPRO $site CATEGORIES-FAIL error=$error');
            // 同进程直调同一适配器实例:区分「注册表构建污染共享态」与「包装层」。
            try {
              final direct = await Sites.of(site).liveSite.getCategores(1, 100);
              // ignore: avoid_print
              print('REPRO $site DIRECT-after-registry categories=${direct.length}');
            } catch (directError) {
              // ignore: avoid_print
              print('REPRO $site DIRECT-after-registry FAIL error=$directError');
              // ignore: avoid_print
              print('REPRO-STACK $site ${StackTrace.current}');
              dynamic cur = directError;
              while (cur != null) {
                // ignore: avoid_print
                print('REPRO-CAUSE $site ${cur.runtimeType}: $cur');
                cur = cur is Error || cur is Exception ? null : null;
              }
            }
          }
        }
      }, _RealNetwork());
    },
    skip: enabled ? false : 'set PURELIVE_BROWSE_REPRO=1',
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
