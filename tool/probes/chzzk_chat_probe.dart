// Opt-in standalone probe (dart:io only, no package imports) for the CHZZK
// chat WebSocket protocol. Prints directory -> live-detail -> WS frames so the
// danmaku adapter can be implemented against verified wire formats.
//
// TLS note: Naver hosts blackhole dart's default no-ALPN ClientHello on some
// networks, so both REST and WebSocket here offer ALPN http/1.1 explicitly via
// RawSecureSocket.
// Run: dart run tool/probes/chzzk_chat_probe.dart [seconds]
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const userAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';
const apiHost = 'api.chzzk.naver.com';
const webOrigin = 'https://chzzk.naver.com';

Future<Object?> _getJson(String host, String path, {Map<String, String>? query}) async {
  final address = (await InternetAddress.lookup(host)).where((a) => a.type == InternetAddressType.IPv4).first;
  final socket = await RawSecureSocket.connect(
    address,
    443,
    supportedProtocols: ['http/1.1'],
    timeout: const Duration(seconds: 12),
  );
  final queryText = (query == null || query.isEmpty) ? '' : Uri(queryParameters: query).query;
  final requestText =
      'GET $path${queryText.isEmpty ? '' : '?$queryText'} HTTP/1.1\r\n'
      'Host: $host\r\n'
      'User-Agent: $userAgent\r\n'
      'Accept: application/json, text/plain, */*\r\n'
      'Origin: $webOrigin\r\n'
      'Referer: $webOrigin/\r\n'
      'Connection: close\r\n'
      '\r\n';
  final chunks = <int>[];
  final done = Completer<List<int>>();
  late final StreamSubscription<RawSocketEvent> subscription;
  subscription = socket.listen((event) {
    if (event == RawSocketEvent.read) {
      chunks.addAll(socket.read()!);
    } else if (event == RawSocketEvent.closed || event == RawSocketEvent.readClosed) {
      subscription.cancel();
      done.complete(chunks);
    }
  });
  socket.write(utf8.encode(requestText));
  final raw = await done.future.timeout(const Duration(seconds: 15));
  await socket.close();

  // Byte-level header/body split keeps multi-byte UTF-8 intact across reads.
  final headerEnd = _indexOf(raw, [13, 10, 13, 10]);
  final headerBytes = raw.sublist(0, headerEnd);
  final head = utf8.decode(headerBytes, allowMalformed: true);
  final statusLine = head.substring(0, head.indexOf('\r\n'));
  stdout.writeln('[rest] $path -> $statusLine');
  var bodyBytes = raw.sublist(headerEnd + 4);
  if (RegExp(r'transfer-encoding:\s*chunked', caseSensitive: false).hasMatch(head)) {
    bodyBytes = _dechunkBytes(bodyBytes);
  }
  final decoded = jsonDecode(utf8.decode(bodyBytes));
  if (decoded is! Map) throw StateError('unexpected envelope');
  return decoded['content'];
}

int _indexOf(List<int> haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var matched = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        matched = false;
        break;
      }
    }
    if (matched) return i;
  }
  return -1;
}

List<int> _dechunkBytes(List<int> input) {
  final out = <int>[];
  var offset = 0;
  while (offset < input.length) {
    final lineEnd = _indexOf(input.sublist(offset, (offset + 64).clamp(0, input.length)), [13, 10]);
    if (lineEnd < 0) break;
    final line = utf8.decode(input.sublist(offset, offset + lineEnd), allowMalformed: true);
    final size = int.tryParse(line.split(';').first.trim(), radix: 16);
    if (size == null || size == 0) break;
    final start = offset + lineEnd + 2;
    out.addAll(input.sublist(start, start + size));
    offset = start + size + 2;
  }
  return out;
}

