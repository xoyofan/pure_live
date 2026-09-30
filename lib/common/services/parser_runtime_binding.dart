import 'package:logger/logger.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/core_error.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:pure_live/core/common/parser_config.dart';
import 'package:pure_live/core/common/proxy_routing.dart';
import 'package:pure_live/core/common/site_ids.dart';
import 'package:pure_live/common/services/settings/cookie_settings_controller.dart';
import 'package:pure_live/common/services/settings/log_controller.dart';
import 'package:pure_live/player/core/live_room_volume_manager.dart';

/// Registers the Flutter app's implementations behind the parsing core's
/// injection points (CoreLog runtime, proxy directive, cookies, per-room
/// volume). The same parsing sources compiled into the sidecar register
/// nothing and run anonymously.
///
/// Must run after InitialServices (SettingsService/LogController registered)
/// and before any site adapter performs a request.
void bindParserRuntimeToApp() {
  CoreLog.runtime = _AppCoreLogRuntime();
  HttpClient.proxyDirectiveProvider = () {
    final proxy = SettingsService.to.proxy;
    return buildProxyDirective(
      enabled: proxy.enableAppProxy.v,
      host: proxy.appProxyHost.v,
      port: proxy.appProxyPort.v,
    );
  };
  ParserConfig.instance = _AppCookieConfig();
  HttpError.statusCodeFormatter = (statusCode) {
    const known = {400, 401, 403, 404, 500, 502, 503};
    final key = known.contains(statusCode) ? 'http_error_$statusCode' : 'http_error_default';
    return i18n(key, args: {'statusCode': statusCode.toString()});
  };
  LiveRoomVolumeStore.reader = LiveRoomVolumeManager.getRoomVolume;
  LiveRoomVolumeStore.writer = LiveRoomVolumeManager.saveRoomVolume;
}

class _AppCoreLogRuntime implements CoreLogRuntime {
  @override
  bool get persistentLogEnabled => Get.isRegistered<LogController>() && LogController.to.enableLog;

  @override
  void write(Level level, String message, StackTrace? stackTrace) {
    switch (level) {
      case Level.debug:
        Log.d(message);
      case Level.info:
        Log.i(message);
      case Level.warning:
        Log.w(message);
      default:
        Log.e(message, stackTrace ?? StackTrace.current);
    }
  }
}

class _AppCookieConfig implements ParserConfig {
  CookieSettingsController get _cookies => SettingsService.to.cookieManager;

  @override
  String persistentCookieFor(String platform) => cookieFor(platform);

  @override
  String cookieFor(String platform) {
    switch (platform) {
      case SiteIds.bilibiliSite:
        return _cookies.bilibiliCookie.v;
      case SiteIds.huyaSite:
        return _cookies.huyaCookie.v;
      case SiteIds.douyuSite:
        return _cookies.douyuCookie.v;
      case SiteIds.douyinSite:
        return _cookies.douyinCookie.v;
      case SiteIds.kuaishouSite:
        return _cookies.kuaishouCookie.v;
      case SiteIds.twitchSite:
        return _cookies.twitchCookie.v;
      case SiteIds.soopSite:
        return _cookies.soopCookie.v;
      case SiteIds.yySite:
        return _cookies.yyCookie.v;
      default:
        return '';
    }
  }

  @override
  Object? auxiliaryFor(String platform, String key) {
    if (platform == SiteIds.bilibiliSite && key == 'bilibiliUid') {
      return _cookies.bilibiliUid.v;
    }
    return null;
  }
}
