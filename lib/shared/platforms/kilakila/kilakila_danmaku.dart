import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';

/// KilaKila live chat via the public message REST interface, verified against
/// the public endpoint (2026-10): `GET
/// https://live.kilakila.cn/LiveRoom/latestQuery?roomId=` is anonymous and
/// returns `b.data[]` rows of `{roomId, ownerUid, relativeTime, bizType,
/// content: JSON string}`. The room's guest WebSocket exists but its
/// handshake needs extra parameters, so the first version polls
/// `latestQuery` on a fixed interval and dedupes rows by `relativeTime`.
class KilakilaDanmakuArgs {
  KilakilaDanmakuArgs({required this.roomId});

  KilakilaDanmakuArgs.fromJson(Map<String, dynamic> json) : roomId = json['roomId'] ?? '';

  final String roomId;

  Map<String, dynamic> toJson() => <String, dynamic>{'roomId': roomId};
}

class KilakilaDanmaku implements LiveDanmaku {
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

  // REST polling carries its own liveness; no socket keepalive applies.
  @override
  int heartbeatTime = 0;

  // REST polling carries its own liveness.
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

  static const _latestQueryUrl = 'https://live.kilakila.cn/LiveRoom/latestQuery';
  static const _pollInterval = Duration(seconds: 4);
  static const _rowLimit = 20;

  String? _roomId;
  Timer? _pollTimer;
  final Set<String> _seenRowKeys = <String>{};
  int _consecutiveFailures = 0;

  @override
  Future<void> start(dynamic args) async {
    if (args is! KilakilaDanmakuArgs || args.roomId.isEmpty) {
      onClose?.call('KilaKila 弹幕参数缺失');
      return;
    }
    _roomId = args.roomId;
    markConnected();
    onReady?.call();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
    _poll();
  }

  Future<void> _poll() async {
    final roomId = _roomId;
    if (roomId == null) return;
    try {
      final client = HttpClient()..userAgent = _pollUserAgent;
      final request = await client.getUrl(
        Uri.parse('$_latestQueryUrl?roomId=${Uri.encodeQueryComponent(roomId)}&pageNo=1&pageSize=$_rowLimit'),
      );
      request.headers.set(HttpHeaders.refererHeader, 'https://live.kilakila.cn/');
      final response = await request.close().timeout(const Duration(seconds: 10));
      final body = jsonDecode(await response.transform(utf8.decoder).join());
      client.close(force: true);
      final rows = envelopeRows(body) ?? const [];
      _consecutiveFailures = 0;
      for (final message in parseRows(rows, seenKeys: _seenRowKeys)) {
        onMessage?.call(message);
      }
      // Bound the dedupe set so long sessions do not grow it indefinitely.
      if (_seenRowKeys.length > 2000) _seenRowKeys.removeWhere((_) => _seenRowKeys.length > 1000);
    } catch (error) {
      _consecutiveFailures += 1;
      if (_consecutiveFailures == 3) {
        onReconnect?.call('弹幕轮询连续失败，仍在重试');
      }
      if (_consecutiveFailures >= 12) {
        _pollTimer?.cancel();
        markDisconnected();
        onClose?.call('弹幕轮询持续失败，已停止');
      }
    }
  }

  @override
  Future<void> stop() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    markDisconnected();
    onMessage = null;
    onReconnect = null;
    onClose = null;
    onReady = null;
    _roomId = null;
    _seenRowKeys.clear();
  }

  static const _pollUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  /// Extracts `b.data[]` from the `{h:{code:200}, b:{data:[...]}}` envelope;
  /// null when the envelope is not a successful latest-query response.
  static List<Object?>? envelopeRows(Object? decoded) {
    if (decoded is! Map) return null;
    final header = decoded['h'];
    if (header is! Map || header['code'] != 200) return null;
    final body = decoded['b'];
    if (body is! Map) return null;
    final data = body['data'];
    return data is List ? data : null;
  }

  /// Pure row decoder, also used by unit tests. Comment rows carry a JSON
  /// string in `content` with a nickname-ish and a text-ish key; Q&A cards
  /// (bizType 2) have neither at the top level and are filtered naturally.
  /// Dedupe keys are `relativeTime:content`.
  static List<LiveMessage> parseRows(List<Object?> rows, {Set<String>? seenKeys}) {
    final messages = <LiveMessage>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final contentRaw = row['content'];
      if (contentRaw is! String || contentRaw.isEmpty) continue;
      Object? content;
      try {
        content = jsonDecode(contentRaw);
      } catch (_) {
        continue;
      }
      if (content is! Map) continue;
      final text = _firstText([content['content'], content['message'], content['msg'], content['text']]);
      if (text.isEmpty) continue;
      final name = _firstText([content['nickname'], content['nick'], content['userNickname'], content['name']]);
      final relativeTime = row['relativeTime']?.toString() ?? '';
      final key = '$relativeTime:$text:$name';
      if (seenKeys != null) {
        if (!seenKeys.add(key)) continue;
      }
      messages.add(
        LiveMessage(type: LiveMessageType.chat, color: LiveMessageColor.white, message: text, userName: name),
      );
    }
    return messages;
  }

  static String _firstText(List<Object?> candidates) {
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) return candidate;
    }
    return '';
  }
}
