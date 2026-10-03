import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';

/// Bigo Live official-web chat, protocol verified against the public guest
/// flow (2026-10): `getWebSocketLink` issues an anonymous guest session, the
/// web socket frames are `<eid><json>` text, the server opens with an eid-256
/// challenge that must be answered with an MD5 signature plus guest login,
/// then the room is entered by studio roomId. Chat arrives as eid-2584 with a
/// base64 JSON payload (`n`/`nick` nickname, `m`/`msg`/`text` text).
class BigoDanmakuArgs {
  BigoDanmakuArgs({required this.siteId, this.roomId});

  BigoDanmakuArgs.fromJson(Map<String, dynamic> json) : siteId = json['siteId'] ?? '', roomId = json['roomId'] ?? '';

  final String siteId;

  /// Studio roomId from `getInternalStudioInfo` (distinct from the URL siteId).
  final String? roomId;

  Map<String, dynamic> toJson() => <String, dynamic>{'siteId': siteId, 'roomId': roomId};
}

class BigoDanmaku implements LiveDanmaku {
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
  int heartbeatTime = 10 * 1000;

  // The eid-791 ping frame is sent from onHeartBeat.
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
  _BigoGuest? _guest;
  String? _roomId;
  bool _challengeAnswered = false;
  bool _loggedIn = false;

  static const _wsLinkUrl = 'https://ta.bigo.tv/official_website/studio/getWebSocketLink';
  static const _wsUrl = 'wss://wss.bigolive.tv/live/official/web';
  static const _webOrigin = 'https://www.bigo.tv';
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  static const _eidChallenge = 256;
  static const _eidChallengeResp = 79108;
  static const _eidLoginReq = 512279;
  static const _eidLoginRes = 512535;
  static const _eidEnterReq = 1304;
  static const _eidEnterRes = 1560;
  static const _eidNormalText = 2584;
  static const _eidPing = 791;

