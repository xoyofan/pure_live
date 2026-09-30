import 'package:dio/dio.dart' as dio;
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/live_url_parser.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/modules/live_play/dialogs/known_room_link_dialog.dart';
import 'package:pure_live/modules/toolbox/toolbox_direct_link_flow.dart';

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
    required String roomId,
    required String platform,
    LiveSite Function(String)? siteFor,
    bool Function()? isCurrentRoom,
    void Function(String)? notify,
  }) => _showKnownRoomAction(
    context: context,
    roomId: roomId,
    platform: platform,
    cast: false,
    siteFor: siteFor,
    isCurrentRoom: isCurrentRoom,
    notify: notify,
  );

  static Future<void> castPlayUrlByRoomId({
    required BuildContext context,
    required String roomId,
    required String platform,
    LiveSite Function(String)? siteFor,
    bool Function()? isCurrentRoom,
    void Function(String)? notify,
    Future<void> Function(String)? openCast,
  }) => _showKnownRoomAction(
    context: context,
    roomId: roomId,
    platform: platform,
    cast: true,
    siteFor: siteFor,
    isCurrentRoom: isCurrentRoom,
    notify: notify,
    openCast: openCast,
  );

  static Future<void> _showKnownRoomAction({
    required BuildContext context,
    required String roomId,
    required String platform,
    required bool cast,
    LiveSite Function(String)? siteFor,
    bool Function()? isCurrentRoom,
    void Function(String)? notify,
    Future<void> Function(String)? openCast,
  }) {
    if (!context.mounted) return Future.value();
    final showNotice = notify ?? ((String key) => ToastUtil.show(i18n(key)));
    roomId = roomId.trim();
    platform = platform.trim().toLowerCase();
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
      room: LiveRoom(roomId: roomId, platform: platform),
      cast: cast,
      flow: ToolBoxDirectLinkFlow(siteFor: siteFor),
      isCurrentRoom: isCurrentRoom ?? (() => true),
      notify: showNotice,
      openCast: openCast,
    );
  }
}
