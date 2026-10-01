// Opt-in standalone probe (dart:io only) for the NetEase CC live comment
// WebSocket protocol (wss://weblink.cc.163.com/). Verifies the register/join
// handshake and captures real chat frames for the danmaku adapter.
// Run: dart run tool/probes/cc_chat_probe.dart [ccid] [seconds]
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const userAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

// ── minimal msgpack (subset used by the CC weblink protocol) ──────────────

Uint8List mpEncodeStr(String s) {
  final bytes = utf8.encode(s);
  final out = BytesBuilder();
  if (bytes.length < 32) {
    out.addByte(0xa0 | bytes.length);
  } else if (bytes.length < 256) {
    out.addByte(0xd9);
    out.addByte(bytes.length);
  } else {
    out.addByte(0xda);
    out.addByte((bytes.length >> 8) & 0xff);
    out.addByte(bytes.length & 0xff);
  }
  out.add(bytes);
  return out.toBytes();
}

Uint8List mpEncodeInt(int v) {
  final out = BytesBuilder();
  if (v >= 0 && v <= 127) {
    out.addByte(v);
  } else if (v > 0 && v <= 0xff) {
    out.addByte(0xcc);
    out.addByte(v);
  } else if (v > 0 && v <= 0xffff) {
    out.addByte(0xcd);
    out.addByte((v >> 8) & 0xff);
    out.addByte(v & 0xff);
  } else {
    // The reference client encodes larger ids as float64; replicate that.
    out.addByte(0xcb);
    final f = ByteData(8)..setFloat64(0, v.toDouble(), Endian.big);
    out.add(f.buffer.asUint8List());
  }
  return out.toBytes();
}

Uint8List mpEncodeMap(Map<String, Object> map) {
  final out = BytesBuilder();
  if (map.length < 16) {
    out.addByte(0x80 | map.length);
  } else {
    out.addByte(0xde);
    out.addByte((map.length >> 8) & 0xff);
    out.addByte(map.length & 0xff);
  }
  map.forEach((key, value) {
    out.add(mpEncodeStr(key));
    if (value is int) {
      out.add(mpEncodeInt(value));
    } else if (value is String) {
      out.add(mpEncodeStr(value));
    } else if (value is Map<String, Object>) {
      out.add(mpEncodeMap(value));
    } else {
      throw StateError('unsupported value type ${value.runtimeType}');
    }
  });
  return out.toBytes();
}

class MpReader {
  MpReader(this.bytes);
  final Uint8List bytes;
  int offset = 0;

  int _u8() => bytes[offset++];
  int _u16() {
    final v = (bytes[offset] << 8) | bytes[offset + 1];
    offset += 2;
    return v;
  }

  int _u32() {
    var v = 0;
    for (var i = 0; i < 4; i++) {
      v = (v << 8) | bytes[offset + i];
    }
    offset += 4;
    return v;
  }

  Object? read() {
    final marker = _u8();
    if (marker <= 0x7f) return marker;
    if (marker >= 0x80 && marker <= 0x8f) return _map(marker & 0x0f);
    if (marker >= 0x90 && marker <= 0x9f) return _list(marker & 0x0f);
    if (marker >= 0xa0 && marker <= 0xbf) return _str(marker & 0x1f);
    switch (marker) {
      case 0xc0:
        return null;
      case 0xc2:
        return false;
      case 0xc3:
        return true;
      case 0xca:
        final v = ByteData.sublistView(bytes, offset, offset + 4).getFloat32(0, Endian.big);
        offset += 4;
        return v;
      case 0xcb:
        final v = ByteData.sublistView(bytes, offset, offset + 8).getFloat64(0, Endian.big);
        offset += 8;
        return v;
      case 0xcc:
        return _u8();
      case 0xcd:
        return _u16();
      case 0xce:
        return _u32();
      case 0xcf:
        var v = 0;
        for (var i = 0; i < 8; i++) {
          v = (v << 8) | _u8();
        }
        return v;
      case 0xd9:
        return _str(_u8());
      case 0xda:
        return _str(_u16());
      case 0xdb:
        return _str(_u32());
      case 0xdc:
        return _list(_u16());
      case 0xdd:
        return _list(_u32());
      case 0xde:
        return _map(_u16());
      case 0xdf:
        return _map(_u32());
      default:
        throw StateError('msgpack marker 0x${marker.toRadixString(16)} unsupported');
    }
  }

  String _str(int len) {
    final s = utf8.decode(bytes.sublist(offset, offset + len), allowMalformed: true);
    offset += len;
    return s;
  }

  List<Object?> _list(int len) => List.generate(len, (_) => read());
  Map<Object?, Object?> _map(int len) {
    final m = <Object?, Object?>{};
    for (var i = 0; i < len; i++) {
      final k = read();
      m[k] = read();
    }
    return m;
  }
}

// ── CC weblink frames ─────────────────────────────────────────────────────

Uint8List frameHeader(int sid, int cid, int flag) {
  final b = ByteData(8)
    ..setUint16(0, sid, Endian.little)
    ..setUint16(2, cid, Endian.little)
    ..setUint32(4, flag, Endian.little);
  return b.buffer.asUint8List();
}

