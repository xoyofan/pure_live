// Opt-in diagnostic for the Bigo chat guest flow: room discovery states plus
// a 25s raw session log (challenge/login/enter/chat). Not part of offline CI.
// PURELIVE_BIGOD_DEBUG_PROBE=1 flutter test tool/probes/bigo_chat_debug_probe_test.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/core/config/settings_service.dart';
import 'package:pure_live/shared/platforms/bigo_danmaku.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('bigo-chat-debug-');
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
    'bigo room discovery states and raw chat session',
    () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final site = Sites.of(Sites.bigoSite).liveSite;
        final rooms = await site.getRecommendRooms(page: 1, pageSize: 12);
        // ignore: avoid_print
        print('[rooms] ${rooms.length}');
        BigoDanmakuArgs? args;
        for (final room in rooms) {
          try {
            final detail = await site.getRoomDetail(LiveRoom(roomId: room.normalizedRoomId, platform: 'bigo'));
            // ignore: avoid_print
            print(
              '[detail] ${room.normalizedRoomId} live=${detail.isLiveNow} danmakuArgs=${detail.danmakuData?.runtimeType}',
            );
            if (detail.isLiveNow && args == null && detail.danmakuData is BigoDanmakuArgs) {
              args = detail.danmakuData! as BigoDanmakuArgs;
            }
          } catch (error) {
            // ignore: avoid_print
            print('[detail] ${room.normalizedRoomId} ERROR ${error.runtimeType}');
          }
        }
        // ignore: avoid_print
        print('[pick] args=$args');

        final engine = site.getDanmaku() as BigoDanmaku;
        final firstReady = Completer<void>();
        var chat = 0;
        engine.onReady = () {
          if (!firstReady.isCompleted) firstReady.complete();
        };
        engine.onMessage = (LiveMessage msg) {
          chat += 1;
          if (chat <= 3) {
            // ignore: avoid_print
            print('[chat] ${msg.userName}: ${msg.message}');
          }
        };
        engine.onClose = (msg) {
          // ignore: avoid_print
          print('[close] $msg');
        };
        if (args == null) throw StateError('no live room with danmaku args found');
        await engine.start(args);
        await firstReady.future.timeout(const Duration(seconds: 20));
        await Future<void>.delayed(const Duration(seconds: 25));
        // ignore: avoid_print
        print('[done] chat=$chat connected=${engine.isConnected}');
        await engine.stop();
      }, _RealNetwork());
    },
    skip: Platform.environment['PURELIVE_BIGOD_DEBUG_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

class _RealNetwork extends HttpOverrides {}
