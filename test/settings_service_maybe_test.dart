import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/core/config/settings_service.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';

/// 宿主未注册 GetX 运行时的安全访问契约(zishu 播放链/sidecar/单测):
/// `maybe` 返回 null 而不是抛 "SettingsService not found"——twitch/
/// kuaishou/soop/yy 适配器据此降级(cookie 空、代理直连),解析不再整链
/// 失败(2026-10-02 真机日志 twitch resolve_fail 根因)。
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final temp = await Directory.systemTemp.createTemp('settings-maybe-');
    addTearDown(() => temp.delete(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => temp.path,
    );
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
  });

  test('未注册时 maybe 返回 null(不抛 GetX not found)', () {
    expect(Get.isRegistered<SettingsService>(), isFalse);
    expect(SettingsService.maybe, isNull);
  });

  test('注册后 maybe 与 to 等价', () {
    Get.put(SettingsService(), permanent: true);
    addTearDown(Get.reset);
    expect(SettingsService.maybe, same(SettingsService.to));
  });
}
