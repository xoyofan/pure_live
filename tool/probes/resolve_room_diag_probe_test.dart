// One-off room resolution diagnostic: replicate the zishu resolve chain for a
// single room (URL search path + direct detail + qualities + play URLs + media
// bytes) against the real adapters.
//
//   PURELIVE_RESOLVE_DIAG=1 PURELIVE_RESOLVE_SITE=17live \
//   PURELIVE_RESOLVE_ROOM=https://17.live/en/live/29725277 \
//   flutter test tool/probes/resolve_room_diag_probe_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/platforms/sites.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'resolve diagnostic',
    () async {
      final site = Platform.environment['PURELIVE_RESOLVE_SITE'] ?? '17live';
      final input = Platform.environment['PURELIVE_RESOLVE_ROOM'] ?? '';
      await HttpOverrides.runWithHttpOverrides(() async {
        final liveSite = Sites.of(site).liveSite;

        // 1) search path (what the zishu search box hits with a pasted URL).
        try {
          final hits = await liveSite.searchRooms(input, page: 1, pageSize: 5);
          // ignore: avoid_print
          print(
            'searchRooms(url) -> ${hits.length} hits; '
            'first: ${hits.isEmpty ? '-' : '${hits.first.roomId} ${hits.first.title}'}',
          );
        } catch (error, stack) {
          // ignore: avoid_print
          print('searchRooms ERROR: $error');
          // ignore: avoid_print
          print(stack.toString().split('\n').take(10).join('\n'));
        }

        // 2) detail via normalized id extracted by the site's own search entry.
        String roomId = input;
        try {
          final hits = await liveSite.searchRooms(input);
          if (hits.isNotEmpty && (hits.first.roomId ?? '').isNotEmpty) roomId = hits.first.roomId!;
        } catch (_) {}
        try {
          final detail = await liveSite.getRoomDetail(LiveRoom(roomId: roomId, platform: site));
          // ignore: avoid_print
          print('detail -> status=${detail.liveStatus} title=${detail.title} data=${detail.data?.runtimeType}');
          final qualities = await liveSite.getPlayQualites(liveroom: detail);
          // ignore: avoid_print
          print('qualities -> ${qualities.map((q) => q.quality).toList()}');
          if (qualities.isNotEmpty) {
            final urls = await liveSite.getPlayUrls(liveroom: detail, quality: qualities.first);
            // ignore: avoid_print
            print('urls -> ${urls.length} ${urls.isEmpty ? '-' : urls.first}');
          }
        } catch (error, stack) {
          // ignore: avoid_print
          print('resolve ERROR: $error');
          // ignore: avoid_print
          print(stack.toString().split('\n').take(10).join('\n'));
        }
      }, _RealNetwork());
    },
    skip: Platform.environment['PURELIVE_RESOLVE_DIAG'] != '1',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

class _RealNetwork extends HttpOverrides {}