  @override
  Future<void> start(dynamic args) async {
    if (args is! BigoDanmakuArgs || args.siteId.isEmpty) {
      onClose?.call('Bigo 弹幕参数缺失');
      return;
    }
    _roomId = (args.roomId != null && args.roomId!.isNotEmpty) ? args.roomId : args.siteId;
    try {
      _guest = await _fetchGuest();
    } catch (error) {
      onClose?.call('Bigo 游客会话获取失败');
      return;
    }
    _socket = WebScoketUtils(
      url: _wsUrl,
      heartBeatTime: heartbeatTime,
      headers: {'Origin': _webOrigin, 'Referer': '$_webOrigin/', 'User-Agent': _userAgent},
      onMessage: (data) {
        if (data is! String) return;
        _handleFrame(data);
      },
      onReady: () {
        markConnected();
        onReady?.call();
        _challengeAnswered = false;
        _loggedIn = false;
      },
      onHeartBeat: () => _sendEid(_eidPing, {
        'status': '0',
        'seqid': '${DateTime.now().millisecondsSinceEpoch}',
        'flag': '0',
        'roomId': _roomId ?? '0',
        'ownerStatus': '0',
        'micUid': '0',
      }),
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

  Future<_BigoGuest> _fetchGuest() async {
    final deviceId = 'web_${_randomMd5()}';
    final client = HttpClient()..userAgent = _userAgent;
    final request = await client.postUrl(Uri.parse(_wsLinkUrl));
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/x-www-form-urlencoded; charset=UTF-8');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.refererHeader, '$_webOrigin/');
    request.headers.set('origin', _webOrigin);
    request.add(utf8.encode('deviceId=${Uri.encodeQueryComponent(deviceId)}'));
    final response = await request.close().timeout(const Duration(seconds: 12));
    final body = jsonDecode(await response.transform(utf8.decoder).join());
    client.close(force: true);
    if (body is! Map) throw const FormatException('bigo getWebSocketLink envelope');
    final data = body['data'];
    if (data is! Map) throw const FormatException('bigo getWebSocketLink data');
    var token = data['uidToken']?.toString() ?? '';
    // The token is suffixed with a transport version marker that the socket
    // login body must not carry.
    final marker = token.indexOf('###');
    if (marker >= 0) token = token.substring(0, marker);
    if (token.isEmpty) throw const FormatException('bigo guest token missing');
    return _BigoGuest(
      uidToken: token,
      userId: data['userId']?.toString() ?? '0',
      deviceId: data['deviceId']?.toString() ?? deviceId,
    );
  }

  void _handleFrame(String text) {
    final split = text.indexOf('{');
    if (split <= 0) return;
    final eid = int.tryParse(text.substring(0, split).trim());
    Object? decoded;
    try {
      decoded = jsonDecode(text.substring(split));
    } catch (_) {
      return;
    }
    if (eid == null || decoded is! Map) return;
    switch (eid) {
      case _eidChallenge:
        final challenge = decoded['challenge']?.toString() ?? '';
        if (challenge.isEmpty) return;
        _sendEid(_eidChallengeResp, challengeBody(challenge));
        if (!_challengeAnswered) {
          _challengeAnswered = true;
          _sendLogin();
        }
      case _eidLoginRes:
        final res = decoded['res']?.toString() ?? '';
        if (res != '200') {
          onClose?.call('Bigo 登录被拒绝 res=$res');
          return;
        }
        if (!_loggedIn) {
          _loggedIn = true;
          _sendEnter();
        }
      case _eidEnterRes:
        final code = decoded['resCode']?.toString() ?? '';
        if (code != '200') {
          onClose?.call('Bigo 进房被拒绝 room=$_roomId resCode=$code');
          return;
        }
      case _eidNormalText:
        for (final message in parseNormalText(decoded)) {
          onMessage?.call(message);
        }
      default:
        break;
    }
  }

  void _sendLogin() {
    final guest = _guest;
    if (guest == null) return;
    _sendEid(_eidLoginReq, {
      'uid': guest.userId,
      'cookie': guest.uidToken,
      'secret': '0',
      'userName': '0',
      'deviceId': guest.deviceId,
      'userFlag': '0',
      'status': '0',
      'password': '0',
      'sdkVersion': '0',
      'displayType': '0',
      'pbVersion': '0',
      'lang': 'cn',
      'loginLevel': '0',
      'clientVersionCode': '0',
      'clientType': '7',
      'clientOsVer': '0',
      'netConf': {
        'clientIp': '0',
        'proxySwitch': '0',
        'proxyTimestamp': '0',
        'mcc': '0',
        'mnc': '0',
        'countryCode': 'CN',
      },
    });
  }

  void _sendEnter() {
    final guest = _guest;
    if (guest == null) return;
    _sendEid(_eidEnterReq, {
      'secretKey': '0',
      'seqId': '${DateTime.now().millisecondsSinceEpoch}',
      'roomId': _roomId ?? '0',
      'reserver': '1',
      'clientVersion': '0',
      'clientType': '7',
      'version': '15',
      'deviceid': guest.deviceId,
      'other': [],
    });
  }

  void _sendEid(int eid, Map<String, Object?> body) {
    _socket?.sendMessage('$eid${jsonEncode(body)}');
  }

  @override
  Future<void> stop() async {
    markDisconnected();
    onMessage = null;
    onReconnect = null;
    onClose = null;
    onReady = null;
    _guest = null;
    _challengeAnswered = false;
    _loggedIn = false;
    final socket = _socket;
    _socket = null;
    await socket?.close();
  }

  // ── pure helpers, also used by unit tests ───────────────────────────────

  /// eid-256 challenge answer: MD5 of `60#4#5#<ts>#1#1#1#1#<challenge tail>`,
  /// where the tail is the last 8 characters of the challenge.
  static Map<String, Object?> challengeBody(String challenge, {String? timestampSec}) {
    final tailStart = challenge.length >= 8 ? challenge.length - 8 : 0;
    final tail = challenge.substring(tailStart);
    final ts = timestampSec ?? '${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
    final material = '60#4#5#$ts#1#1#1#1#$tail';
    final sign = crypto.md5.convert(utf8.encode(material)).toString();
    return {
      'appId': '60',
      'osType': '4',
      'clientVersion': '5',
      'timeStamp': ts,
      'nonce': '1',
      'reservedForSecurity': '1',
      'appSign': '1',
      'redundancy': '1',
      'sign': sign,
    };
  }

  /// eid-2584 chat decode: base64 `payload.content` JSON, tag 1/2 = chat with
  /// `n`/`nick` and `m`/`msg`/`text`; tag 6 (gift) and others are ignored.
  static List<LiveMessage> parseNormalText(Map<Object?, Object?> frame) {
    final payload = frame['payload'];
    if (payload is! Map) return const [];
    final tag = int.tryParse(payload['tag']?.toString() ?? '') ?? 0;
    if (tag != 1 && tag != 2) return const [];
    final content = payload['content'];
    if (content is! String || content.isEmpty) return const [];
    Object? decodedPayload;
    try {
      decodedPayload = jsonDecode(utf8.decode(base64.decode(content), allowMalformed: true));
    } catch (_) {
      return const [];
    }
    if (decodedPayload is! Map) return const [];
    final text = (decodedPayload['m'] ?? decodedPayload['msg'] ?? decodedPayload['text'])?.toString() ?? '';
    if (text.trim().isEmpty) return const [];
    final fallbackUser = payload['uid']?.toString() ?? frame['from_uid']?.toString() ?? '';
    final name = (decodedPayload['n'] ?? decodedPayload['nick'])?.toString() ?? fallbackUser;
    return [LiveMessage(type: LiveMessageType.chat, color: LiveMessageColor.white, message: text, userName: name)];
  }
}

class _BigoGuest {
  const _BigoGuest({required this.uidToken, required this.userId, required this.deviceId});

  final String uidToken;
  final String userId;
  final String deviceId;
}

String _randomMd5() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return crypto.md5.convert(bytes).toString();
}
