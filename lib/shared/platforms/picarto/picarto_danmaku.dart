import 'dart:async';
import 'dart:convert';

import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';

/// Picarto chat over the public gateway, verified against the public endpoint
/// (2026-10): `wss://chat.picarto.tv/chat/token=<jwt>` upgrades anonymously
/// with an empty token (JWT is only required to send). Clients introduce
/// themselves with a fixed set of `{"type":...}` init frames, keep the socket
/// alive with a `__ping__` frame roughly every 50 seconds, and receive chat
/// as `{"t":"c","m":[...]}` batches (`n` nickname, `m` text, `rn` channel).
class PicartoDanmakuArgs {
  PicartoDanmakuArgs({required this.channelName, this.jwt = ''});

  PicartoDanmakuArgs.fromJson(Map<String, dynamic> json)
    : channelName = json['channelName'] ?? '',
      jwt = json['jwt'] ?? '';

  final String channelName;
  final String jwt;

  Map<String, dynamic> toJson() => <String, dynamic>{'channelName': channelName, 'jwt': jwt};
}

class PicartoDanmaku implements LiveDanmaku {
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
  int heartbeatTime = 50 * 1000;

  // The actual __ping__ frame is sent from onHeartBeat.
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
  String? _channelName;

  @override
  Future<void> start(dynamic args) async {
    if (args is! PicartoDanmakuArgs || args.channelName.isEmpty) {
      onClose?.call('Picarto 弹幕参数缺失');
      return;
    }
    _channelName = args.channelName.toLowerCase();
    _socket = WebScoketUtils(
      url: 'wss://chat.picarto.tv/chat/token=${args.jwt}',
      heartBeatTime: heartbeatTime,
      headers: {'Origin': 'https://picarto.tv', 'User-Agent': _picartoUserAgent},
      onMessage: (data) {
        if (data is! String) return;
        for (final message in parseFrame(data, channelName: _channelName)) {
          onMessage?.call(message);
        }
      },
      onReady: () {
        markConnected();
        onReady?.call();
        for (final type in const [
          'welcomeMessage',
          'accessLevelMessage',
          'multistreamMessage',
          'settings',
          'topChips',
        ]) {
          _socket?.sendMessage(jsonEncode({'type': type}));
        }
        // Latest history page first; older pages only matter for scrollback.
        _socket?.sendMessage(jsonEncode({'type': 'chatNext', 'page': 1, 'paginated': false}));
      },
      onHeartBeat: () => _socket?.sendMessage(jsonEncode({'type': 'ping', 'message': '__ping__'})),
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
    _channelName = null;
    final socket = _socket;
    _socket = null;
    await socket?.close();
  }

  /// Pure frame decoder, also used by unit tests. Chat batches are
  /// `{"t":"c","m":[...]}`; when [channelName] is given only entries whose
  /// `rn` (or `c`) match are returned — the anonymous socket may carry
  /// multiple channels. Other `t` values (nk/ns/nf events) are ignored.
  static List<LiveMessage> parseFrame(String raw, {String? channelName}) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const [];
    }
    if (decoded is! Map || decoded['t'] != 'c' || decoded['m'] is! List) return const [];
    final messages = <LiveMessage>[];
    for (final entry in decoded['m'] as List) {
      if (entry is! Map) continue;
      if (entry['t'] != 'c') continue;
      final text = entry['m']?.toString() ?? '';
      if (text.trim().isEmpty) continue;
      final entryChannel = (entry['rn']?.toString() ?? entry['c']?.toString() ?? '').toLowerCase();
      if (channelName != null && channelName.isNotEmpty && entryChannel != channelName) continue;
      messages.add(
        LiveMessage(
          type: LiveMessageType.chat,
          color: LiveMessageColor.white,
          message: text,
          userName: entry['n']?.toString() ?? '',
        ),
      );
    }
    return messages;
  }
}

const _picartoUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';
