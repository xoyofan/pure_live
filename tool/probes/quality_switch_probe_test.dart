// Opt-in probe of the quality-switch decision chain on every registered site.
// Mirrors PlayerController.switchStreamSelection for ReloadDataType.changeQuality:
// baseline URLs for the current quality, then the real switch path
// (resolvePlayUrlsForRecovery for LivePlayRecoveryResolver sites, otherwise
// resolvePlayUrls) per alternate quality, classified with the controller's own
// reject predicates (empty sources / applied-to-current / unchanged stream).
// Not part of offline CI. Nothing is saved except the stage/verdict report;
// signed URLs, cookies and media are never written.
//
//   PURELIVE_QUALITY_SWITCH_PROBE=1 flutter test tool/probes/quality_switch_probe_test.dart
//   PURELIVE_PROBE_SITES=huya,douyu        limit to some sites
//   PURELIVE_PROBE_REPORT=/tmp/report.json write the JSON report there
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/core/config/settings_service.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/domains/live/presentation/playback/controllers/player_controller.dart';

const _siteTimeout = Duration(seconds: 120);

/// Alternates probed beyond the baseline quality, to bound per-site runtime.
const _maxAlternates = 4;

/// Rooms the platform itself restricts (region, adult) are skipped without
/// using one of the attempts, up to this many listed rooms.
const _roomsScanned = 10;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('quality-switch-probe-');
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
    'every registered site can switch away from its baseline quality',
    () async {
      final wanted = (Platform.environment['PURELIVE_PROBE_SITES'] ?? '')
          .split(',')
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toSet();
      final ids =
          Sites.supportedSiteIds.where((id) => id != Sites.iptvSite && (wanted.isEmpty || wanted.contains(id))).toList()
            ..sort();
      final results = <Map<String, Object?>>[];
      await HttpOverrides.runWithHttpOverrides(() async {
        for (final id in ids) {
          final clock = Stopwatch()..start();
          final result = <String, Object?>{'site': id};
          try {
            await _probeSite(id, result).timeout(_siteTimeout);
          } on TimeoutException {
            result['error'] ??= 'site timed out after ${_siteTimeout.inSeconds}s';
          } catch (error) {
            result['error'] ??= _describe(error);
          }
          result['ms'] = clock.elapsedMilliseconds;
          results.add(result);
          // ignore: avoid_print
          print(_row(result));
        }
      }, _RealNetwork());

      final broken = results.where((r) => r['verdict'] == 'switch-broken').length;
      final partial = results.where((r) => r['verdict'] == 'switch-partial').length;
      // ignore: avoid_print
      print(
        '\nSUMMARY ok ${results.length - broken - partial}/${results.length} '
        'partial $partial broken $broken',
      );
      final reportPath = Platform.environment['PURELIVE_PROBE_REPORT'];
      if (reportPath != null && reportPath.isNotEmpty) {
        await File(reportPath).writeAsString(const JsonEncoder.withIndent('  ').convert(results));
      }
    },
    skip: Platform.environment['PURELIVE_QUALITY_SWITCH_PROBE'] != '1',
    timeout: const Timeout(Duration(hours: 2)),
  );
}

