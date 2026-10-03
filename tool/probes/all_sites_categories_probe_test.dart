// Opt-in audit of every registered site's category catalog: exactly the call
// the zishu browse UI makes (getCategores(1, 100) via PureLiveBrowseRepository).
// Not part of offline CI. Only counts, verdicts and short name samples are
// printed/saved.
//
//   PURELIVE_ALL_SITES_PROBE=1 flutter test tool/probes/all_sites_categories_probe_test.dart
//   PURELIVE_PROBE_SITES=huya,douyu        limit to some sites
//   PURELIVE_PROBE_REPORT=/tmp/report.json write the JSON report there
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:live_parser/live_parser.dart' as lp;
import 'package:pure_live/core/config/settings_service.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/core/network/core_error.dart';
import 'package:pure_live/src/shared/domain/category_display.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/get/get.dart';

const _siteTimeout = Duration(seconds: 60);

/// Sites whose catalog is a local database rather than a live platform.
const _localDbSites = {Sites.iptvSite};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('all-categories-probe-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => temp.path,
    );
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
    Get.put(SettingsService(), permanent: true);
  });

  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  test(
    'every registered site returns its category catalog',
    () async {
      final wanted = (Platform.environment['PURELIVE_PROBE_SITES'] ?? '')
          .split(',')
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toSet();
      final ids = Sites.supportedSiteIds
          .where((id) => !_localDbSites.contains(id) && (wanted.isEmpty || wanted.contains(id)))
          .toList()
        ..sort();
      // The UI "xhs" tab is served by the live_parser registry (pure_live's id
      // is xiaohongshu); audit that path separately with the same entry point.
      final results = <Map<String, Object?>>[];
      // flutter test's binding answers every request with a fake HTTP 400;
      // run under an empty override so adapters reach the real network.
      await HttpOverrides.runWithHttpOverrides(() async {
        for (final id in ids) {
          final clock = Stopwatch()..start();
          final result = <String, Object?>{'site': id};
          try {
            await _probePureLiveSite(id, result).timeout(_siteTimeout);
          } on TimeoutException {
            result['error'] = 'timed out after ${_siteTimeout.inSeconds}s';
          } catch (error) {
            result['error'] = _describe(error);
            if (error is HttpError) {
              result['errorStatus'] = error.statusCode;
              final body = error.responseBody ?? '';
              if (body.isNotEmpty) result['errorBody'] = body.substring(0, body.length.clamp(0, 220));
              result['errorHeaders'] = error.responseHeaders;
            }
          }
          result['ms'] = clock.elapsedMilliseconds;
          results.add(result);
          // ignore: avoid_print
          print(_row(result));
        }

        final xhsClock = Stopwatch()..start();
        final xhsResult = <String, Object?>{'site': 'xhs(live_parser)'};
        try {
          await _probeLiveParserXhs(xhsResult).timeout(_siteTimeout);
        } catch (error) {
          xhsResult['error'] = _describe(error);
        }
        xhsResult['ms'] = xhsClock.elapsedMilliseconds;
        results.add(xhsResult);
        // ignore: avoid_print
        print(_row(xhsResult));
      }, _RealNetwork());

      final ok = results.where((r) => r['verdict'] == 'categories-ok').length;
      // ignore: avoid_print
      print('\nSUMMARY categories-ok $ok/${results.length}');
      final reportPath = Platform.environment['PURELIVE_PROBE_REPORT'];
      if (reportPath != null && reportPath.isNotEmpty) {
        await File(reportPath).writeAsString(const JsonEncoder.withIndent('  ').convert(results));
      }
    },
    skip: Platform.environment['PURELIVE_ALL_SITES_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 30)),
  );
}

Future<void> _probePureLiveSite(String id, Map<String, Object?> result) async {
  final site = Sites.of(id).liveSite;
  final categories = await site.getCategores(1, 100);
  _fillCatalog(result, categories.map((c) => (c.name, [for (final a in c.children) (a.areaName ?? '')])).toList());
  // 展示层中文名抽查: 与 UI 同一 displayCategoryName 入口, 即用户实际所见。
  final samples = <String>[];
  for (final category in categories) {
    for (final area in category.children) {
      samples.add(displayCategoryName(id, area.areaName, area.areaId));
      if (samples.length >= 12) break;
    }
    if (samples.length >= 12) break;
  }
  result['displayNames'] = samples;
}

Future<void> _probeLiveParserXhs(Map<String, Object?> result) async {
  final registry = lp.buildSiteRegistry();
  final browse = registry['xhs']?.browse;
  if (browse == null) {
    result['verdict'] = 'no-browse';
    return;
  }
  final categoryResult = await browse.fetchCategories('xhs');
  _fillCatalog(
    result,
    [
      for (final group in categoryResult.groups)
        (group.name, [for (final item in group.items) item.name]),
    ],
  );
}

void _fillCatalog(Map<String, Object?> result, List<(String, List<String>)> groups) {
  final children = [for (final (_, items) in groups) ...items];
  result['groups'] = groups.length;
  result['items'] = children.length;
  result['groupNames'] = [for (final (name, _) in groups.take(12)) name];
  result['itemNames'] = children.take(12).toList();
  if (groups.isEmpty) {
    result['verdict'] = 'empty';
  } else if (children.isEmpty) {
    result['verdict'] = 'groups-only';
  } else {
    result['verdict'] = 'categories-ok';
  }
}

String _describe(Object error) {
  final text = error.toString().replaceAll(RegExp(r'https?://\S+'), '<url>').replaceAll('\n', ' ');
  return text.length > 160 ? '${text.substring(0, 160)}…' : text;
}

String _row(Map<String, Object?> r) {
  final detail = r['error'] ?? '';
  final groups = r['groups'] ?? '-';
  final items = r['items'] ?? '-';
  return '${(r['site'] as String).padRight(16)} ${(r['verdict'] ?? 'error').toString().padRight(16)} '
      'groups=$groups items=$items ${r['ms']}ms  $detail';
}

class _RealNetwork extends HttpOverrides {}
