// Pure Live parsing sidecar — the SAME lib/core sources the Flutter app uses,
// compiled by `dart compile exe` for the Node streaming server.
//
// Protocol: one JSON request per stdin line, one JSON response per stdout
// line: {"id":<req id>,"method":<name>,"params":{...}} ->
// {"id":<req id>,"ok":true,"result":...} | {"id":<req id>,"ok":false,
// "error":{"code":"...","message":"..."}}.
//
// Methods: health | resolve | liveStatus | qualities | playUrls
//          | categories | categoryRooms | recommendRooms | searchRooms
//          | danmakuStart | danmakuStop (push frames via stdout)
// (contracts stay in contracts/api.md; this process is a Dart-side
// implementation detail of the streaming server's ResolverBackend).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pure_live/core/utils/type_cast.dart';
import 'package:pure_live/core/network/parser_config.dart';
import 'package:pure_live/core/network/site_ids.dart';
import 'package:pure_live/shared/platforms/bilibili/bilibili_site.dart';
import 'package:pure_live/shared/platforms/douyin/douyin_site.dart';
import 'package:pure_live/shared/platforms/huya/huya_site.dart';
import 'package:pure_live/shared/platforms/douyu/douyu_site.dart';
import 'package:pure_live/shared/platforms/douyin/douyin_danmaku.dart';
import 'package:pure_live/shared/platforms/huya/huya_danmaku.dart';
import 'package:pure_live/shared/platforms/douyu/douyu_danmaku.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/core/models/live_area.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/models/live_room.dart';

/// Page-size ceiling shared by every list method (api.md 4.6).
const int _maxPageSize = 50;

/// Optional operator cookie injection: PARSER_<PLATFORM>_COOKIE (e.g.
/// PARSER_DOUYIN_COOKIE) aligns the sidecar with a logged-in app for the
/// parsing paths that gate on cookie (douyin search, higher qualities).
/// Without the env the sidecar keeps running anonymous, as before.
class _EnvParserConfig implements ParserConfig {
  @override
  String cookieFor(String platform) {
    final key = 'PARSER_${platform.toUpperCase()}_COOKIE';
    return Platform.environment[key] ?? '';
  }

  @override
  String persistentCookieFor(String platform) => cookieFor(platform);

  @override
  Object? auxiliaryFor(String platform, String key) => null;
}

/// Live danmaku sessions (douyin/huya/douyu) keyed by "platform:roomId";
/// frames are pushed to stdout as
/// {"push":"danmaku","platform":...,"roomId":...,"frame":{...}} envelopes.
/// All platforms drive the SAME lib/core implementations the Flutter app uses.
final Map<String, LiveDanmaku> _danmakuSessions = {};

String _isoTs(DateTime? at) => (at ?? DateTime.now()).toUtc().toIso8601String();

void _pushDanmakuFrame(String sessionKey, Map<String, dynamic> frame) {
  final separator = sessionKey.indexOf(':');
  stdout.writeln(
    jsonEncode({
      'push': 'danmaku',
      'platform': sessionKey.substring(0, separator),
      'roomId': sessionKey.substring(separator + 1),
      'frame': frame,
    }),
  );
}

void _stopDanmakuSession(String platform, String roomId) {
  final session = _danmakuSessions.remove('$platform:$roomId');
  if (session == null) return;
  session.onMessage = null;
  session.onReconnect = null;
  session.onClose = null;
  session.onReady = null;
  session.stop();
}

/// Per-platform danmaku construction from the room's danmakuData payload:
/// douyin/huya carry typed arg objects, douyu carries the numeric roomId.
LiveDanmaku _danmakuFor(String platform, Object? args) {
  switch (platform) {
    case 'douyin':
      if (args is DouyinDanmakuArgs) return DouyinDanmaku();
      break;
    case 'huya':
      if (args is HuyaDanmakuArgs) return HuyaDanmaku();
      break;
    case 'douyu':
      if (args is String && args.isNotEmpty) return DouyuDanmaku();
      break;
  }
  throw _RpcError('ROOM_CLOSED', 'room has no danmaku session data (offline?)');
}

