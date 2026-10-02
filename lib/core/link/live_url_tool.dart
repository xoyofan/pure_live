import 'package:pure_live/platforms/niconico/niconico_link.dart';
import 'package:pure_live/platforms/weibo/weibo_link.dart';
import 'package:pure_live/platforms/xiaohongshu/xiaohongshu_link.dart';
import 'package:dio/dio.dart' as dio;
import 'package:pure_live/platforms/kilakila/kilakila_api.dart';
import 'package:pure_live/platforms/kilakila/kilakila_link.dart';
import 'package:pure_live/platforms/showroom/showroom_link.dart';
import 'package:pure_live/platforms/chzzk/chzzk_link.dart';
import 'package:pure_live/platforms/liveme/liveme_api.dart';
import 'package:pure_live/platforms/liveme/liveme_link.dart';
import 'package:pure_live/platforms/tiktok/tiktok_api.dart';
import 'package:pure_live/platforms/tiktok/tiktok_link.dart';
import 'package:pure_live/platforms/youtube/youtube_api.dart';
import 'package:pure_live/platforms/youtube/youtube_link.dart';
import 'package:pure_live/platforms/bigo/bigo_link.dart';
import 'package:pure_live/platforms/pandalive/pandalive_link.dart';
import 'package:pure_live/platforms/fc2live/fc2_link.dart';
import 'package:pure_live/platforms/steambroadcast/steam_broadcast_link.dart';
import 'package:pure_live/platforms/jdlive/jd_live_link.dart';
import 'package:pure_live/platforms/kugoulive/kugou_live_link.dart';
import 'package:pure_live/platforms/baidulive/baidu_live_link.dart';
import 'package:pure_live/platforms/sixroom/sixroom_link.dart';
import 'package:pure_live/platforms/looklive/look_live_link.dart';
import 'package:pure_live/platforms/seventeenlive/seventeenlive_link.dart';

import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/link/live_short_link_session.dart';
import 'package:pure_live/core/network/live_url_parser.dart';
import 'package:pure_live/core/contracts/live_site.dart';
import 'package:pure_live/features/live/playback/dialogs/known_room_link_dialog.dart';
import 'package:pure_live/features/toolbox/toolbox_direct_link_flow.dart';
import 'package:pure_live/features/live/search/web_search_room_parser.dart';

/// UI entry points around share links. Every URL/platform decision lives in
/// [LiveUrlParser] (core) so the parsing core stays swappable; this class only
/// hosts widgets-adjacent flows (dialogs, toasts).
class LiveUrlTool {
  static Iterable<Uri> sharedHttpUris(String text) => LiveUrlParser.sharedHttpUris(text);

  static Iterable<String> sharedHttpUrls(String text) => LiveUrlParser.sharedHttpUrls(text);

  static bool containsSupportedLink(String text) => LiveUrlParser.containsSupportedLink(text);

  static Future<List<String>> parseLiveUrl(
    String text, {
    dio.Dio Function()? clientFactory,
    dio.CancelToken? cancelToken,
    Duration timeout = const Duration(seconds: 12),
  }) {
    return LiveUrlParser.parseLiveUrl(text, clientFactory: clientFactory, cancelToken: cancelToken, timeout: timeout);
  }

  static Future<void> getPlayUrlByRoomId({
    required BuildContext context,
    required LiveRoom liveroom,
    LiveSite Function(String)? siteFor,
    bool Function()? isCurrentRoom,
    void Function(String)? notify,
  }) => _showKnownRoomAction(
    context: context,
    liveroom: liveroom,
    cast: false,
    siteFor: siteFor,
    isCurrentRoom: isCurrentRoom,
    notify: notify,
  );

  static Future<void> castPlayUrlByRoomId({
    required BuildContext context,
    required LiveRoom liveroom,
    LiveSite Function(String)? siteFor,
    bool Function()? isCurrentRoom,
    void Function(String)? notify,
    Future<void> Function(String)? openCast,
  }) => _showKnownRoomAction(
    context: context,
    liveroom: liveroom,
    cast: true,
    siteFor: siteFor,
    isCurrentRoom: isCurrentRoom,
    notify: notify,
    openCast: openCast,
  );

  static Future<void> _showKnownRoomAction({
    required BuildContext context,
    required LiveRoom liveroom,
    required bool cast,
    LiveSite Function(String)? siteFor,
    bool Function()? isCurrentRoom,
    void Function(String)? notify,
    Future<void> Function(String)? openCast,
  }) {
    if (!context.mounted) return Future.value();
    final roomId = (liveroom.roomId ?? '').trim();
    final platform = (liveroom.platform ?? '').trim().toLowerCase();
    final showNotice = notify ?? ((String key) => ToastUtil.show(i18n(key)));
    if (roomId.isEmpty || platform.isEmpty) {
      showNotice('toolbox_empty_link');
      return Future.value();
    }
    if (!Sites.isSupported(platform)) {
      showNotice('toolbox_parse_failed');
      return Future.value();
    }
    return KnownRoomLinkDialog.show(
      context: context,
      liveroom: LiveRoom(roomId: roomId, platform: platform),
      cast: cast,
      flow: ToolBoxDirectLinkFlow(siteFor: siteFor),
      isCurrentRoom: isCurrentRoom ?? (() => true),
      notify: showNotice,
      openCast: openCast,
    );
  }
}
