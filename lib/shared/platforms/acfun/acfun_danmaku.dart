import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart' as $fix;
import 'package:pointycastle/export.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/network/web_socket_util.dart';

import 'proto/acfun.pb.dart' as pb;

import 'package:pure_live/shared/platforms/live_danmaku.dart';

/// AcFun live comment transport over the Kuaishou link SDK, verified against
/// the public endpoints (2026-10): credentials come from the startPlay
/// response (availableTickets/enterRoomAttach/liveId) plus the anonymous
/// visitor session; packets are `magic(0xABCD) ver headLen bodyLen` framing a
/// protobuf PacketHeader and an AES-CBC(+IV) encrypted UpstreamPayload.
/// Comments arrive as ZtLiveScActionSignal items pushed over the session.
class AcFunDanmakuArgs {
  AcFunDanmakuArgs({
    required this.ticket,
    required this.enterRoomAttach,
    required this.liveId,
    required this.uid,
    required this.ssecurity,
    required this.token,
    required this.did,
    required this.kpf,
  });

  AcFunDanmakuArgs.fromJson(Map<String, dynamic> json)
    : ticket = json['ticket'] ?? '',
      enterRoomAttach = json['enterRoomAttach'] ?? '',
      liveId = json['liveId'] ?? '',
      uid = json['uid'] ?? '',
      ssecurity = json['ssecurity'] ?? '',
      token = json['token'] ?? '',
      did = json['did'] ?? '',
      kpf = json['kpf'] ?? '';

  final String ticket;
  final String enterRoomAttach;
  final String liveId;
  final String uid;
  final String ssecurity;
  final String token;
  final String did;
  final String kpf;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'ticket': ticket,
    'enterRoomAttach': enterRoomAttach,
    'liveId': liveId,
    'uid': uid,
    'ssecurity': ssecurity,
    'token': token,
    'did': did,
    'kpf': kpf,
  };
}

class AcFunDanmaku implements LiveDanmaku {
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

  // The util drives the interval; the actual ZtLiveCsHeartbeat frame is sent
  // from onHeartBeat once the room session is established.
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
  AcFunDanmakuArgs? _args;
  Uint8List? _ssecurity;
  Uint8List? _sessionKey;
  int _seqId = 0;
  int _instanceId = 0;
  bool _entered = false;

  static const _wsUrl = 'wss://link.xiatou.com/';
  static const _kpn = 'ACFUN_APP';
  static const _clientSdkVersion = 'kwai-acfun-live-link';