Future<Object?> _startDanmakuSession(String platform, String roomId) async {
  final sessionKey = '$platform:$roomId';
  if (_danmakuSessions.containsKey(sessionKey)) {
    return {'started': true, 'roomId': roomId, 'existing': true};
  }
  final site = _sites[platform];
  if (site == null) {
    throw _RpcError('PLATFORM_UNSUPPORTED', 'platform "$platform" is not built into this sidecar');
  }
  final room = await site.getRoomDetail(LiveRoom(roomId: roomId, platform: platform));
  final session = _danmakuFor(platform, room.danmakuData);

  session.onMessage = (message) {
    if (message.type == LiveMessageType.chat) {
      _pushDanmakuFrame(sessionKey, {
        'type': 'chat',
        'userName': message.userName,
        'userId': message.userId,
        'text': message.message,
        'avatar': '',
        'ts': _isoTs(message.sentAt),
      });
    } else if (message.type == LiveMessageType.online) {
      _pushDanmakuFrame(sessionKey, {
        'type': 'online',
        'kind': message.data.kind.name,
        'value': message.data.value,
        'ts': _isoTs(null),
      });
    }
  };
  session.onReady = () {
    _pushDanmakuFrame(sessionKey, {'type': 'status', 'state': 'connected'});
  };
  session.onReconnect = (msg) {
    _pushDanmakuFrame(sessionKey, {'type': 'status', 'state': 'reconnecting', 'message': msg});
  };
  session.onClose = (msg) {
    _pushDanmakuFrame(sessionKey, {'type': 'status', 'state': 'closed', 'message': msg});
    _danmakuSessions.remove(sessionKey);
  };
  _danmakuSessions[sessionKey] = session;
  try {
    await session.start(room.danmakuData);
  } catch (error) {
    _danmakuSessions.remove(sessionKey);
    throw _RpcError('UPSTREAM_ERROR', 'danmaku start failed: $error');
  }
  return {'started': true, 'roomId': roomId};
}

int _pageOf(Map<String, dynamic> params) {
  final value = asT<int?>(params['page']) ?? (int.tryParse('${params['page'] ?? ''}') ?? 1);
  return value < 1 ? 1 : value;
}

int _pageSizeOf(Map<String, dynamic> params) {
  final value = asT<int?>(params['pageSize']) ?? (int.tryParse('${params['pageSize'] ?? ''}') ?? 30);
  if (value < 1) return 30;
  return value > _maxPageSize ? _maxPageSize : value;
}

Map<String, dynamic> _roomListResult(List<LiveRoom> rooms, int page, int pageSize) {
  return {
    'page': page,
    'hasMore': rooms.length >= pageSize,
    'rooms': [for (final room in rooms) _roomToJson(room)],
  };
}

