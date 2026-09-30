// Pure Live parsing sidecar — the SAME lib/core sources the Flutter app uses,
// compiled by `dart compile exe` for the Node streaming server.
//
// Protocol: one JSON request per stdin line, one JSON response per stdout
// line: {"id":<req id>,"method":<name>,"params":{...}} ->
// {"id":<req id>,"ok":true,"result":...} | {"id":<req id>,"ok":false,
// "error":{"code":"...","message":"..."}}.
//
// Methods: health | resolve | qualities | playUrls
// (contracts stay in contracts/api.md; this process is a Dart-side
// implementation detail of the streaming server's ResolverBackend).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pure_live/core/common/convert_helper.dart';
import 'package:pure_live/core/site/bilibili/bilibili_site.dart';
import 'package:pure_live/core/site/douyin/douyin_site.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/common/models/live_room.dart';

final Map<String, LiveSite> _sites = {
  'bilibili': BiliBiliSite(),
  'douyin': DouyinSite(),
};

Map<String, dynamic> _roomToJson(LiveRoom room) {
  return {
    'platform': room.platform,
    'roomId': room.roomId,
    'title': room.title ?? '',
    'nick': room.nick ?? '',
    'avatar': room.avatar ?? '',
    'cover': room.cover ?? '',
    'watching': room.watching ?? '',
    'link': room.link ?? '',
    'status': room.status,
    'liveStatus': room.liveStatus?.name ?? 'unknown',
  };
}

Future<Object?> _dispatch(String method, Map<String, dynamic> params) async {
  if (method == 'health') {
    return {'ok': true, 'platforms': _sites.keys.toList(growable: false)};
  }

  final platform = asT<String?>(params['platform']) ?? '';
  final roomId = asT<String?>(params['roomId']) ?? '';
  final site = _sites[platform];
  if (site == null) {
    throw _RpcError('PLATFORM_UNSUPPORTED', 'platform "$platform" not built into this sidecar');
  }

  switch (method) {

    case 'resolve':
      if (roomId.isEmpty) throw _RpcError('BAD_REQUEST', 'roomId is required');
      final room = await site.getRoomDetail(platform: platform, roomId: roomId);
      return {'room': _roomToJson(room)};

    case 'qualities':
      if (roomId.isEmpty) throw _RpcError('BAD_REQUEST', 'roomId is required');
      final room = await site.getRoomDetail(platform: platform, roomId: roomId);
      final qualities = await site.getPlayQualites(detail: room);
      return {
        'qualities': [
          for (final q in qualities)
            {'selectionId': '${q.selectionId}', 'label': q.quality},
        ],
      };

    case 'playUrls':
      if (roomId.isEmpty) throw _RpcError('BAD_REQUEST', 'roomId is required');
      final room = await site.getRoomDetail(platform: platform, roomId: roomId);
      final qualities = await site.getPlayQualites(detail: room);
      final requested = asT<String?>(params['quality']);
      LivePlayQuality? chosen;
      if (requested != null && requested.isNotEmpty) {
        chosen = qualities.firstWhere(
          (q) => '${q.selectionId}' == requested || q.quality == requested,
          orElse: () => throw _RpcError('BAD_REQUEST', 'unknown quality "$requested"'),
        );
      }
      chosen ??= qualities.isEmpty ? null : qualities.first;
      if (chosen == null) {
        throw _RpcError('ROOM_CLOSED', 'room has no playable qualities (offline?)');
      }
      final urls = await site.getPlayUrls(detail: room, quality: chosen);
      return {
        'quality': chosen.quality,
        'qualityId': '${chosen.selectionId}',
        'urls': urls,
      };

    default:
      throw _RpcError('BAD_REQUEST', 'unknown method "$method"');
  }
}

class _RpcError implements Exception {
  _RpcError(this.code, this.message);
  final String code;
  final String message;
}

Future<void> runSidecar(List<String> args) async {
  // Optional sidecar-side proxy from environment (host decides whether to set
  // it); without it connections are direct.
  if (args.contains('--quiet')) {
    // reserved for future flags
  }

  stdout.writeln(jsonEncode({'ok': true, 'started': true, 'platforms': _sites.keys.toList(growable: false)}));

  final lineStream = stdin
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter());

  await for (final line in lineStream) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    Object? id;
    try {
      final request = jsonDecode(trimmed);
      if (request is! Map<String, dynamic>) throw const FormatException('request must be an object');
      id = request['id'];
      final method = request['method'];
      final params = request['params'];
      final result = await _dispatch(
        method is String ? method : '',
        params is Map<String, dynamic> ? params : const <String, dynamic>{},
      );
      stdout.writeln(jsonEncode({'id': id, 'ok': true, 'result': result}));
    } on _RpcError catch (error) {
      stdout.writeln(jsonEncode({
        'id': id,
        'ok': false,
        'error': {'code': error.code, 'message': error.message},
      }));
    } catch (error) {
      stdout.writeln(jsonEncode({
        'id': id,
        'ok': false,
        'error': {'code': 'UPSTREAM_ERROR', 'message': error.toString()},
      }));
    }
  }
}
