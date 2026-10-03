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

  test('classifyHlsManifest 判定口径与 zishu 接入一致(裸名/绝对路径需改写)', () {
    final bare = classifyHlsManifest(_rootManifest);
    expect(bare.requiresRewrite, isTrue);
    final absolute = classifyHlsManifest('#EXTM3U\n#EXTINF:6.0,\nhttps://cdn.example/a/media.mp4\n#EXT-X-ENDLIST\n');
    expect(absolute.requiresRewrite, isFalse);
  });
}
