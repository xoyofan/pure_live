import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';

/// CHZZK live chat, protocol verified against the public endpoints (2026-10):
/// anonymous READ sessions come from `comm-api.game.naver.com/nng_main/v1/
/// chats/access-token?channelId=...&chatType=STREAMING`, and the socket is
/// `wss://kr-ss{N}.chat.naver.net/chat` where N is derived from the chat
/// channel id. Text frames carry `{ver, cmd, ...}` envelopes: register(100)
/// → ready(10100 with sid) → recent(5101/15101) → chat(93101), keepalive is a
/// cmd-0 ping every ~20s answered by a cmd-10000 pong.
///
/// Transport note: Naver's chat edge blackholes dart's default no-ALPN
/// ClientHello, so the socket is a minimal RFC6455 client over
/// RawSecureSocket with ALPN http/1.1 (same transport the probe validated to
/// the REST endpoints).
class ChzzkDanmakuArgs {
  ChzzkDanmakuArgs({required this.chatChannelId, this.accessToken = ''});

  ChzzkDanmakuArgs.fromJson(Map<String, dynamic> json)
    : chatChannelId = json['chatChannelId'] ?? '',
      accessToken = json['accessToken'] ?? '';

  final String chatChannelId;
  final String accessToken;

  Map<String, dynamic> toJson() => <String, dynamic>{'chatChannelId': chatChannelId, 'accessToken': accessToken};
}

class ChzzkDanmaku implements LiveDanmaku {
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
  int heartbeatTime = 20 * 1000;

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onReconnect;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;

  _ChzzkSocket? _socket;
  String? _chatChannelId;
  String? _accessToken;
  String? _sid;
  bool _stopping = false;
  Timer? _pingTimer;

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  @override
  Future<void> start(dynamic args) async {
    if (args is! ChzzkDanmakuArgs || args.chatChannelId.isEmpty) {
      onClose?.call('CHZZK 弹幕参数缺失');
      return;
    }
    _chatChannelId = args.chatChannelId;
    _accessToken = args.accessToken;
    if (_accessToken!.isEmpty) {
      _accessToken = await _fetchAccessToken(args.chatChannelId);
      if (_accessToken == null || _accessToken!.isEmpty) {
        onClose?.call('CHZZK access token 获取失败');
        return;
      }
    }
    unawaited(_run());
  }

