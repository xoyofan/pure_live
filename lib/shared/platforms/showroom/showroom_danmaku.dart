import 'dart:convert';

import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';

/// SHOWROOM live comment wire protocol, verified against the public comment
/// servers (2026-10): connect to `wss://<bcsvr_host>/`, send `SUB\t<bcsvr_key>`
/// and read `MSG\t<bcsvr_key>\t<json>` frames. A JSON payload with `"t":1` is
/// a chat comment (`ac` nickname, `cm` text); `"t":2` is a gift notification.
class ShowroomDanmakuArgs {
  ShowroomDanmakuArgs({required this.host, required this.port, required this.key});

  ShowroomDanmakuArgs.fromJson(Map<String, dynamic> json)
    : host = json['host'] ?? '',
      port = json['port'] ?? 8080,
      key = json['key'] ?? '';

  final String host;
  final int port;
  final String key;

  Map<String, dynamic> toJson() => <String, dynamic>{'host': host, 'port': port, 'key': key};
}

class ShowroomDanmaku implements LiveDanmaku {
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
  int heartbeatTime = 0;

  // The comment servers define no client keepalive frame; dart's WebSocket
  // transport answers server pings on its own.
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

  @override
  Future<void> start(dynamic args) async {
    if (args is! ShowroomDanmakuArgs || args.host.isEmpty || args.key.isEmpty) {
      onClose?.call('SHOWROOM 弹幕参数缺失');
      return;
    }
    // Primary endpoint is the TLS one the web player uses; the bcsvr_port
    // plain listener stays as failover. heartBeatTime stays 0: the comment
    // servers define no client keepalive frame and quiet rooms must not be
    // churned by inactivity reconnects (dart pongs server pings itself).
    _socket = WebScoketUtils(
      url: 'wss://${args.host}/',
      backupUrl: 'ws://${args.host}:${args.port}/',
      heartBeatTime: heartbeatTime,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/140.0.0.0 Safari/537.36',
      },
      onMessage: (data) {
        if (data is! String) return;
        final message = parseFrame(data);
        if (message != null) onMessage?.call(message);
      },
      onReady: () {
        markConnected();
        onReady?.call();
        // Resubscribing on every ready also covers util-level reconnects.
        _socket?.sendMessage('SUB\t${args.key}');
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

  @override
  Future<void> stop() async {
    markDisconnected();
    onMessage = null;
    onReconnect = null;
    onClose = null;
    onReady = null;
    final socket = _socket;
    _socket = null;
    await socket?.close();
  }

  /// Pure frame decoder, also used by unit tests against captured frames.
  static LiveMessage? parseFrame(String raw) {
    if (!raw.startsWith('MSG\t')) return null;
    // The payload begins after "MSG\t<bcsvr_key>\t"; the key never contains tabs.
    final jsonStart = raw.indexOf('\t', 'MSG\t'.length);
    if (jsonStart < 0) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(raw.substring(jsonStart + 1));
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    if (decoded['t'] != 1) return null;
    final text = decoded['cm'];
    if (text is! String || text.trim().isEmpty) return null;
    final name = decoded['ac'];
    return LiveMessage(
      type: LiveMessageType.chat,
      color: LiveMessageColor.white,
      message: text,
      userName: name is String ? name : '',
    );
  }
}
