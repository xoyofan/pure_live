import 'dart:async';
import 'dart:convert';

import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';

/// PandaTV chat over the public Centrifugo v1 gateway, verified against the
/// community protocol documentation (2026-10): credentials (`token`,
/// `channel`) ride on the `/v1/live/play` response; the socket is
/// `wss://chat-ws.bktv.kr/connection/websocket` with a JSON
/// connect(0)/subscribe(1) pair, transport-level ping/pong only, and chat
/// arriving inside `{"push":{"pub":{"data":{...}}}}` frames.
class PandaliveDanmakuArgs {
  PandaliveDanmakuArgs({required this.token, required this.channel});

  PandaliveDanmakuArgs.fromJson(Map<String, dynamic> json)
    : token = json['token'] ?? '',
      channel = json['channel'] ?? '';

  final String token;
  final String channel;

  Map<String, dynamic> toJson() => <String, dynamic>{'token': token, 'channel': channel};
}

class PandaliveDanmaku implements LiveDanmaku {
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

  // Centrifugo v1 keeps the connection alive with transport ping/pong, which
  // dart answers on its own; no client keepalive frame exists. A generous
  // inactivity window keeps quiet rooms from being churned by reconnects.
  @override
  int heartbeatTime = 0;

  // Centrifugo v1 has no client keepalive frame; transport ping/pong suffices.
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
    if (args is! PandaliveDanmakuArgs || args.token.isEmpty || args.channel.isEmpty) {
      onClose?.call('PandaTV 弹幕参数缺失');
      return;
    }
    _socket = WebScoketUtils(
      url: 'wss://chat-ws.bktv.kr/connection/websocket',
      heartBeatTime: heartbeatTime,
      inactivityTimeout: const Duration(minutes: 5),
      headers: {
        'Origin': 'https://www.pandalive.co.kr',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/140.0.0.0 Safari/537.36',
      },
      onMessage: (data) {
        if (data is! String) return;
        for (final message in parseFrame(data)) {
          onMessage?.call(message);
        }
      },
      onReady: () {
        markConnected();
        onReady?.call();
        // Resubscribing on every ready also covers util-level reconnects.
        _socket?.sendMessage(
          jsonEncode({
            'id': 1,
            'method': 0,
            'params': {'token': args.token, 'name': 'js', 'version': ''},
          }),
        );
        _socket?.sendMessage(
          jsonEncode({
            'id': 2,
            'method': 1,
            'params': {'channel': args.channel},
          }),
        );
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

  /// Pure frame decoder, also used by unit tests. Publication frames are
  /// `{"push":{"pub":{"data":{...}}}}`; the text and nickname keys vary by
  /// payload shape, so the common variants are tried defensively. Non-push
  /// frames (connect/subscribe replies, pings) are ignored.
  static List<LiveMessage> parseFrame(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const [];
    }
    final data = _publicationData(decoded);
    if (data == null) return const [];
    final text = _firstText([data['message'], data['msg'], data['text'], data['content']]);
    if (text.isEmpty) return const [];
    final name = _firstText([data['userNick'], data['nickname'], data['nick'], data['name'], data['userId']]);
    return [LiveMessage(type: LiveMessageType.chat, color: LiveMessageColor.white, message: text, userName: name)];
  }

  static Map? _publicationData(Object? decoded) {
    if (decoded is! Map) return null;
    final push = decoded['push'];
    if (push is! Map) return null;
    final pub = push['pub'];
    if (pub is! Map) return null;
    final data = pub['data'];
    return data is Map ? data : null;
  }

  static String _firstText(List<Object?> candidates) {
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) return candidate;
    }
    return '';
  }
}
