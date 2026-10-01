import 'dart:io';
import 'dart:async';
import 'dart:developer';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/utils.dart';
import 'package:pure_live/core/site/cc/cc_catalog.dart';
import 'package:url_launcher/url_launcher.dart';

/// APP页面跳转封装
/// * 需要参数的页面都应使用此类
/// * 如不需要参数，可以使用Get.toNamed
class AppNavigator {
  static bool _openingLiveRoom = false;
  static bool _openingOfficialCategory = false;

  /// 跳转至分类详情
  static Future<void> toCategoryDetail({required Site site, required LiveArea category}) async {
    if (CCCatalog.isOfficialEntry(category)) {
      if (_openingOfficialCategory) return;
      final uri = site.id == Sites.ccSite ? CCCatalog.officialEntryUri(category) : null;
      if (uri == null) {
        ToastUtil.show(i18n('external_browser_not_opened'));
        return;
      }
      _openingOfficialCategory = true;
      try {
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          ToastUtil.show(i18n('external_browser_not_opened'));
        }
      } catch (_) {
        ToastUtil.show(i18n('external_browser_not_opened'));
      } finally {
        _openingOfficialCategory = false;
      }
      return;
    }
    Get.toNamed(RoutePath.kAreaRooms, arguments: [site, category]);
  }

  /// 跳转至直播间
  static Future<void> toLiveRoomDetail({required LiveRoom liveRoom}) async {
    if (_openingLiveRoom) return;
    final platform = (liveRoom.platform?.trim() ?? '').toLowerCase();
    final roomId = liveRoom.roomId?.trim() ?? '';
    if (platform.isEmpty || roomId.isEmpty || !Sites.isSupported(platform)) {
      ToastUtil.show(i18n(Sites.isRetired(platform) ? 'platform_retired' : 'get_room_info_failed_retry'));
      return;
    }
    final normalizedRoom = liveRoom.platform == platform && liveRoom.roomId == roomId
        ? liveRoom
        : liveRoom.copyWith(platform: platform, roomId: roomId);
    _openingLiveRoom = true;
    try {
      final manager = GlobalPlayerService.instance.player;
      if (manager.isAppFloatingActive) {
        if (manager.currentFloatRoom == normalizedRoom) {
          manager.prepareRoomSessionReentry(normalizedRoom);
        } else {
          manager.cancelRoomSessionReentry();
        }
        await manager.closeAppFloating();
      } else {
        manager.cancelRoomSessionReentry();
      }
      // 播放页内切房只换栈顶(真源 follow_panel.dart:215-222 的
      // pushReplacement 语义:push 会让旧播放页连同其播放会话压在栈下继续
      // 存活(泄漏);replace 卸载旧页,下层浏览页保留为返回目标)。已在本
      // 播放页路由时改走既有等价方法 offAndToRoomDetail(Get.offAndToNamed),
      // 其内部重复的校验/归一对已处理参数幂等;否则维持现状入栈。
      if (Get.currentRoute == RoutePath.kLivePlay) {
        await offAndToRoomDetail(liveRoom: liveRoom);
        return;
      }
      await Get.toNamed(RoutePath.kLivePlay, arguments: normalizedRoom, parameters: {"site": platform});
    } catch (error, stackTrace) {
      log('Open live room route failed', name: 'AppNavigator', error: error, stackTrace: stackTrace);
      ToastUtil.show(i18n('get_room_info_failed_retry'));
    } finally {
      _openingLiveRoom = false;
    }
  }

  static Future<void> offAndToRoomDetail({required LiveRoom liveRoom}) async {
    final platform = (liveRoom.platform?.trim() ?? '').toLowerCase();
    final roomId = liveRoom.roomId?.trim() ?? '';
    if (platform.isEmpty || roomId.isEmpty || !Sites.isSupported(platform)) {
      ToastUtil.show(i18n(Sites.isRetired(platform) ? 'platform_retired' : 'get_room_info_failed_retry'));
      return;
    }
    final normalizedRoom = liveRoom.platform == platform && liveRoom.roomId == roomId
        ? liveRoom
        : liveRoom.copyWith(platform: platform, roomId: roomId);
    await Get.offAndToNamed(RoutePath.kLivePlay, arguments: normalizedRoom, parameters: {"site": platform});
  }

  /// 跳转至多画面同看页面。
  ///
  /// 房间分配由页面内交互完成，无需携带参数。
  static Future<void> toMultiview() async {
    await Get.toNamed(RoutePath.kMultiview);
  }

  /// 跳转至哔哩哔哩登录
  static Future toBiliBiliLogin() async {
    var contents = [i18n("sms_login"), i18n("qrcode_login")];
    if (Platform.isAndroid || Platform.isIOS) {
      var result = await Utils.showOptionDialog(contents, '', title: i18n("select_login_method"));
      if (result == i18n("sms_login")) {
        await Get.toNamed(RoutePath.kBiliBiliWebLogin);
      } else if (result == i18n("qrcode_login")) {
        await Get.toNamed(RoutePath.kBiliBiliQRLogin);
      }
    } else {
      await Get.toNamed(RoutePath.kBiliBiliQRLogin);
    }
  }
}