Future<void> main(List<String> args) async {
  final observeSeconds = int.tryParse(args.firstOrNull ?? '') ?? 14;

  final override = args.length > 1 ? args[1] : '';
  final lives = await _getJson(apiHost, '/service/v1/lives', query: {'size': '10'});
  final rows = lives is Map && lives['data'] is List ? lives['data'] as List : const [];
  if (rows.isEmpty) throw StateError('directory returned no rows');
  final channel = override.isEmpty
      ? (rows.first as Map)['channel'] as Map?
      : (rows
                .map((r) => (r as Map)['channel'])
                .firstWhere((c) => c is Map && c['channelId']?.toString() == override, orElse: () => null)
            as Map?);
  final channelId = channel?['channelId']?.toString() ?? '';
  stdout.writeln('[dir] rows=${rows.length} firstChannel=$channelId name=${channel?['channelName']}');

  final detail = (await _getJson(apiHost, '/service/v3.1/channels/$channelId/live-detail')) as Map?;
  if (detail == null) throw StateError('live-detail returned null');
  stdout.writeln('[detail] status=${detail['status']} liveId=${detail['liveId']}');
  stdout.writeln('[detail] chatChannelId=${detail['chatChannelId']}');
  final interesting = detail.keys
      .where((key) => key.toLowerCase().contains('chat') || key.toLowerCase().contains('message'))
      .toList();
  stdout.writeln('[detail] chat-related keys: $interesting');
  final chatChannelId = detail['chatChannelId']?.toString() ?? '';
  if (chatChannelId.isEmpty) throw StateError('chatChannelId missing');

  // Access token for the anonymous READ session.
  final tokenContent = await _getJson(
    'comm-api.game.naver.com',
    '/nng_main/v1/chats/access-token',
    query: {'channelId': chatChannelId, 'chatType': 'STREAMING'},
  );
  final tokenMap = tokenContent is Map ? tokenContent : const {};
  final accessToken = tokenMap['accessToken']?.toString() ?? '';
  stdout.writeln(
    '[token] accessToken=${accessToken.isEmpty ? '(empty)' : '${accessToken.length}B'} extraToken=${(tokenMap['extraToken']?.toString() ?? '').length}B',
  );
  if (accessToken.isEmpty) throw StateError('access token missing');

  // Host selection mirrors the web client: sum of chatChannelId char codes % 9 + 1.
  final hostIndex = chatChannelId.codeUnits.fold<int>(0, (sum, code) => sum + code).abs() % 9 + 1;
  final host = 'kr-ss$hostIndex.chat.naver.net';
  stdout.writeln('[ws] target $host/chat');

  final client = await _ChzzkChatSocket.connect(host);
  stdout.writeln('[ws] connected (alpn=${client.negotiatedProtocol})');
  await client.sendText(
    jsonEncode({
      'ver': '2',
      'cmd': 100,
      'svcid': 'game',
      'cid': chatChannelId,
      'tid': 1,
      'bdy': {'uid': null, 'devType': 2001, 'accTkn': accessToken, 'auth': 'READ'},
    }),
  );
  stdout.writeln('[->] cmd100 register sent');

  var sawChat = false;
  final done = Completer<void>();
  var sid = '';
  client.onText = (text) {
    final preview = text.length > 400 ? '${text.substring(0, 400)}…(${text.length})' : text;
    stdout.writeln('[<-] $preview');
    try {
      final frame = jsonDecode(text) as Map;
      final cmd = int.tryParse(frame['cmd']?.toString() ?? '') ?? 0;
      if (cmd == 10100) {
        final bdy = frame['bdy'];
        sid = bdy is Map ? bdy['sid']?.toString() ?? '' : '';
        stdout.writeln('[<-] registered sid=$sid');
        // Pull recent messages to prove the read path even on quiet rooms.
        requestRecent(client, chatChannelId, sid);
      } else if (cmd == 0) {
        client.sendText(jsonEncode({'ver': '2', 'cmd': 10000, 'sid': sid}));
        stdout.writeln('[->] cmd10000 pong');
      } else if (cmd == 93101) {
        final bdy = frame['bdy'];
        final list = bdy is Map ? bdy['messageList'] : null;
        if (list is List && list.isNotEmpty) {
          sawChat = true;
          for (final entry in list.whereType<Map>().take(3)) {
            final profile = entry['profile'];
            String name = '';
            if (profile is String) {
              try {
                final decoded = jsonDecode(profile);
                if (decoded is Map) name = decoded['nickname']?.toString() ?? '';
              } catch (_) {}
            }
            stdout.writeln('[<-] CHAT $name: ${entry['msg']}');
          }
        }
      }
    } catch (_) {}
  };
  client.onClose = () {
    stdout.writeln('[ws] closed by server');
    if (!done.isCompleted) done.complete();
  };
  final ping = Timer.periodic(const Duration(seconds: 20), (_) => client.sendText(jsonEncode({'ver': '2', 'cmd': 0})));
  await Future.any([done.future, Future<void>.delayed(Duration(seconds: observeSeconds))]);
  ping.cancel();
  await client.close();
  stdout.writeln('[ws] sawChat=$sawChat');
}

void requestRecent(_ChzzkChatSocket client, String cid, String sid) {
  if (sid.isEmpty) return;
  client.sendText(
    jsonEncode({
      'ver': '2',
      'cmd': 5101,
      'cid': cid,
      'sid': sid,
      'tid': 2,
      'bdy': {'recentMessageCount': 50},
    }),
  );
  stdout.writeln('[->] cmd5101 recent-message request sent');
}

/// Minimal RFC6455 client over RawSecureSocket with ALPN http/1.1, for hosts
/// that drop dart's default no-ALPN TLS (e.g. Naver chat edge).
class _ChzzkChatSocket {
  _ChzzkChatSocket._(this._socket, this.negotiatedProtocol);

  static Future<_ChzzkChatSocket> connect(String host, {String path = '/chat'}) async {
    final address = (await InternetAddress.lookup(host)).where((a) => a.type == InternetAddressType.IPv4).first;
    final socket = await RawSecureSocket.connect(
      address,
      443,
      supportedProtocols: ['http/1.1'],
      timeout: const Duration(seconds: 12),
    );
    final key = base64.encode(List<int>.generate(16, (_) => Random.secure().nextInt(256)));
    final request =
        'GET $path HTTP/1.1\r\n'
        'Host: $host\r\n'
        'Upgrade: websocket\r\n'
        'Connection: Upgrade\r\n'
        'Sec-WebSocket-Key: $key\r\n'
        'Sec-WebSocket-Version: 13\r\n'
        'Origin: $webOrigin\r\n'
        'User-Agent: $userAgent\r\n'
        '\r\n';
    socket.write(utf8.encode(request));

    final completer = Completer<String>();
    final buffer = BytesBuilder();
    late final StreamSubscription<RawSocketEvent> subscription;
    subscription = socket.listen((event) {
      if (completer.isCompleted) return;
      if (event == RawSocketEvent.read) {
        buffer.add(socket.read()!);
        final bytes = buffer.toBytes();
        final head = utf8.decode(bytes, allowMalformed: true);
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

    final client = _ChzzkChatSocket._(socket, socket.selectedProtocol ?? '');
    client._handshakeRemainder = buffer.toBytes().sublist(utf8.encode(response).length);
    client._listen();
    return client;
  }

  final RawSecureSocket _socket;
  final String negotiatedProtocol;
  List<int> _handshakeRemainder = const [];
  final BytesBuilder _buffer = BytesBuilder();

  Function(String text)? onText;
  Function()? onClose;

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
          onClose?.call();
        }
      },
      onError: (Object error) {
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
          onText?.call(utf8.decode(payload, allowMalformed: true));
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
