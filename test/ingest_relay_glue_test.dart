// zishu 播放链 × media_core_ingest 胶水验证:本地伪上游(HLS 根+分段)→
// LoopbackIngestRelay 改写→回环根地址可取→分段经中继代理回流。整链回环,
// 零外网。这就是播放链把 HLS 交给 ingest 管线的核心契约。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_ingest/media_core_ingest.dart';

const String _rootManifest = '''
#EXTM3U
#EXT-X-TARGETDURATION:6
#EXTINF:6.0,
media.95.mp4
#EXTINF:6.0,
media.96.mp4
#EXT-X-ENDLIST
''';

Future<HttpServer> _startUpstream() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final path = request.uri.path;
    if (path.endsWith('.m3u8')) {
      request.response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl');
      request.response.write(_rootManifest);
    } else if (path.endsWith('.mp4')) {
      request.response.headers.contentType = ContentType.binary;
      request.response.add([1, 2, 3, 4]);
    } else {
      request.response.statusCode = HttpStatus.notFound;
    }
    await request.response.close();
  });
  return server;
}

/// TwitCasting 形态的伪上游:清单响应下发会话 Cookie(Set-Cookie),
/// 分片请求不带该 Cookie 一律 401(上游 86dde8f16 台账的 curl 实测行为)。
Future<HttpServer> _startCookieUpstream() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final path = request.uri.path;
    if (path.endsWith('.m3u8')) {
      request.response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl');
      request.response.headers.set(
        HttpHeaders.setCookieHeader,
        'lvhls_ssid_test=session123; Path=/hls/; Max-Age=600; HttpOnly',
      );
      request.response.write(_rootManifest);
    } else if (path.endsWith('.mp4')) {
      final cookie = request.headers.value(HttpHeaders.cookieHeader) ?? '';
      if (!cookie.contains('lvhls_ssid_test=session123')) {
        request.response.statusCode = HttpStatus.unauthorized;
      } else {
        request.response.headers.contentType = ContentType.binary;
        request.response.add([1, 2, 3, 4]);
      }
    } else {
      request.response.statusCode = HttpStatus.notFound;
    }
    await request.response.close();
  });
  return server;
}

void main() {
  late HttpServer upstream;
  late Uri upstreamRoot;

  setUp(() async {
    upstream = await _startUpstream();
    upstreamRoot = Uri.parse('http://127.0.0.1:${upstream.port}');
  });

  tearDown(() async {
    await upstream.close(force: true);
  });

  test('根 manifest 改写为回环绝对地址,分段经中继代理回流', () async {
    final relay = await LoopbackIngestRelay.start(source: upstreamRoot.replace(path: '/hls/root.m3u8'));
    addTearDown(relay.close);

    // 播放器只见回环绝对地址。
    expect(relay.inputUri.host, '127.0.0.1');
    expect(relay.inputUri.path, contains('root.m3u8'));

    final client = HttpClient();
    try {
      // 1) 根 manifest:子行从裸名改写为回环地址。
      final rootResponse = await client.getUrl(relay.inputUri).then((r) => r.close());
      expect(rootResponse.statusCode, 200);
      final text = await rootResponse.transform(utf8.decoder).join();
      expect(text.contains('\nmedia.95.mp4'), isFalse);
      expect(RegExp(r'^http://127\.0\.0\.1:', multiLine: true).allMatches(text).length, greaterThanOrEqualTo(2));

      // 2) 分段:改写后的回环子地址经中继回流伪上游的分段体。
      final childMatch = RegExp(r'^http://127\.0\.0\.1:\S+', multiLine: true).firstMatch(text);
      final childUrl = childMatch!.group(0)!;
      final childResponse = await client.getUrl(Uri.parse(childUrl)).then((r) => r.close());
      expect(childResponse.statusCode, 200);
      final childBytes = await childResponse.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      expect(childBytes, [1, 2, 3, 4]);
      expect(relay.childCount, greaterThanOrEqualTo(2));
    } finally {
      client.close(force: true);
    }
  });

  test('close 后中继端口不再服务(生命周期回收)', () async {
    final relay = await LoopbackIngestRelay.start(source: upstreamRoot.replace(path: '/hls/root.m3u8'));
    final port = relay.inputUri.port;
    await relay.close();
    expect(relay.isClosed, isTrue);
    final client = HttpClient();
    try {
      await expectLater(
        client.getUrl(Uri.parse('http://127.0.0.1:$port/root.m3u8')).then((request) => request.close()),
        throwsA(anything),
      );
    } finally {
      client.close(force: true);
    }
  });

  test('sessionCookies: true —— 清单下发的会话 Cookie 续传给分片(TwitCasting 401 契约)', () async {
    final cookieUpstream = await _startCookieUpstream();
    addTearDown(() => cookieUpstream.close(force: true));
    final root = Uri.parse('http://127.0.0.1:${cookieUpstream.port}');

    // zishu 接入口径(2026-10-07 对齐上游 _createIngestRelay):sessionCookies
    // 必开,且不预载 rootManifest——预载会跳过中继自己的清单请求,Set-Cookie
    // 进不了 Cookie 罐。
    final relay = await LoopbackIngestRelay.start(source: root.replace(path: '/hls/root.m3u8'), sessionCookies: true);
    addTearDown(relay.close);

    final client = HttpClient();
    try {
      final manifest = await client.getUrl(relay.inputUri).then((request) => request.close());
      expect(manifest.statusCode, HttpStatus.ok);
      final body = await manifest.fold<String>('', (text, chunk) => text + String.fromCharCodes(chunk));
      // 改写后的清单给出回环绝对分片地址(与既有用例同口径解析)。
      final childMatch = RegExp(r'https?://127\.0\.0\.1:\d+/[^\s]+\.mp4').firstMatch(body);
      expect(childMatch, isNotNull, reason: '改写后的清单应携带回环分片地址');
      final segment = await client.getUrl(Uri.parse(childMatch!.group(0)!)).then((request) => request.close());
      expect(segment.statusCode, HttpStatus.ok, reason: '分片必须携带清单下发的会话 Cookie 回源');
      final bytes = await segment.fold<int>(0, (sum, chunk) => sum + chunk.length);
      expect(bytes, 4);
    } finally {
      client.close(force: true);
    }
  });

  test('classifyHlsManifest 判定口径与 zishu 接入一致(裸名/绝对路径需改写)', () {
    final bare = classifyHlsManifest(_rootManifest);
    expect(bare.requiresRewrite, isTrue);
    final absolute = classifyHlsManifest('#EXTM3U\n#EXTINF:6.0,\nhttps://cdn.example/a/media.mp4\n#EXT-X-ENDLIST\n');
    expect(absolute.requiresRewrite, isFalse);
  });
}
