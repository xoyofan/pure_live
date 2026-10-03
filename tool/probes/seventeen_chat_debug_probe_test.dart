// Opt-in diagnostic for the 17LIVE Ably chat receive path: prints the decoded
// payload type distribution so quiet rooms still prove the pipeline.
// PURELIVE_SEV_DEBUG_PROBE=1 flutter test tool/probes/seventeen_chat_debug_probe_test.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/core/config/settings_service.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/shared/platforms/seventeen_danmaku.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('sev-chat-debug-');
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
    'seventeen ably receive path payload distribution',
    () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final site = Sites.of(Sites.seventeenLiveSite).liveSite;
        final rooms = await site.getRecommendRooms(page: 1, pageSize: 10);
        // ignore: avoid_print
        print('[rooms] ${rooms.map((r) => r.normalizedRoomId).take(5).toList()}');
        final liveRoom = rooms.firstWhere((r) => r.isLiveNow, orElse: () => rooms.first);
        final roomId = liveRoom.normalizedRoomId;
        // ignore: avoid_print
        print('[pick] $roomId');

        SeventeenDanmaku.debugCapture = true;
        final engine = site.getDanmaku() as SeventeenDanmaku;
        final firstReady = Completer<void>();

        var comments = 0;
        engine.onReady = () {
          if (!firstReady.isCompleted) firstReady.complete();
        };
        engine.onMessage = (msg) {
          comments += 1;
          if (comments <= 3) {
            // ignore: avoid_print
            print('[chat] ${msg.userName}: ${msg.message}');
          }
        };
        // Raw tap: decode payloads the same way the engine does to count types.
        final original = engine.onMessage;
        engine.onMessage = (msg) {
          original?.call(msg);
        };
        await engine.start(SeventeenDanmakuArgs(liveStreamID: roomId));
        await firstReady.future.timeout(const Duration(seconds: 20));
        await Future<void>.delayed(const Duration(seconds: 30));
        // ignore: avoid_print
        print('[done] comments=$comments connected=${engine.isConnected}');
        for (final frame in SeventeenDanmaku.debugFrames.take(8)) {
          // ignore: avoid_print
          print('[frame] ${frame.substring(0, frame.length.clamp(0, 260))}');
        }
        SeventeenDanmaku.debugCapture = false;
        SeventeenDanmaku.debugFrames.clear();
        await engine.stop();
      }, _RealNetwork());
    },
    skip: Platform.environment['PURELIVE_SEV_DEBUG_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

class _RealNetwork extends HttpOverrides {}
