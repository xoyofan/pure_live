// Opt-in matrix probe: for every site, walk EVERY category tile and fetch its
// room list — verifying the category→rooms link users hit when clicking a chip
// in the hover flyout or drawer. Reports per-category room counts and flags
// categories that error out or come back empty.
//
//   PURELIVE_CATROOM_MATRIX=1 flutter test tool/probes/category_rooms_matrix_probe_test.dart
//   PURELIVE_PROBE_SITES=douyin,soop      limit to some sites
//   PURELIVE_PROBE_REPORT=/tmp/report.json write the JSON report there
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/core/config/settings_service.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/core/models/live_area.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/get/get.dart';

const _siteTimeout = Duration(seconds: 90);
const _categoryTimeout = Duration(seconds: 30);
// 每站最多验证的分类枚数(全量枚举太慢时缩样本;0 = 不限制)。
const _perSiteCap = int.fromEnvironment('PURELIVE_CATROOM_CAP', defaultValue: 24);

class _RealNetwork extends HttpOverrides {}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final temp = await Directory.systemTemp.createTemp('catroom-matrix-');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => temp.path,
  );
  await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
  await HivePrefUtil.init();
  Get.put(SettingsService(), permanent: true);

  final wanted = (Platform.environment['PURELIVE_PROBE_SITES'] ?? '')
      .split(',')
      .map((s) => s.trim().toLowerCase())
      .where((s) => s.isNotEmpty)
      .toSet();
  final ids = Sites.supportedSiteIds
      .where((id) => id != Sites.iptvSite && (wanted.isEmpty || wanted.contains(id)))
      .toList()
    ..sort();

  final results = <Map<String, Object?>>[];
  await HttpOverrides.runWithHttpOverrides(() async {
    for (final id in ids) {
      final result = <String, Object?>{'site': id};
      final clock = Stopwatch()..start();
      try {
        await _probeSite(id, result).timeout(_siteTimeout);
      } on TimeoutException {
        result['error'] = 'timed out';
      } catch (error) {
        result['error'] = '$error'.replaceAll('\n', ' ');
      }
      result['ms'] = clock.elapsedMilliseconds;
      results.add(result);
      // ignore: avoid_print
      print(_siteRow(result));
      for (final bad in (result['bad'] as List?) ?? const []) {
        // ignore: avoid_print
        print('    BAD $bad');
      }
    }
  }, _RealNetwork());

  final reportPath = Platform.environment['PURELIVE_PROBE_REPORT'];
  if (reportPath != null && reportPath.isNotEmpty) {
    await File(reportPath).writeAsString(const JsonEncoder.withIndent('  ').convert(results));
  }
  final total = results.fold<int>(0, (sum, r) => sum + ((r['checked'] as int?) ?? 0));
  final empty = results.fold<int>(0, (sum, r) => sum + ((r['empty'] as int?) ?? 0));
  final bad = results.fold<int>(0, (sum, r) => sum + ((r['bad'] as List?)?.length ?? 0));
  // ignore: avoid_print
  print('\nSUMMARY sites=${results.length} checked=$total empty=$empty bad=$bad');
  await temp.delete(recursive: true);
}

Future<void> _probeSite(String id, Map<String, Object?> result) async {
  final site = Sites.of(id).liveSite;
  final categories = await site.getCategores(1, 100);
  // 直接保留 getCategores 返回的原始 LiveArea:部分站适配器经 shortName /
  // areaType 等扩展字段携带查询参数(如 yy shortName=JSON 查询串、twitch
  // shortName=slug), 重建骨架字段会丢失这些生产路径必需的载荷。
  final areas = <(String, LiveArea)>[];
  for (final category in categories) {
    for (final area in category.children) {
      areas.add((category.name, area));
    }
  }
  result['tiles'] = areas.length;
  if (areas.isEmpty) {
    result['verdict'] = 'no-categories';
    return;
  }

  final candidates = _perSiteCap > 0 ? areas.take(_perSiteCap).toList() : areas;
  result['checked'] = candidates.length;

  var withRooms = 0;
  final empty = <String>[];
  final bad = <String>[];
  for (final (groupName, area) in candidates) {
    final label = '$groupName/${area.areaName}(${area.areaId})';
    try {
      final rooms = await site
          .getCategoryRooms(area, page: 1, pageSize: 5)
          .timeout(_categoryTimeout);
      if (rooms.isEmpty) {
        empty.add(label);
      } else {
        withRooms++;
      }
    } catch (error) {
      bad.add('$label -> ${'$error'.replaceAll('\n', ' ')}');
    }
  }
  result['withRooms'] = withRooms;
  result['empty'] = empty.length;
  result['bad'] = bad;
  final okRatio = candidates.isEmpty ? 0.0 : withRooms / candidates.length;
  result['verdict'] = bad.isEmpty && okRatio >= 0.5 ? 'rooms-ok' : (bad.isEmpty ? 'mostly-empty' : 'rooms-broken');
}

String _siteRow(Map<String, Object?> r) {
  final sb = StringBuffer((r['site'] as String).padRight(16));
  sb.write((r['verdict'] ?? 'error').toString().padRight(14));
  sb.write('tiles=${r['tiles']} checked=${r['checked']} withRooms=${r['withRooms']} empty=${r['empty']} bad=${(r['bad'] as List?)?.length ?? 0}');
  if (r['error'] != null) {
    final e = '${r['error']}';
    sb.write('  ERR ${e.substring(0, e.length.clamp(0, 60))}');
  }
  return sb.toString();
}