  Future<void> _run() async {
    var failures = 0;
    var reportedReconnect = false;
    while (!_stopping) {
      _ChzzkSocket? socket;
      try {
        final host = _chatHost(_chatChannelId!);
        socket = await _ChzzkSocket.connect(host);
        _socket = socket;
        failures = 0;
        reportedReconnect = false;
        final ready = Completer<void>();
        socket.onText = (text) => _handleFrame(text, ready);
        socket.onClose = () {
          if (!ready.isCompleted) ready.complete();
        };
        markConnected();
        _sid = null;
        socket.sendText(registerFrame(_chatChannelId!, _accessToken!));
        await ready.future.timeout(const Duration(seconds: 15));
        onReady?.call();
        await for (final _ in socket.messages) {}
      } catch (error) {
        CoreLog.error(error);
      } finally {
        _pingTimer?.cancel();
        _pingTimer = null;
        _socket = null;
        try {
          await socket?.close();
        } catch (_) {}
      }
      if (_stopping) break;
      markDisconnected();
      failures += 1;
      if (failures >= 8) {
        onClose?.call('重连超过最大次数，与服务器断开连接');
        return;
      }
      if (!reportedReconnect) {
        reportedReconnect = true;
        onReconnect?.call('与服务器断开连接，正在尝试重连');
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  Future<String?> _fetchAccessToken(String chatChannelId) async {
    try {
      final client = HttpClient()..userAgent = _userAgent;
      final request = await client.getUrl(
        Uri.parse(
          'https://comm-api.game.naver.com/nng_main/v1/chats/access-token'
          '?channelId=${Uri.encodeQueryComponent(chatChannelId)}&chatType=STREAMING',
        ),
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 12));
      final body = jsonDecode(await response.transform(utf8.decoder).join());
      client.close(force: true);
      final content = body is Map ? body['content'] : null;
      return content is Map ? content['accessToken']?.toString() : null;
    } catch (_) {
      return null;
    }
  }

  void _handleFrame(String text, Completer<void> ready) {
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;
    final cmd = int.tryParse(decoded['cmd']?.toString() ?? '') ?? 0;
    switch (cmd) {
      case 10100:
        final body = decoded['bdy'];
        _sid = body is Map ? body['sid']?.toString() ?? '' : '';
        if (!ready.isCompleted) ready.complete();
        final recent = recentFrame(_chatChannelId ?? '', _sid ?? '');
        if (recent != null) _socket?.sendText(recent);
      case 0:
        _socket?.sendText(pongFrame(_sid ?? ''));
      case 93101:
        for (final message in parseChatFrame(text)) {
          onMessage?.call(message);
        }
      default:
        break;
    }
  }

  @override
  void heartbeat() {
    // The cmd-0 ping is driven by the util's heartbeat timer.
    _socket?.sendText(pingFrame());
  }

  @override
  Future<void> stop() async {
    _stopping = true;
    markDisconnected();
    onMessage = null;
    onReconnect = null;
    onClose = null;
    onReady = null;
    _chatChannelId = null;
    _accessToken = null;
    final socket = _socket;
    _socket = null;
    try {
      await socket?.close();
    } catch (_) {}
  }

  // ── pure frame helpers, also used by unit tests ─────────────────────────

  static String _chatHost(String chatChannelId) {
    final index = chatChannelId.codeUnits.fold<int>(0, (sum, code) => sum + code).abs() % 9 + 1;
    return 'kr-ss$index.chat.naver.net';
  }

  static String registerFrame(String chatChannelId, String accessToken) => jsonEncode({
    'ver': '2',
    'cmd': 100,
    'svcid': 'game',
    'cid': chatChannelId,
    'tid': 1,
    'bdy': {'uid': null, 'devType': 2001, 'accTkn': accessToken, 'auth': 'READ'},
  });

  static String? recentFrame(String chatChannelId, String sid) {
    if (sid.isEmpty) return null;
    return jsonEncode({
      'ver': '2',
      'cmd': 5101,
      'cid': chatChannelId,
      'sid': sid,
      'tid': 2,
      'bdy': {'recentMessageCount': 50},
    });
  }

  static String pingFrame() => jsonEncode({'ver': '2', 'cmd': 0});

  static String pongFrame(String sid) => jsonEncode({'ver': '2', 'cmd': 10000, 'sid': sid});

  /// cmd-93101 chat decode: `bdy.messageList[]` with `msg` text and a
  /// `profile` JSON string holding `nickname`.
  static List<LiveMessage> parseChatFrame(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const [];
    }
    if (decoded is! Map || int.tryParse(decoded['cmd']?.toString() ?? '') != 93101) return const [];
    final body = decoded['bdy'];
    final list = body is Map ? body['messageList'] : null;
    if (list is! List) return const [];
    final messages = <LiveMessage>[];
    for (final entry in list) {
      if (entry is! Map) continue;
      final text = entry['msg']?.toString() ?? '';
      if (text.trim().isEmpty) continue;
      var name = '';
      final profile = entry['profile'];
      if (profile is String && profile.isNotEmpty) {
        try {
          final decodedProfile = jsonDecode(profile);
          if (decodedProfile is Map) name = decodedProfile['nickname']?.toString() ?? '';
        } catch (_) {}
      }
      messages.add(
        LiveMessage(type: LiveMessageType.chat, color: LiveMessageColor.white, message: text, userName: name),
      );
    }
    return messages;
  }
}

/// Minimal RFC6455 client over RawSecureSocket with ALPN http/1.1, for hosts
/// that blackhole dart's default no-ALPN TLS (Naver chat edge). One frame per
/// WebSocket message is expected from this service, so fragmentation is not
/// reassembled beyond continuation support.
class _ChzzkSocket {
  _ChzzkSocket._(this._socket);

  static Future<_ChzzkSocket> connect(String host) async {
    final address = (await InternetAddress.lookup(host)).where((a) => a.type == InternetAddressType.IPv4).first;
    final socket = await RawSecureSocket.connect(
      address,
      443,
      supportedProtocols: ['http/1.1'],
      timeout: const Duration(seconds: 12),
    );
    final key = base64.encode(List<int>.generate(16, (_) => Random.secure().nextInt(256)));
    socket.write(
      utf8.encode(
        'GET /chat HTTP/1.1\r\n'
        'Host: $host\r\n'
        'Upgrade: websocket\r\n'
        'Connection: Upgrade\r\n'
        'Sec-WebSocket-Key: $key\r\n'
        'Sec-WebSocket-Version: 13\r\n'
        'Origin: https://chzzk.naver.com\r\n'
        'User-Agent: ${ChzzkDanmaku._userAgent}\r\n'
        '\r\n',
      ),
    );

    final completer = Completer<String>();
    final buffer = BytesBuilder();
    late final StreamSubscription<RawSocketEvent> subscription;
    subscription = socket.listen((event) {
      if (completer.isCompleted) return;
      if (event == RawSocketEvent.read) {
        buffer.add(socket.read()!);
        final head = utf8.decode(buffer.toBytes(), allowMalformed: true);
        final end = head.indexOf('\r\n\r\n');
        if (end >= 0) {
          subscription.cancel();
          completer.complete(head.substring(0, end + 4));
        }
      } else if (event == RawSocketEvent.closed || event == RawSocketEvent.readClosed) {
        if (!completer.isCompleted) completer.completeError(const SocketException('closed during handshake'));
      }
    });
    final response = await completer.future.timeout(const Duration(seconds: 12));
    final statusLine = response.substring(0, response.indexOf('\r\n'));
    if (!statusLine.contains(' 101 ')) throw StateError('websocket upgrade refused: $statusLine');

    final client = _ChzzkSocket._(socket);
    client._handshakeRemainder = buffer.toBytes().sublist(utf8.encode(response).length);
    client._listen();
    return client;
  }