Future<void> _probeSite(String id, Map<String, Object?> result) async {
  const webViewSites = {'dailymotion', 'nimotv', 'rumble', 'shopeelive'};
  if (webViewSites.contains(id)) {
    result['verdict'] = 'needs-device';
    return;
  }
  final site = Sites.of(id).liveSite;
  final usesRecoveryPath = site is LivePlayRecoveryResolver;
  result['switchPath'] = usesRecoveryPath ? 'recovery' : 'resolvePlayUrls';

  result['stage'] = 'catalog';
  var rooms = await site.getRecommendRooms(page: 1, pageSize: 20);
  if (rooms.isEmpty) {
    final categories = await site.getCategores(1, 20);
    for (final category in categories) {
      if (category.children.isEmpty) continue;
      rooms = await site.getCategoryRooms(category.children.first, page: 1, pageSize: 20);
      if (rooms.isNotEmpty) break;
    }
  }
  if (rooms.isEmpty) {
    result['verdict'] = 'no-catalog';
    return;
  }

  result['stage'] = 'detail';
  LiveRoom? detail;
  var restricted = 0;
  final attempts = <String>[];
  for (final listed in rooms.where((r) => (r.roomId ?? '').trim().isNotEmpty).take(_roomsScanned)) {
    final roomId = listed.roomId!.trim();
    try {
      final candidate = await site.getRoomDetail(LiveRoom(roomId: roomId, platform: id));
      if (candidate.liveStatus != LiveStatus.live) {
        attempts.add('not-live');
        continue;
      }
      final qualities = normalizePlayQualities(await site.getPlayQualites(liveroom: candidate));
      if (qualities.isEmpty) {
        attempts.add('no-qualities');
        continue;
      }
      detail = candidate;
      result['qualities'] = qualities.map((q) => q.quality).toList();
      break;
    } catch (error) {
      restricted++;
    }
  }
  if (detail == null) {
    result['verdict'] = 'no-live-room';
    result['restrictedSkipped'] = restricted;
    return;
  }
  final qualities = normalizePlayQualities(await site.getPlayQualites(liveroom: detail));
  if (qualities.length < 2) {
    result['verdict'] = 'single-quality';
    return;
  }

  final baseline = await site.resolvePlayUrls(liveroom: detail, quality: qualities.first);
  result['stage'] = 'switch';
  final baselineUrls = baseline.urls;
  result['baselineLines'] = baselineUrls.length;
  if (baselineUrls.isEmpty) {
    result['verdict'] = 'failed';
    result['attempts'] = ['baseline: no urls'];
    return;
  }
  result['baselineFingerprint'] = _fingerprint(baselineUrls.first);

  // The active room starts on qualities.first, mirroring the player state
  // against which the controller evaluates a tap on another quality.
  const currentIndex = 0;
  final switchRows = <Map<String, Object?>>[];
  var rejected = 0;
  var accepted = 0;
  for (final quality in qualities.take(1 + _maxAlternates).skip(1)) {
    final requestedIndex = qualities.indexOf(quality);
    final row = <String, Object?>{'quality': quality.quality, 'requestedIndex': requestedIndex};
    try {
      final resolution = usesRecoveryPath
          ? await site.resolvePlayUrlsForRecovery(liveroom: detail!, quality: quality)
          : await site.resolvePlayUrls(liveroom: detail!, quality: quality);
      if (!resolution.hasSources) {
        row['verdict'] = 'rejected-empty';
        rejected++;
      } else {
        final applied = resolveAppliedQualityIndex(
          qualities: qualities,
          requestedIndex: requestedIndex,
          appliedQualityData: resolution.appliedQualityData,
        );
        row['appliedIndex'] = applied;
        final qualityAdjusted = applied != requestedIndex;
        if (qualityAdjusted && applied == currentIndex) {
          row['verdict'] = 'rejected-applied-current';
          rejected++;
        } else {
          final selection = resolveStreamSelection(
            qualityCount: qualities.length,
            playUrlCount: resolution.lineCount,
            requestedQualityIndex: applied,
            requestedLineIndex: 0,
          );
          if (!selection.isValid) {
            row['verdict'] = 'rejected-invalid-selection';
            rejected++;
          } else if (selection.qualityIndex != currentIndex &&
              resolution.inputRecipe == null &&
              hasSameStreamChoices(baselineUrls, resolution.urls)) {
            row['verdict'] = 'rejected-same-stream';
            row['fingerprint'] = resolution.urls.isEmpty ? '-' : _fingerprint(resolution.urls.first);
            rejected++;
          } else {
            row['verdict'] = 'accepted';
            row['fingerprint'] = resolution.urls.isEmpty ? '-' : _fingerprint(resolution.urls.first);
            accepted++;
          }
        }
      }
    } catch (error) {
      row['verdict'] = 'error';
      row['error'] = _describe(error);
      rejected++;
    }
    switchRows.add(row);
  }
  result['switches'] = switchRows;
  result['restrictedSkipped'] = restricted;
  if (attempts.isNotEmpty) result['attempts'] = attempts;
  result['verdict'] = rejected == 0
      ? 'switch-ok'
      : accepted == 0
      ? 'switch-broken'
      : 'switch-partial';
}

/// Host plus leading path bytes: enough to tell per-quality endpoints apart
/// without storing signed queries.
String _fingerprint(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return 'unparsable(${url.length})';
  final path = uri.path;
  return '${uri.host}${path.length > 48 ? '${path.substring(0, 48)}…' : path}';
}

String _describe(Object error) {
  final text = error.toString();
  return text.length > 160 ? '${text.substring(0, 160)}…' : text;
}

String _row(Map<String, Object?> result) {
  final quality = (result['qualities'] as List?)?.length;
  return '${result['site']}'.padRight(15) +
      '${result['verdict']}'.padRight(15) +
      'qualities=$quality ${result['ms']}ms ${result['error'] ?? ''}';
}

class _RealNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..connectionTimeout = const Duration(seconds: 15)
      ..maxConnectionsPerHost = 8;
  }
}