  @override
  Future<void> start(dynamic args) async {
    if (args is! AcFunDanmakuArgs || args.ticket.isEmpty || args.liveId.isEmpty || args.ssecurity.isEmpty) {
      onClose?.call('AcFun 弹幕参数缺失');
      return;
    }
    _args = args;
    _ssecurity = base64.decode(args.ssecurity);
    _socket = WebScoketUtils(
      url: _wsUrl,
      heartBeatTime: heartbeatTime,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/140.0.0.0 Safari/537.36',
      },
      onMessage: (data) {
        if (data is Uint8List) {
          _handlePacket(data);
        } else if (data is List<int>) {
          _handlePacket(Uint8List.fromList(data));
        }
      },
      onReady: () {
        markConnected();
        _resetSession();
        _sendRegister();
        // The transport is up; session readiness (RegisterResponse) is
        // reported by the server-side flow below.
        onReady?.call();
      },
      onHeartBeat: () => _sendHeartbeat(),
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

  void _resetSession() {
    _seqId = 0;
    _instanceId = 0;
    _sessionKey = null;
    _entered = false;
  }

  // ── outbound ────────────────────────────────────────────────────────────

  void _sendRegister() {
    final args = _args;
    if (args == null) return;
    _seqId = 1;
    final request = pb.RegisterRequest()
      ..appActiveStatus = pb.RegisterRequest_ActiveStatus.kAppInForeground
      ..presenceStatus = pb.RegisterRequest_PresenceStatus.kPresenceOnline
      ..appInfo = (pb.AppInfo()
        ..appName = 'link-sdk'
        ..sdkVersion = '1.2.1')
      ..deviceInfo = (pb.DeviceInfo()
        ..deviceModel = 'h5'
        ..platformType = pb.DeviceInfo_PlatformType.valueOf(6)!)
      ..instanceId = $fix.Int64.ZERO
      ..ztCommonInfo = (pb.ZtCommonInfo()
        ..kpn = _kpn
        ..kpf = args.kpf
        ..uid = $fix.Int64.parseInt(args.uid)
        ..did = args.did);
    final header =
        _header(
            seqId: _seqId,
            encryptionMode: pb.PacketHeader_EncryptionMode.kEncryptionServiceToken,
            payloadLen: request.writeToBuffer().length,
          )
          ..tokenInfo = (pb.TokenInfo()
            ..tokenType = pb.TokenInfo_TokenType.kServiceToken
            ..token = utf8.encode(args.token));
    _emit(header, request.writeToBuffer(), _ssecurity!);
  }

  void _sendEnterRoom() {
    final args = _args;
    if (args == null) return;
    _seqId += 1;
    final payload = pb.ZtLiveCsEnterRoom()
      ..isAuthor = false
      ..reconnectCount = 0
      ..enterRoomAttach = args.enterRoomAttach
      ..clientLiveSdkVersion = _clientSdkVersion;
    _sendCsCmd('ZtLiveCsEnterRoom', payload.writeToBuffer());
  }

  void _sendHeartbeat() {
    if (_socket == null || !_entered) return;
    _seqId += 1;
    final payload = pb.ZtLiveCsHeartbeat()..clientTimestampMs = $fix.Int64(DateTime.now().millisecondsSinceEpoch);
    _sendCsCmd('ZtLiveCsHeartbeat', payload.writeToBuffer());
  }

  void _sendCsCmd(String type, List<int> payloadBytes) {
    final args = _args;
    if (args == null || _sessionKey == null) return;
    final cmd = pb.CsCmd()
      ..cmdType = type
      ..ticket = args.ticket
      ..payload = payloadBytes
      ..liveId = args.liveId;
    final upstream = pb.UpstreamPayload()
      ..command = 'Global.ZtLiveInteractive.CsCmd'
      ..seqId = $fix.Int64(_seqId)
      ..retryCount = 1
      ..payloadData = cmd.writeToBuffer()
      ..subBiz = 'mainApp';
    final header = _header(
      seqId: _seqId,
      encryptionMode: pb.PacketHeader_EncryptionMode.kEncryptionSessionKey,
      payloadLen: upstream.writeToBuffer().length,
    )..instanceId = $fix.Int64(_instanceId);
    _emit(header, upstream.writeToBuffer(), _sessionKey!);
  }

  pb.PacketHeader _header({
    required int seqId,
    required pb.PacketHeader_EncryptionMode encryptionMode,
    required int payloadLen,
  }) {
    final args = _args;
    return pb.PacketHeader()
      ..appId = 13
      ..uid = $fix.Int64.parseInt(args?.uid ?? '0')
      ..flags = 0
      ..decodedPayloadLen = payloadLen
      ..encryptionMode = encryptionMode
      ..seqId = $fix.Int64(seqId)
      ..kpn = _kpn;
  }

  void _emit(pb.PacketHeader header, List<int> plaintext, Uint8List key) {
    final socket = _socket;
    if (socket == null) return;
    final encrypted = aesCbcPkcs7(Uint8List.fromList(plaintext), key, forEncryption: true);
    socket.sendMessage(buildPacket(header, encrypted, plainLen: plaintext.length));
  }

  // ── inbound ─────────────────────────────────────────────────────────────

  void _handlePacket(Uint8List data) {
    try {
      final parsed = parsePacket(data);
      if (parsed == null) return;
      final header = parsed.header;
      final key = header.encryptionMode == pb.PacketHeader_EncryptionMode.kEncryptionServiceToken
          ? _ssecurity
          : _sessionKey;
      if (header.encryptionMode != pb.PacketHeader_EncryptionMode.kEncryptionNone && key == null) {
        return;
      }
      final body = header.encryptionMode == pb.PacketHeader_EncryptionMode.kEncryptionNone
          ? parsed.body
          : aesCbcPkcs7(parsed.body, key!, forEncryption: false);
      final downstream = pb.DownstreamPayload.fromBuffer(body);
      switch (downstream.command) {
        case 'Basic.Register':
          final response = pb.RegisterResponse.fromBuffer(downstream.payloadData);
          _sessionKey = Uint8List.fromList(response.sessKey);
          _instanceId = response.instanceId.toInt();
          _sendEnterRoom();
          _entered = true;
        case 'Push.ZtLiveInteractive.Message':
          _handlePush(downstream.payloadData);
        default:
          break;
      }
    } catch (error) {
      CoreLog.error(error);
    }
  }

  void _handlePush(List<int> payloadBytes) {
    final message = pb.ZtLiveScMessage.fromBuffer(payloadBytes);
    if (message.messageType == 'ZtLiveScTicketInvalid') {
      onClose?.call('AcFun 弹幕票据失效');
      return;
    }
    if (message.messageType != 'ZtLiveScActionSignal') return;
    var payloadBytes2 = message.payload;
    if (message.compressionType == 2) {
      payloadBytes2 = Uint8List.fromList(gzip.decode(message.payload));
    }
    final signal = pb.ZtLiveScActionSignal.fromBuffer(payloadBytes2);
    for (final item in signal.item) {
      if (item.signalType != 'CommonActionSignalComment') continue;
      for (final entry in item.payload) {
        try {
          final comment = pb.CommonActionSignalComment.fromBuffer(entry);
          final text = comment.content.trim();
          if (text.isEmpty) continue;
          onMessage?.call(
            LiveMessage(
              type: LiveMessageType.chat,
              color: LiveMessageColor.white,
              message: text,
              userName: comment.userInfo.nickname,
            ),
          );
        } catch (error) {
          CoreLog.error(error);
        }
      }
    }
  }

  @override
  Future<void> stop() async {
    markDisconnected();
    onMessage = null;
    onReconnect = null;
    onClose = null;
    onReady = null;
    _args = null;
    _sessionKey = null;
    _entered = false;
    final socket = _socket;
    _socket = null;
    await socket?.close();
  }

  // ── pure helpers, also used by unit tests ───────────────────────────────

  /// Wraps a protobuf header and AES-CBC(+IV) encrypted payload into the
  /// `magic version headLen bodyLen` big-endian frame.
  static Uint8List buildPacket(pb.PacketHeader header, Uint8List encryptedBody, {required int plainLen}) {
    header.decodedPayloadLen = plainLen;
    final head = header.writeToBuffer();
    final prefix = ByteData(12)
      ..setUint16(0, 0xABCD, Endian.big)
      ..setUint16(2, 1, Endian.big)
      ..setUint32(4, head.length, Endian.big)
      ..setUint32(8, encryptedBody.length, Endian.big);
    final out = BytesBuilder();
    out.add(prefix.buffer.asUint8List());
    out.add(head);
    out.add(encryptedBody);
    return out.toBytes();
  }

  /// Splits one frame back into its header and encrypted body; null when the
  /// magic does not match or the lengths exceed the buffer.
  static ({pb.PacketHeader header, Uint8List body})? parsePacket(Uint8List data) {
    if (data.length < 12) return null;
    final view = ByteData.sublistView(data);
    if (view.getUint16(0, Endian.big) != 0xABCD) return null;
    final headLen = view.getUint32(4, Endian.big);
    final bodyLen = view.getUint32(8, Endian.big);
    if (12 + headLen + bodyLen > data.length) return null;
    final header = pb.PacketHeader.fromBuffer(data.sublist(12, 12 + headLen));
    return (header: header, body: Uint8List.fromList(data.sublist(12 + headLen, 12 + headLen + bodyLen)));
  }

  /// AES-256/128-CBC with PKCS7; the 16-byte random IV prefixes the output on
  /// encryption and is consumed from the input on decryption.
  static Uint8List aesCbcPkcs7(Uint8List input, Uint8List key, {required bool forEncryption}) {
    if (forEncryption) {
      final iv = Uint8List(16);
      final random = Random.secure();
      for (var i = 0; i < iv.length; i++) {
        iv[i] = random.nextInt(256);
      }
      final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
        ..init(
          true,
          PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, KeyParameter>(
            ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
            null,
          ),
        );
      final out = BytesBuilder();
      out.add(iv);
      out.add(cipher.process(input));
      return out.toBytes();
    }
    if (input.length < 32 || input.length % 16 != 0) {
      throw const FormatException('acfun packet body is not a valid aes-cbc block set');
    }
    final iv = Uint8List.sublistView(input, 0, 16);
    final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
      ..init(
        false,
        PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, KeyParameter>(
          ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
          null,
        ),
      );
    return Uint8List.fromList(cipher.process(Uint8List.sublistView(input, 16)));
  }

  /// Decodes one ZtLiveScActionSignal payload into chat messages.
  static List<LiveMessage> parseActionSignal(List<int> bytes) {
    final signal = pb.ZtLiveScActionSignal.fromBuffer(bytes);
    final messages = <LiveMessage>[];
    for (final item in signal.item) {
      if (item.signalType != 'CommonActionSignalComment') continue;
      for (final entry in item.payload) {
        final comment = pb.CommonActionSignalComment.fromBuffer(entry);
        final text = comment.content.trim();
        if (text.isEmpty) continue;
        messages.add(
          LiveMessage(
            type: LiveMessageType.chat,
            color: LiveMessageColor.white,
            message: text,
            userName: comment.userInfo.nickname,
          ),
        );
      }
    }
    return messages;
  }
}
