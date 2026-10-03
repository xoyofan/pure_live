// Opt-in audit: homepage (room card) fields vs live page (detail) fields per
// site. Zishu renders card badges from RoomSummary(area/watching) and the play
// page header from getRoomDetail — both come from the same LiveRoom fields, so
// any drift (missing area, raw i18n keys, audience gaps) shows up here as
// home≠play mismatches or RAW-KEY leaks.
//
//   PURELIVE_ALIGNMENT_PROBE=1 flutter test tool/probes/home_play_alignment_probe_test.dart
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
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/core/utils/i18n.dart';
import 'package:pure_live/get/get.dart';

const _siteTimeout = Duration(seconds: 90);

/// Raw i18n-key shape (lowercase snake), e.g. `niconico_category_common`.
final _rawKeyPattern = RegExp(r'^[a-z][a-z0-9]*(?:_[a-z0-9]+)+$');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('home-play-alignment-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => temp.path,
    );
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
    Get.put(SettingsService(), permanent: true);
    await ensureZhTextFallback();
  });

  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  test(
    'homepage card fields align with live page detail fields',
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
          final result = <String, Object?>{'site': id};
          try {
            await _probeSite(id, result).timeout(_siteTimeout);
          } on TimeoutException {
            result['error'] = 'timed out';
          } catch (error) {
            result['error'] = '$error'.replaceAll('\n', ' ');
          }
          results.add(result);
          // ignore: avoid_print
          print(_row(result));
        }
      }, _RealNetwork());

      final leaks = results.where((r) => (r['leaks'] as List?)?.isNotEmpty == true).length;
      // ignore: avoid_print
      print('\nSUMMARY sites=${results.length} raw-key-leaks=$leaks');
      final reportPath = Platform.environment['PURELIVE_PROBE_REPORT'];
      if (reportPath != null && reportPath.isNotEmpty) {
        await File(reportPath).writeAsString(const JsonEncoder.withIndent('  ').convert(results));
      }
    },
    skip: Platform.environment['PURELIVE_ALIGNMENT_PROBE'] != '1',
    timeout: const Timeout(Duration(hours: 2)),
  );
}

Future<void> _probeSite(String id, Map<String, Object?> result) async {
  final site = Sites.of(id).liveSite;
  final leaks = <String>[];

  // ── 首页(房间卡)字段:推荐流 ──
  final rooms = await site.getRecommendRooms(page: 1, pageSize: 5);
  result['rooms'] = rooms.length;
  if (rooms.isNotEmpty) {
    final card = rooms.first;
    result['homeArea'] = card.area ?? '';
    result['homeAudience'] = card.audienceValue(preferRealOnline: true, platformEnabled: false);
    if ((card.area ?? '').isNotEmpty && _rawKeyPattern.hasMatch(card.area!)) leaks.add('home.area=${card.area}');
  }

  // ── 直播页字段:同房间 detail(登录墙/受限房不改写状态,取到首个
  // 公开在播房间为止,至多试 3 个候选)──
  final withId = rooms.where((r) => (r.roomId ?? '').trim().isNotEmpty).toList();
  for (final candidate in withId.take(3)) {
    final detail = await site.getRoomDetail(LiveRoom(roomId: candidate.roomId!, platform: id));
    final isPublicLive = detail.liveStatus == LiveStatus.live && (detail.notice ?? '').isEmpty;
    if (result['playStatus'] == null) {
      result['playStatus'] = detail.liveStatus?.name ?? '';
      result['playArea'] = detail.area ?? '';
      result['playAudience'] = detail.audienceValue(preferRealOnline: true, platformEnabled: false);
      result['playNotice'] = detail.notice ?? '';
      if ((detail.area ?? '').isNotEmpty && _rawKeyPattern.hasMatch(detail.area!)) {
        leaks.add('play.area=${detail.area}');
      }
    }
    if (isPublicLive) {
      result['playStatus'] = detail.liveStatus?.name ?? '';
      result['playArea'] = detail.area ?? '';
      result['playAudience'] = detail.audienceValue(preferRealOnline: true, platformEnabled: false);
      result['playNotice'] = detail.notice ?? '';
      // 画质名(播放页菜单直显)。
      final qualities = await site.getPlayQualites(liveroom: detail);
      final names = qualities.map((q) => q.quality).toList();
      result['qualities'] = names;
      for (final name in names) {
        if (_rawKeyPattern.hasMatch(name)) leaks.add('quality=$name');
      }
      break;
    }
  }

  // ── 对齐判定:首页卡与直播页的分类字段同源可比 ──
  final homeArea = (result['homeArea'] as String?) ?? '';
  final playArea = (result['playArea'] as String?) ?? '';
  if (homeArea.isNotEmpty && playArea.isNotEmpty) {
    result['areaAligned'] = homeArea == playArea;
  }
  result['leaks'] = leaks;
}

String _row(Map<String, Object?> r) {
  final site = (r['site'] as String).padRight(16);
  final sb = StringBuffer(site);
  if (r['error'] != null) {
    final errorText = r['error'].toString();
    sb.write(' ERROR ${errorText.substring(0, errorText.length.clamp(0, 90))}');
    return sb.toString();
  }
  sb.write(
    ' rooms=${r['rooms']} home=(${r['homeArea']},${r['homeAudience']}) '
    'play=(${r['playStatus']},${r['playArea']},${r['playAudience']})',
  );
  final notice = '${r['playNotice'] ?? ''}';
  if (notice.isNotEmpty) sb.write(' notice=$notice');
  if (r.containsKey('areaAligned')) sb.write(' aligned=${r['areaAligned']}');
  final leaks = (r['leaks'] as List?) ?? const [];
  if (leaks.isNotEmpty) sb.write('  LEAKS: ${leaks.join('; ')}');
  return sb.toString();
}

class _RealNetwork extends HttpOverrides {}
