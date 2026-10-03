// Opt-in standalone probe for the AcFun comment link protocol: visitor login
// -> startPlay credentials -> wss://link.xiatou.com/ register/enterRoom with
// raw frame dumps. Run: dart run tool/probes/acfun_chat_probe.dart [authorId]
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart' as $fix;
import 'package:pointycastle/export.dart';
import 'package:pure_live/shared/platforms/proto/acfun.pb.dart' as pb;

const userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/140.0.0.0 Safari/537.36';

Future<Map<String, dynamic>> _postForm(String url, Map<String, String> form, {Map<String, String>? headers}) async {
  final client = HttpClient()..userAgent = userAgent;
  final request = await client.postUrl(Uri.parse(url));
  request.headers.set('Content-Type', 'application/x-www-form-urlencoded');
  headers?.forEach(request.headers.set);
  request.add(utf8.encode(form.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')));
  final response = await request.close().timeout(const Duration(seconds: 12));
  final body = await response.transform(utf8.decoder).join();
  if (response.statusCode != 200) throw StateError('$url -> ${response.statusCode}');
  return Map<String, dynamic>.from(jsonDecode(body) as Map);
}

Future<Map<String, String>> _credentials(String authorId) async {
  final login = await _postForm(
    'https://id.app.acfun.cn/rest/app/visitor/login',
    {'sid': 'acfun.api.visitor'},
    headers: {'Cookie': '_did=web_probe'},
  );
  final ssecurity = login['acSecurity']?.toString() ?? '';
  final userId = login['userId']?.toString() ?? '';
  final token = login['acfun.api.visitor_st']?.toString() ?? '';
  stdout.writeln('[login] uid=$userId tokenLen=${token.length} ssec=${ssecurity.length}');
  final start = await _postForm(
    'https://api.kuaishouzt.com/rest/zt/live/web/startPlay'
    '?subBiz=mainApp&kpn=ACFUN_APP&kpf=PC_WEB&userId=$userId&did=web_probe&acfun.api.visitor_st=$token',
    {'authorId': authorId, 'pullStreamType': 'FLV'},
    headers: {'Referer': 'https://live.acfun.cn/'},
  );
  final result = start['result'];
  stdout.writeln('[startPlay] result=$result');
  final data = start['data'];
  if (result != 1 || data is! Map) throw StateError('startPlay failed');
  final tickets = data['availableTickets'];
  return {
    'ticket': tickets is List && tickets.isNotEmpty ? tickets.first.toString() : '',
    'enterRoomAttach': data['enterRoomAttach']?.toString() ?? '',
    'liveId': data['liveId']?.toString() ?? '',
    'ssecurity': ssecurity,
    'token': token,
    'uid': userId,
  };
}

Uint8List aes(Uint8List input, Uint8List key, {required bool encrypt}) {
  if (encrypt) {
    final iv = Uint8List(16)..fillRange(0, 16, 0x31);
    final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
      ..init(true, PaddedBlockCipherParameters(ParametersWithIV(KeyParameter(key), iv), null));
    final out = BytesBuilder()
      ..add(iv)
      ..add(cipher.process(input));
    return out.toBytes();
  }
  final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
    ..init(
      false,
      PaddedBlockCipherParameters(ParametersWithIV(KeyParameter(key), Uint8List.sublistView(input, 0, 16)), null),
    );
  return Uint8List.fromList(cipher.process(Uint8List.sublistView(input, 16)));
}

Uint8List buildPacket(pb.PacketHeader header, List<int> plain, Uint8List key) {
  final encrypted = plain.isEmpty ? Uint8List(0) : aes(Uint8List.fromList(plain), key, encrypt: true);
  header.decodedPayloadLen = plain.length;
  final head = header.writeToBuffer();
  final prefix = ByteData(12)
    ..setUint16(0, 0xABCD, Endian.big)
    ..setUint16(2, 1, Endian.big)
    ..setUint32(4, head.length, Endian.big)
    ..setUint32(8, encrypted.length, Endian.big);
  final out = BytesBuilder()
    ..add(prefix.buffer.asUint8List())
    ..add(head)
    ..add(encrypted);
  return out.toBytes();
}

void main(List<String> args) async {
  final authorId = args.isNotEmpty ? args.first : '1345673';
  final creds = await _credentials(authorId);
  stdout.writeln(
    '[creds] liveId=${creds['liveId']} ticketLen=${creds['ticket']!.length} attachLen=${creds['enterRoomAttach']!.length}',
  );

  final ssec = Uint8List.fromList(base64.decode(creds['ssecurity']!));
  final ws = await WebSocket.connect('wss://link.xiatou.com/').timeout(const Duration(seconds: 10));
  stdout.writeln('[ws] connected');

  var seqId = 1;
  final register = pb.RegisterRequest()
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
      ..kpn = 'ACFUN_APP'
      ..kpf = 'PC_WEB'
      ..uid = $fix.Int64.parseInt(creds['uid']!)
      ..did = 'web_probe');
  final upstream = pb.UpstreamPayload()
    ..command = 'Basic.Register'
    ..seqId = $fix.Int64(seqId)
    ..retryCount = 1
    ..payloadData = register.writeToBuffer()
    ..subBiz = 'mainApp';
  final header = pb.PacketHeader()
    ..appId = 13
    ..uid = $fix.Int64.parseInt(creds['uid']!)
    ..decodedPayloadLen = upstream.writeToBuffer().length
    ..encryptionMode = pb.PacketHeader_EncryptionMode.kEncryptionServiceToken
    ..seqId = $fix.Int64(seqId)
    ..kpn = 'ACFUN_APP'
    ..tokenInfo = (pb.TokenInfo()
      ..tokenType = pb.TokenInfo_TokenType.kServiceToken
      ..token = utf8.encode(creds['token']!));
  ws.add(buildPacket(header, upstream.writeToBuffer(), ssec));
  stdout.writeln('[->] register sent (${upstream.writeToBuffer().length}B payload)');

  Uint8List? sessionKey;
  late StreamSubscription sub;
  sub = ws.listen(
    (data) {
      final bytes = data is Uint8List ? data : Uint8List.fromList((data as List<int>).cast<int>());
      if (bytes.length < 12) {
        stdout.writeln('[<-] tiny frame len=${bytes.length}');
        return;
      }
      final view = ByteData.sublistView(bytes);
      final magic = view.getUint16(0, Endian.big);
      final headLen = view.getUint32(4, Endian.big);
      final bodyLen = view.getUint32(8, Endian.big);
      if (magic != 0xABCD) {
        stdout.writeln(
          '[<-] bad magic 0x${magic.toRadixString(16)} len=${bytes.length} head=${utf8.decode(bytes.sublist(0, bytes.length.clamp(0, 80)), allowMalformed: true)}',
        );
        return;
      }
      final header = pb.PacketHeader.fromBuffer(bytes.sublist(12, 12 + headLen));
      final body = Uint8List.sublistView(bytes, 12 + headLen, 12 + headLen + bodyLen);
      final key = header.encryptionMode == pb.PacketHeader_EncryptionMode.kEncryptionServiceToken ? ssec : sessionKey;
      final text = header.encryptionMode == pb.PacketHeader_EncryptionMode.kEncryptionNone
          ? Uint8List.fromList(body)
          : (key == null ? null : aes(Uint8List.fromList(body), key, encrypt: false));
      if (text == null) {
        stdout.writeln('[<-] cmd=${header.encryptionMode} no key yet');
        return;
      }
      final downstream = pb.DownstreamPayload.fromBuffer(text);
      stdout.writeln('[<-] command=${downstream.command} error=${downstream.errorCode} msg=${downstream.errorMsg}');
      if (downstream.command == 'Basic.Register') {
        final response = pb.RegisterResponse.fromBuffer(downstream.payloadData);
        sessionKey = Uint8List.fromList(response.sessKey);
        stdout.writeln('[<-] registered instanceId=${response.instanceId} sessKeyLen=${response.sessKey.length}');
        seqId += 1;
        final enterPayload = pb.ZtLiveCsEnterRoom()
          ..isAuthor = false
          ..reconnectCount = 0
          ..enterRoomAttach = creds['enterRoomAttach']!
          ..clientLiveSdkVersion = 'kwai-acfun-live-link';
        final cmd = pb.CsCmd()
          ..cmdType = 'ZtLiveCsEnterRoom'
          ..ticket = creds['ticket']!
          ..payload = enterPayload.writeToBuffer()
          ..liveId = creds['liveId']!;
        final up = pb.UpstreamPayload()
          ..command = 'Global.ZtLiveInteractive.CsCmd'
          ..seqId = $fix.Int64(seqId)
          ..retryCount = 1
          ..payloadData = cmd.writeToBuffer()
          ..subBiz = 'mainApp';
        final h2 = pb.PacketHeader()
          ..appId = 13
          ..uid = $fix.Int64.parseInt(creds['uid']!)
          ..decodedPayloadLen = up.writeToBuffer().length
          ..encryptionMode = pb.PacketHeader_EncryptionMode.kEncryptionSessionKey
          ..seqId = $fix.Int64(seqId)
          ..instanceId = response.instanceId
          ..kpn = 'ACFUN_APP';
        ws.add(buildPacket(h2, up.writeToBuffer(), sessionKey!));
        stdout.writeln('[->] enterRoom sent');
      } else if (downstream.command == 'Push.ZtLiveInteractive.Message') {
        final message = pb.ZtLiveScMessage.fromBuffer(downstream.payloadData);
        var payload = message.payload;
        if (message.compressionType == 2) payload = Uint8List.fromList(gzip.decode(message.payload));
        stdout.writeln('[<-] push type=${message.messageType} len=${payload.length}');
        if (message.messageType == 'ZtLiveScStateSignal') {
          final state = pb.ZtLiveScStateSignal.fromBuffer(payload);
          for (final item in state.item) {
            stdout.writeln('[<-] state=${item.signalType}');
            if (item.signalType == 'CommonStateSignalRecentComment' && item.payload.isNotEmpty) {
              final rc = pb.CommonStateSignalRecentComment.fromBuffer(item.payload.first);
              if (rc.hasComment()) {
                stdout.writeln('[<-] RECENT ${rc.comment.userInfo.nickname}: ${rc.comment.content}');
              }
            }
          }
        }
        if (message.messageType == 'ZtLiveScActionSignal') {
          final signal = pb.ZtLiveScActionSignal.fromBuffer(payload);
          for (final item in signal.item) {
            stdout.writeln('[<-] signal=${item.signalType} payloads=${item.payload.length}');
            if (item.signalType == 'CommonActionSignalComment' && item.payload.isNotEmpty) {
              final comment = pb.CommonActionSignalComment.fromBuffer(item.payload.first);
              stdout.writeln('[<-] CHAT ${comment.userInfo.nickname}: ${comment.content}');
            }
          }
        }
      }
    },
    onDone: () => stdout.writeln('[ws] closed'),
    onError: (Object e) => stdout.writeln('[ws] err $e'),
  );

  await Future<void>.delayed(Duration(seconds: int.parse(args.length > 1 ? args[1] : '30')));
  await sub.cancel();
  await ws.close().timeout(const Duration(seconds: 2), onTimeout: () {});
}
