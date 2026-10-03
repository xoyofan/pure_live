import 'dart:async';
import 'dart:convert';

import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/shared/platforms/fc2live/fc2_api.dart';

/// FC2 Live chat over the same public control seat the player uses, verified
/// against the public endpoint family (2026-10): `Fc2Api.controlGrant` issues
/// the signed `control_token` + `l_ortkn` cookie, the control socket then
/// pushes `{"name":"comment","arguments":{"comments":[...]}}` batches with
/// `user_name`/`comment` fields, and stays alive on an app-level
/// `{"name":"heartbeat"...}` frame roughly every 30 seconds.
class Fc2DanmakuArgs {
  Fc2DanmakuArgs({required this.channelId});

  Fc2DanmakuArgs.fromJson(Map<String, dynamic> json) : channelId = json['channelId'] ?? '';

  final String channelId;

  Map<String, dynamic> toJson() => <String, dynamic>{'channelId': channelId};
}

class Fc2Danmaku implements LiveDanmaku {
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

  // The app-level heartbeat frame is sent from onHeartBeat.
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
  int _heartbeatId = 0;

  @override
  Future<void> start(dynamic args) async {
    if (args is! Fc2DanmakuArgs || args.channelId.isEmpty) {
      onClose?.call('FC2 弹幕参数缺失');
      return;
    }
    final Fc2ControlGrant grant;
    try {
      grant = await Fc2Api().controlGrant(args.channelId);
    } catch (error) {
      onClose?.call('FC2 控制席位获取失败');
      return;
    }
    final endpoint = grant.webSocket.replace(queryParameters: {'control_token': grant.controlToken});
    _socket = WebScoketUtils(
      url: endpoint.toString(),
      heartBeatTime: heartbeatTime,
      headers: {'Origin': Fc2Api.origin, 'User-Agent': Fc2Api.userAgent, 'Cookie': 'l_ortkn=${grant.orz}'},
      onMessage: (data) {
        if (data is! String) return;
        for (final message in parseFrame(data)) {
          onMessage?.call(message);
        }
      },
      onReady: () {
        markConnected();
        onReady?.call();
      },
      onHeartBeat: () {
        _heartbeatId += 1;
        _socket?.sendMessage(jsonEncode({'name': 'heartbeat', 'arguments': {}, 'id': _heartbeatId}));
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

  /// Pure frame decoder, also used by unit tests. Only `name: "comment"`
  /// batches carry chat; other control frames (connect_complete / hls
  /// responses / heartbeats echoes) are ignored.
  static List<LiveMessage> parseFrame(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const [];
    }
    if (decoded is! Map || decoded['name'] != 'comment') return const [];
    final arguments = decoded['arguments'];
    final comments = arguments is Map ? arguments['comments'] : null;
    if (comments is! List) return const [];
    final messages = <LiveMessage>[];
    for (final entry in comments) {
      if (entry is! Map) continue;
      final text = entry['comment']?.toString() ?? '';
      if (text.trim().isEmpty) continue;
      messages.add(
        LiveMessage(
          type: LiveMessageType.chat,
          color: LiveMessageColor.white,
          message: text,
          userName: entry['user_name']?.toString() ?? '',
        ),
      );
    }
    return messages;
  }
}
