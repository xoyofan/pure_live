import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';

/// Missevan (猫耳FM) live room chat over the viewer-facing gateway, verified
/// against the public endpoints (2026-10): `wss://im.missevan.com/ws?room_id=`
/// accepts an anonymous session (any base cookie from `GET /api/user/info`)
/// with `Origin: https://fm.missevan.com`. Text frames only: a `join` action
/// subscribes the room, a literal `❤️` every 30s keeps it alive, and chat
/// arrives as `{"type":"message","event":"new",...}` JSON frames.
class MissevanDanmakuArgs {
  MissevanDanmakuArgs({required this.roomId});

  MissevanDanmakuArgs.fromJson(Map<String, dynamic> json) : roomId = json['roomId'] ?? '';

  final String roomId;

  Map<String, dynamic> toJson() => <String, dynamic>{'roomId': roomId};
}

class MissevanDanmaku implements LiveDanmaku {
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

  @override
  int heartbeatTime = 30 * 1000;

  // The actual ❤️ keepalive frame is sent from onHeartBeat.
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
  String? _cookie;

  static const _origin = 'https://fm.missevan.com';
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  @override
  Future<void> start(dynamic args) async {
    if (args is! MissevanDanmakuArgs || args.roomId.isEmpty) {
      onClose?.call('猫耳弹幕参数缺失');
      return;
    }
    _cookie = await _anonymousCookie();
    _socket = WebScoketUtils(
      url: 'wss://im.missevan.com/ws?room_id=${args.roomId}',
      heartBeatTime: heartbeatTime,
      headers: {
        'Origin': _origin,
        'User-Agent': _userAgent,
        'Pragma': 'no-cache',
        if (_cookie != null && _cookie!.isNotEmpty) 'Cookie': _cookie!,
      },
      onMessage: (data) {
        if (data is! String) return;
        // The server's own keepalive is a literal ❤️ frame; skip parsing it.
        if (data == '❤️') return;
        for (final message in parseFrame(data)) {
          onMessage?.call(message);
        }
      },
      onReady: () {
        markConnected();
        onReady?.call();
        _socket?.sendMessage(
          jsonEncode({
            'action': 'join',
            'uuid': _joinUuid(),
            'type': 'room',
            'room_id': int.tryParse(args.roomId) ?? 0,
          }),
        );
      },
      onHeartBeat: () => _socket?.sendMessage('❤️'),
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

  /// Anonymous session cookie; the gateway accepts any base cookie, and an
  /// empty result must not block the connection attempt.
  Future<String> _anonymousCookie() async {
    try {
      final client = HttpClient()..userAgent = _userAgent;
      final request = await client.getUrl(Uri.parse('https://fm.missevan.com/api/user/info'));
      request.headers.set(HttpHeaders.refererHeader, '$_origin/');
      final response = await request.close().timeout(const Duration(seconds: 10));
      await response.drain<void>();
      final cookies = response.headers['set-cookie'] ?? const [];
      return cookies.map((raw) => raw.split(';').first.trim()).where((part) => part.isNotEmpty).join('; ');
    } catch (_) {
      return '';
    }
  }

  static String _joinUuid() {
    final random = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final suffix = List.generate(8, (i) => ((random.hashCode >> i) & 0xf).toRadixString(16)).join();
    return '$random$suffix';
  }

  @override
  Future<void> stop() async {
    markDisconnected();
    onMessage = null;
    onReconnect = null;
    onClose = null;
    onReady = null;
    _cookie = null;
    final socket = _socket;
    _socket = null;
    await socket?.close();
  }

  /// Pure frame decoder, also used by unit tests. Chat is
  /// `{"type":"message","event":"new","message":{...},"user":{...}}`; other
  /// types (room/gift/member/notify/statistics) are ignored.
  static List<LiveMessage> parseFrame(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const [];
    }
    if (decoded is! Map) return const [];
    if (decoded['type'] != 'message' || decoded['event'] != 'new') return const [];
    final payload = decoded['message'];
    final text = payload is Map
        ? (payload['message'] ?? payload['content'] ?? '')?.toString() ?? ''
        : payload?.toString() ?? '';
    if (text.trim().isEmpty) return const [];
    final user = decoded['user'];
    final name = user is Map ? user['username']?.toString() ?? '' : '';
    return [LiveMessage(type: LiveMessageType.chat, color: LiveMessageColor.white, message: text, userName: name)];
  }
}