Uint8List registerPacket() {
  final token = 'probe-${DateTime.now().millisecondsSinceEpoch}@web.cc.163.com';
  final body = mpEncodeMap({
    'web-cc': DateTime.now().millisecondsSinceEpoch,
    'macAdd': token,
    'device_token': token,
    'page_uuid': 'probe-${DateTime.now().millisecondsSinceEpoch}',
    'update_req_info': {'22': 640, '23': 360, '24': 'web', '25': 'Linux', '29': '163_cc', '30': '', '31': userAgent},
    'system': 'win',
    'memory': 1,
    'version': 1,
    'webccType': 4253,
  });
  return Uint8List.fromList([...frameHeader(6144, 2, 0), ...body]);
}

Uint8List joinPacket(Map<String, Object> info, {String variant = 'ref'}) {
  // variant=ref: 参考客户端原样(fixint / 0xcd / 0xcb float64);
  // variant=str: 值编码为字符串; variant=u32: 标准 uint32。
  final body = BytesBuilder();
  final entries = <String, Object>{
    'cid': info['channel_id']!,
    'gametype': info['gametype']!,
    'roomId': info['room_id']!,
  };
  body.addByte(0x80 | entries.length);
  entries.forEach((key, value) {
    body.add(mpEncodeStr(key));
    if (variant == 'str') {
      body.add(mpEncodeStr('$value'));
    } else if (variant == 'u32') {
      body.addByte(0xce);
      final b = ByteData(4)..setUint32(0, (value as int), Endian.big);
      body.add(b.buffer.asUint8List());
    } else {
      body.add(mpEncodeInt(value as int));
    }
  });
  return Uint8List.fromList([...frameHeader(512, 1, 0), ...body.toBytes()]);
}

Uint8List beatPacket() => Uint8List.fromList([...frameHeader(6144, 5, 0), ...mpEncodeMap({})]);

Object? decodeBody(Uint8List body) {
  var payload = body;
  if (payload.isNotEmpty && payload[0] == 0x78) {
    payload = Uint8List.fromList(ZLibCodec().decoder.convert(payload));
  }
  return MpReader(payload).read();
}

Future<Map<String, Object>> fetchAnchorInfo(String ccid) async {
  final client = HttpClient()..userAgent = userAgent;
  final req = await client.getUrl(Uri.parse('https://api.cc.163.com/v1/activitylives/anchor/lives?anchor_ccid=$ccid'));
  final resp = await req.close().timeout(const Duration(seconds: 10));
  final decoded = jsonDecode(await resp.transform(utf8.decoder).join()) as Map;
  final data = (decoded['data'] as Map)[ccid];
  if (data is! Map) throw StateError('anchor offline or schema changed');
  return Map<String, Object>.from(data);
}

void main(List<String> args) async {
  final ccid = args.isNotEmpty ? args.first : '586568';
  final observeSeconds = args.length > 1 ? int.parse(args[1]) : 22;
  final info = await fetchAnchorInfo(ccid);
  stdout.writeln('[info] $info');

  final ws = await WebSocket.connect('wss://weblink.cc.163.com/').timeout(const Duration(seconds: 10));
  stdout.writeln('[ws] connected');
  ws.add(registerPacket());
  await Future<void>.delayed(const Duration(seconds: 2));
  final variant = args.length > 2 ? args[2] : 'ref';
  ws.add(joinPacket(info, variant: variant));
  stdout.writeln('[->] register sent, join($variant) sent after 2s');

  var chatCount = 0;
  var enterCount = 0;
  late StreamSubscription sub;
  sub = ws.listen(
    (data) {
      final bytes = data is Uint8List ? data : Uint8List.fromList((data as List<int>).cast<int>());
      if (bytes.length < 8) return;
      final b = ByteData.sublistView(bytes);
      final sid = b.getUint16(0, Endian.little);
      final cid = b.getUint16(2, Endian.little);
      final flag = b.getUint32(4, Endian.little);
      Object? body;
      try {
        var offset = 8;
        if (flag > 0) offset += 4;
        var payload = Uint8List.sublistView(bytes, offset);
        if (payload.isNotEmpty && payload[0] == 0x78) {
          payload = Uint8List.fromList(ZLibCodec().decoder.convert(payload));
        }
        body = MpReader(payload).read();
      } catch (error) {
        stdout.writeln('[<-] sid=$sid cid=$cid flag=$flag len=${bytes.length} decode-error $error');
        return;
      }
      final summary = jsonEncode(body).length > 300 ? '${jsonEncode(body).substring(0, 300)}…' : jsonEncode(body);
      if (sid == 515 && cid == 32785) chatCount++;
      if (sid == 512 && cid == 32784) enterCount++;
      stdout.writeln('[<-] sid=$sid cid=$cid len=${bytes.length} $summary');
    },
    onDone: () => stdout.writeln('[ws] closed'),
    onError: (Object e) => stdout.writeln('[ws] err $e'),
  );

  final beat = Timer.periodic(const Duration(seconds: 15), (_) => ws.add(beatPacket()));
  await Future<void>.delayed(Duration(seconds: observeSeconds));
  beat.cancel();
  await sub.cancel();
  await ws.close().timeout(const Duration(seconds: 2), onTimeout: () {});
  stdout.writeln('[ws] chatFrames=$chatCount enterFrames=$enterCount');
}
