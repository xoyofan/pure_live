import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';

/// TwitCasting live comment protocol, verified against the public endpoint
/// (2026-10): POST `https://twitcasting.tv/eventpubsuburl.php` with the movie
/// id returns a signed, expiring WebSocket URL; the stream sends JSON arrays
/// of comment objects (`message`, `from_user.name`). No keepalive frame.
class TwitcastingDanmakuArgs {
  TwitcastingDanmakuArgs({required this.movieId, this.password = ''});

  TwitcastingDanmakuArgs.fromJson(Map<String, dynamic> json)
    : movieId = json['movieId'] ?? '',
      password = json['password'] ?? '';

  final String movieId;
  final String password;

  Map<String, dynamic> toJson() => <String, dynamic>{'movieId': movieId, 'password': password};
}

class TwitcastingDanmaku implements LiveDanmaku {
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

  // The pubsub stream has no client keepalive frame (protocol note verified
  // upstream); dart's WebSocket transport answers server pings itself.
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

  // The pubsub URL carries an expiring signature, so every (re)connect needs a
  // fresh POST. Reconnects are bounded per session and the counter resets on
  // each successful connection, matching the bounded behaviour of
  // WebScoketUtils for the platforms whose endpoint is static.
  static const _maxConsecutiveFailures = 8;
  static const _reconnectDelay = Duration(seconds: 3);
  WebSocket? _socket;

  @override
  Future<void> start(dynamic args) async {
    if (args is! TwitcastingDanmakuArgs || args.movieId.isEmpty) {
      onClose?.call('TwitCasting 弹幕参数缺失');
      return;
    }
    unawaited(_run(args));
  }

  Future<void> _run(TwitcastingDanmakuArgs args) async {
    var failures = 0;
    var reportedReconnect = false;
    while (!_stopping) {
      WebSocket? socket;
      try {
        final url = await _fetchPubSubUrl(args);
        socket = await WebSocket.connect(
          url,
          headers: {'User-Agent': _userAgent, 'Origin': 'https://twitcasting.tv'},
        ).timeout(const Duration(seconds: 10));
        _socket = socket;
        failures = 0;
        reportedReconnect = false;
        markConnected();
        onReady?.call();
        await for (final data in socket) {
          if (data is! String) continue;
          for (final message in parseFrame(data)) {
            onMessage?.call(message);
          }
        }
        // Server closed the stream (e.g. the live ended).
      } catch (error) {
        CoreLog.error(error);
      } finally {
        _socket = null;
        try {
          socket?.close().timeout(const Duration(seconds: 2), onTimeout: () {});
        } catch (_) {}
      }
      if (_stopping) break;
      markDisconnected();
      failures++;
      if (failures >= _maxConsecutiveFailures) {
        onClose?.call('重连超过最大次数，与服务器断开连接');
        return;
      }
      if (!reportedReconnect) {
        reportedReconnect = true;
        onReconnect?.call('与服务器断开连接，正在尝试重连');
      }
      await Future<void>.delayed(_reconnectDelay);
    }
  }

  bool _stopping = false;

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  Future<String> _fetchPubSubUrl(TwitcastingDanmakuArgs args) async {
    final data = await HttpClient.instance.postJson(
      'https://twitcasting.tv/eventpubsuburl.php',
      data: {'movie_id': args.movieId, 'password': args.password},
      header: {'User-Agent': _userAgent, 'Referer': 'https://twitcasting.tv/', 'Accept': '*/*'},
      formUrlEncoded: true,
    );
    final url = data is Map ? data['url']?.toString() ?? '' : '';
    final uri = Uri.tryParse(url);
    final hostOk = uri != null && (uri.host == 'twitcasting.tv' || uri.host.endsWith('.twitcasting.tv'));
    if (!hostOk || !{'wss', 'ws'}.contains(uri.scheme)) {
      throw const FormatException('TwitCasting pubsub url is not a twitcasting.tv websocket');
    }
    return url;
  }

  @override
  Future<void> stop() async {
    _stopping = true;
    markDisconnected();
    onMessage = null;
    onReconnect = null;
    onClose = null;
    onReady = null;
    final socket = _socket;
    _socket = null;
    try {
      await socket?.close().timeout(const Duration(seconds: 2), onTimeout: () {});
    } catch (_) {}
  }

  /// Pure frame decoder, also used by unit tests against captured frames.
  /// A frame is one or more newline-separated JSON arrays of comment objects;
  /// entries without a message text are control records and are ignored.
  static List<LiveMessage> parseFrame(String raw) {
    final messages = <LiveMessage>[];
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      Object? decoded;
      try {
        decoded = jsonDecode(trimmed);
      } catch (_) {
        continue;
      }
      if (decoded is! List) continue;
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final text = entry['message'];
        if (text is! String || text.trim().isEmpty) continue;
        final user = entry['from_user'];
        final name = user is Map && user['name'] is String ? user['name'] as String : '';
        messages.add(
          LiveMessage(type: LiveMessageType.chat, color: LiveMessageColor.white, message: text, userName: name),
        );
      }
    }
    return messages;
  }
}