  final RawSecureSocket _socket;
  List<int> _handshakeRemainder = const [];
  final BytesBuilder _buffer = BytesBuilder();
  final StreamController<String> _messages = StreamController<String>.broadcast();

  Function(String text)? onText;
  Function()? onClose;

  Stream<String> get messages => _messages.stream;

  void _listen() {
    _buffer.add(_handshakeRemainder);
    _handshakeRemainder = const [];
    late final StreamSubscription<RawSocketEvent> subscription;
    subscription = _socket.listen(
      (event) {
        if (event == RawSocketEvent.read) {
          _buffer.add(_socket.read()!);
          _drainFrames(subscription);
        } else if (event == RawSocketEvent.closed || event == RawSocketEvent.readClosed) {
          subscription.cancel();
          _messages.close();
          onClose?.call();
        }
      },
      onError: (Object error) {
        _messages.close();
        onClose?.call();
      },
    );
  }

  void _drainFrames(StreamSubscription<RawSocketEvent> subscription) {
    final bytes = _buffer.takeBytes();
    var offset = 0;
    while (offset + 2 <= bytes.length) {
      final opcode = bytes[offset] & 0x0f;
      final masked = (bytes[offset + 1] & 0x80) != 0;
      var length = bytes[offset + 1] & 0x7f;
      var headerLength = 2;
      if (length == 126) {
        if (offset + 4 > bytes.length) break;
        length = (bytes[offset + 2] << 8) | bytes[offset + 3];
        headerLength = 4;
      } else if (length == 127) {
        if (offset + 10 > bytes.length) break;
        length = 0;
        for (var i = 0; i < 8; i++) {
          length = (length << 8) | bytes[offset + 2 + i];
        }
        headerLength = 10;
      }
      final maskOffset = offset + headerLength;
      final maskLength = masked ? 4 : 0;
      final payloadStart = maskOffset + maskLength;
      final frameEnd = payloadStart + length;
      if (frameEnd > bytes.length) {
        _buffer.add(bytes.sublist(offset));
        return;
      }
      final payload = bytes.sublist(payloadStart, frameEnd);
      offset = frameEnd;
      switch (opcode) {
        case 0x1:
        case 0x2:
          final text = utf8.decode(payload, allowMalformed: true);
          onText?.call(text);
          _messages.add(text);
        case 0x8:
          subscription.cancel();
          onClose?.call();
          return;
        case 0x9:
          _sendFrame(0xA, payload);
        default:
          break;
      }
    }
  }

  Future<void> sendText(String text) => _sendFrame(0x1, utf8.encode(text));

  Future<void> _sendFrame(int opcode, List<int> payload) async {
    final mask = List<int>.generate(4, (_) => Random.secure().nextInt(256));
    final header = <int>[0x80 | opcode];
    if (payload.length < 126) {
      header.add(0x80 | payload.length);
    } else if (payload.length <= 0xffff) {
      header.addAll([0x80 | 126, (payload.length >> 8) & 0xff, payload.length & 0xff]);
    } else {
      header.add(0x80 | 127);
      for (var shift = 56; shift >= 0; shift -= 8) {
        header.add((payload.length >> shift) & 0xff);
      }
    }
    header.addAll(mask);
    final masked = [for (var i = 0; i < payload.length; i++) payload[i] ^ mask[i % 4]];
    _socket.write([...header, ...masked]);
  }

  Future<void> close() async {
    try {
      await _sendFrame(0x8, utf8.encode('1000'));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      _socket.shutdown(SocketDirection.both);
    } catch (_) {}
  }
}
