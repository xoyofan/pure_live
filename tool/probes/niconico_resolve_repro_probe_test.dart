// 临时诊断(2026-10-07 niconico 房间解析失败):真实网络下直调
// getRoomDetail('user/N') 与 getPlayUrls,打印完整错误链。
//   PURELIVE_NICONICO_RESOLVE_REPRO=1 PURELIVE_NICONICO_ROOM=user/53473980 flutter test ...
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/core/config/settings_service.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/src/shared/application/purelive_backend.dart' show PureLiveRoomResolver;
import 'package:live_parser/live_parser.dart' show RoomRequest;
import 'package:pure_live/domains/recorder/data/services/niconico_hls_input.dart' show readNiconicoMaster;
import 'package:live_parser/live_parser.dart' show UpstreamProxy;

class _RealNetwork extends HttpOverrides {}

void main() {
  final enabled = Platform.environment['PURELIVE_NICONICO_RESOLVE_REPRO'] == '1';
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final temp = await Directory.systemTemp.createTemp('nico-resolve-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => temp.path,
    );
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
    if (Platform.environment['PURELIVE_NICONICO_RESOLVE_NOGETX'] != '1') {
      Get.put(SettingsService(), permanent: true);
    }
    // app 装配同款(main.dart):niconico master 读取器注入。
    Sites.niconicoMasterReader = readNiconicoMaster;
  });

  test(
    'niconico user/N 详情解析',
    () async {
      // app 同款:启动探测出的系统代理注入 UpstreamProxy(niconico 会话层
      // 显式读取它路由)。不设则等价旧探针直连。
      final proxy = Platform.environment['PURELIVE_NICONICO_RESOLVE_PROXY'];
      if (proxy != null && proxy.isNotEmpty) {
        UpstreamProxy.configure(proxy);
        // ignore: avoid_print
        print('NICO proxy-configured $proxy');
      }
      await HttpOverrides.runWithHttpOverrides(() async {
        final room = Platform.environment['PURELIVE_NICONICO_ROOM'] ?? 'user/53473980';
        final site = Sites.of('niconico').liveSite;
        try {
          final detail = await site.getRoomDetail(LiveRoom(roomId: room, platform: 'niconico'));
          // ignore: avoid_print
          print(
            'NICO detail-ok id=${detail.roomId} title=${detail.title?.substring(0, detail.title!.length > 30 ? 30 : detail.title!.length)} status=${detail.liveStatus}',
          );
          final payload = await PureLiveRoomResolver('niconico')
              .resolveRoom(RoomRequest(site: 'niconico', roomIdOrUrl: room));
          // ignore: avoid_print
          print('NICO resolveRoom-ok streams=${payload.streams.length}');
        } catch (error, stack) {
          // ignore: avoid_print
          print('NICO detail-FAIL $error');
          // ignore: avoid_print
          print('NICO stack $stack');
        }
      }, _RealNetwork());
    },
    skip: enabled ? false : 'set PURELIVE_NICONICO_RESOLVE_REPRO=1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