final Map<String, LiveSite> _sites = {
  SiteIds.bilibiliSite: BiliBiliSite(),
  SiteIds.douyinSite: DouyinSite(),
  SiteIds.huyaSite: HuyaSite(),
  SiteIds.douyuSite: DouyuSite(),
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
    'audienceMetricType': room.audienceMetricType?.name ?? 'unknown',
    'totalViewers': room.totalViewers ?? '',
    'followers': room.followers ?? '',
    'area': room.area ?? '',
    'introduction': room.introduction ?? '',
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
      final room = await site.getRoomDetail(LiveRoom(roomId: roomId, platform: platform));
      return {'room': _roomToJson(room)};

    case 'liveStatus':
      // Cheap liveness probe for follow lists (api.md 4.3.1): any upstream or
      // shape failure reads as offline instead of surfacing a transport error.
      if (roomId.isEmpty) throw _RpcError('BAD_REQUEST', 'roomId is required');
      try {
        final detail = await site.getRoomDetail(LiveRoom(roomId: roomId, platform: platform));
        return {'live': detail.liveStatus == LiveStatus.live};
      } catch (_) {
        return {'live': false};
      }

    case 'qualities':
      if (roomId.isEmpty) throw _RpcError('BAD_REQUEST', 'roomId is required');
      final room = await site.getRoomDetail(LiveRoom(roomId: roomId, platform: platform));
      final qualities = await site.getPlayQualites(liveroom: room);
      return {
        'qualities': [
          for (final q in qualities) {'selectionId': '${q.selectionId}', 'label': q.quality},
        ],
      };

    case 'playUrls':
      if (roomId.isEmpty) throw _RpcError('BAD_REQUEST', 'roomId is required');
      final room = await site.getRoomDetail(LiveRoom(roomId: roomId, platform: platform));
      final qualities = await site.getPlayQualites(liveroom: room);
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
      final urls = await site.getPlayUrls(liveroom: room, quality: chosen);
      return {'quality': chosen.quality, 'qualityId': '${chosen.selectionId}', 'urls': urls};

    case 'categories':
      {
        final page = _pageOf(params);
        final pageSize = _pageSizeOf(params);
        final categories = await site.getCategores(page, pageSize);
        return {
          'categories': [
            for (final category in categories)
              {
                'id': category.id,
                'name': category.name,
                'children': [for (final area in category.children) area.toJson()],
              },
          ],
        };
      }

    case 'categoryRooms':
      {
        final page = _pageOf(params);
        final pageSize = _pageSizeOf(params);
        final areaId = asT<String?>(params['areaId']) ?? '';
        if (areaId.isEmpty) throw _RpcError('BAD_REQUEST', 'areaId is required');
        final area = LiveArea(
          platform: platform,
          areaType: asT<String?>(params['areaType']),
          typeName: asT<String?>(params['typeName']),
          areaId: areaId,
          areaName: asT<String?>(params['areaName']),
        );
        final rooms = await site.getCategoryRooms(area, page: page, pageSize: pageSize);
        return _roomListResult(rooms, page, pageSize);
      }

    case 'recommendRooms':
      {
        final page = _pageOf(params);
        final pageSize = _pageSizeOf(params);
        final rooms = await site.getRecommendRooms(page: page, pageSize: pageSize);
        return _roomListResult(rooms, page, pageSize);
      }

    case 'searchRooms':
      {
        final page = _pageOf(params);
        final pageSize = _pageSizeOf(params);
        final keyword = asT<String?>(params['keyword']) ?? '';
        if (keyword.trim().isEmpty) throw _RpcError('BAD_REQUEST', 'keyword is required');
        final rooms = await site.searchRooms(keyword.trim(), page: page, pageSize: pageSize);
        return _roomListResult(rooms, page, pageSize);
      }

    case 'danmakuStart':
      {
        // Douyin/huya/douyu danmaku run on the SAME lib/core implementations as
        // the app; frames flow back as stdout push envelopes. Bilibili stays a
        // host-side TS source (contracts/api.md section 5 is unchanged).
        if (roomId.isEmpty) throw _RpcError('BAD_REQUEST', 'roomId is required');
        return await _startDanmakuSession(platform, roomId);
      }

    case 'danmakuStop':
      {
        if (roomId.isEmpty) throw _RpcError('BAD_REQUEST', 'roomId is required');
        _stopDanmakuSession(platform, roomId);
        return {'stopped': true, 'roomId': roomId};
      }

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

  ParserConfig.instance ??= _EnvParserConfig();

  stdout.writeln(jsonEncode({'ok': true, 'started': true, 'platforms': _sites.keys.toList(growable: false)}));

  final lineStream = stdin.transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter());

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
      stdout.writeln(
        jsonEncode({
          'id': id,
          'ok': false,
          'error': {'code': error.code, 'message': error.message},
        }),
      );
    } catch (error) {
      stdout.writeln(
        jsonEncode({
          'id': id,
          'ok': false,
          'error': {'code': 'UPSTREAM_ERROR', 'message': error.toString()},
        }),
      );
    }
  }
}
