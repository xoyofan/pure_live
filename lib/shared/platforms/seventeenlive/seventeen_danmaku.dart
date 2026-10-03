import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';

/// 17LIVE chat over the room's Ably realtime channel, verified against the
/// public endpoints (2026-10): the anonymous messenger token comes from
/// `GET https://wap-api.17app.co/api/v1/messenger/token?type=1&roomID=`
/// (custom `language`/`devicetype`/`deviceid`/`version` headers), the socket
/// is `wss://17media.realtime.ably.net/?access_token=<token>&format=json`,
/// the server's first frame is CONNECTED(action 4) and the client attaches
/// with `{action:10, channel:<liveStreamID>}`. Messages arrive as
/// action-15 envelopes whose `data` is Base64(gzip(JSON)); `type == 3` is a
/// chat comment (`content`, `displayUser.displayName`).
class SeventeenDanmakuArgs {
  SeventeenDanmakuArgs({required this.liveStreamID});

  SeventeenDanmakuArgs.fromJson(Map<String, dynamic> json) : liveStreamID = json['liveStreamID'] ?? '';

  final String liveStreamID;

  Map<String, dynamic> toJson() => <String, dynamic>{'liveStreamID': liveStreamID};
}

class SeventeenDanmaku implements LiveDanmaku {
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  void markConnected() {
    _connected = true;
  }

  @override
  void markDisconnected() {
    _connected = false;
  }

  // The Ably server emits action-0 heartbeats and ws-level pings; no client
  // keepalive frame exists. Server traffic keeps the inactivity window fed.
  @override
  int heartbeatTime = 0;

  // Ably server heartbeats (action 0) keep the session fed; no client frame.
  @override
  void heartbeat() {}

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onReconnect;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;

  WebScoketUtils? _socket;
  bool _attached = false;
  String? _token;

  static const _tokenUrl = 'https://wap-api.17app.co/api/v1/messenger/auth';

  /// Protocol debugging aid: when enabled, the last raw socket frames are
  /// retained here for diagnostic probes. Never populated in normal runs.
  static bool debugCapture = false;
  static final List<String> debugFrames = <String>[];
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  @override
  Future<void> start(dynamic args) async {
    if (args is! SeventeenDanmakuArgs || args.liveStreamID.isEmpty) {
      onClose?.call('17LIVE 弹幕参数缺失');
      return;
    }
    _token = await _fetchToken(args.liveStreamID);
    if (_token == null || _token!.isEmpty) {
      onClose?.call('17LIVE messenger token 获取失败');
      return;
    }
    _socket = WebScoketUtils(
      url:
          'wss://17media.realtime.ably.net:443/?access_token=${Uri.encodeQueryComponent(_token!)}&format=json&heartbeats=true&v=6',
      heartBeatTime: heartbeatTime,
      headers: {'Origin': 'https://17.live', 'User-Agent': _userAgent},
      onMessage: (data) {
        if (data is! String) return;
        if (debugCapture && debugFrames.length < 40) debugFrames.add(data);
        // The server opens with CONNECTED(action 4); attaching before that
        // frame is silently ignored, so the room attach waits for it.
        if (!_attached && data.contains('"action":4')) {
          _attached = true;
          _socket?.sendMessage(jsonEncode({'action': 10, 'channel': args.liveStreamID}));
        }
        for (final message in parseFrame(data)) {
          onMessage?.call(message);
        }
      },
      onReady: () {
        markConnected();
        onReady?.call();
      },
      onReconnect: () {
        markDisconnected();
        onReconnect?.call('与服务器断开连接，正在尝试重连');
      },
      onClose: (message) {
        markDisconnected();
        onClose?.call(message);
      },
    );
    _socket?.connect();
  }

  Future<String?> _fetchToken(String liveStreamID) async {
    try {
      final client = HttpClient()..userAgent = _userAgent;
      final request = await client.postUrl(Uri.parse(_tokenUrl));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('language', 'HK');
      request.headers.set('devicetype', 'WEB');
      request.headers.set('deviceid', _deviceSeed());
      request.headers.set('version', 'ddd03e19bb6c98dcbb7763dc814e50ca773960f7');
      request.headers.set(HttpHeaders.refererHeader, 'https://17.live/');
      final response = await request.close().timeout(const Duration(seconds: 12));
      final body = jsonDecode(await response.transform(utf8.decoder).join());
      client.close(force: true);
      return body is Map ? body['token']?.toString() : null;
    } catch (_) {
      return null;
    }
  }

  static String _deviceSeed() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return '2072377001.$now';
  }

  @override
  Future<void> stop() async {
    markDisconnected();
    onMessage = null;
    onReconnect = null;
    onClose = null;
    onReady = null;
    _token = null;
    _attached = false;
    debugFrames.clear();
    final socket = _socket;
    _socket = null;
    await socket?.close();
  }

  /// Pure frame decoder, also used by unit tests. Action 15 envelopes carry
  /// `messages[]` whose `data` is Base64(gzip|zlib(JSON)); only `type == 3`
  /// (chat comment) maps to a danmaku message — presence(18), viewer
  /// counts(38), gifts(13/32) and heartbeats(0) are ignored.
  static List<LiveMessage> parseFrame(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const [];
    }
    if (decoded is! Map || int.tryParse(decoded['action']?.toString() ?? '') != 15) return const [];
    final messages = decoded['messages'];
    if (messages is! List) return const [];
    final result = <LiveMessage>[];
    for (final entry in messages) {
      if (entry is! Map) continue;
      final payload = decodeDataPayload(entry['data']);
      if (payload == null) continue;
      if (payload['type'] != 3) continue;
      final text = payload['content']?.toString() ?? '';
      if (text.trim().isEmpty) continue;
      final user = payload['displayUser'];
      final name = user is Map ? user['displayName']?.toString() ?? '' : '';
      result.add(LiveMessage(type: LiveMessageType.chat, color: LiveMessageColor.white, message: text, userName: name));
    }
    return result;
  }

  /// Base64(gzip(JSON)) per field observation; the compression marker is
  /// sniffed instead of trusting the `encoding` declaration.
  static Map<String, Object?>? decodeDataPayload(Object? encoded) {
    if (encoded is! String || encoded.isEmpty) return null;
    List<int> raw;
    try {
      raw = base64.decode(encoded);
    } catch (_) {
      return null;
    }
    String text;
    try {
      if (raw.length >= 2 && raw[0] == 0x1f && raw[1] == 0x8b) {
        text = utf8.decode(gzip.decode(raw), allowMalformed: true);
      } else if (raw.length >= 2 && raw[0] == 0x78) {
        text = utf8.decode(zlib.decode(raw), allowMalformed: true);
      } else {
        text = utf8.decode(raw, allowMalformed: true);
      }
      final decoded = jsonDecode(text);
      return decoded is Map<String, Object?> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
