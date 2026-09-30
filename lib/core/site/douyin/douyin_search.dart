import 'dart:convert';

import 'package:meta/meta.dart';

import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/common/parser_config.dart';
import 'package:pure_live/core/common/site_ids.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/site/douyin/douyin_audience.dart';
import 'package:pure_live/core/utils/douyin/douyin_request_params.dart';
import 'package:pure_live/core/utils/douyin/douyin_utils.dart';

class DouyinSearch {
  static const String host = 'https://live.douyin.com';

  /// 请求头 UA 与 a_bogus 签名实现同源（DouyinRequestParams.kDefaultUserAgent），
  /// 避免请求头与签名各用不同 Chrome 版本导致的 UA 失配。
  static const String userAgent = DouyinRequestParams.kDefaultUserAgent;

  static const Map<String, dynamic> defaultHeaders = {
    'User-Agent': userAgent,
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'zh-CN,zh;q=0.9',
  };

  static String _cookie = '';
  static Future<String>? _cookieRequest;
  static String _configuredCookieSnapshot = '';

  static Future<String> _getCookie() async {
    if (_cookie.isNotEmpty) {
      return _cookie;
    }

    final configuredCookie = (ParserConfig.instance?.cookieFor(SiteIds.douyinSite) ?? '').trim();

    if (configuredCookie.isNotEmpty) {
      _configuredCookieSnapshot = configuredCookie;
      _cookie = configuredCookie;
      return _cookie;
    }

    // A user may clear or replace the account cookie while the process stays
    // alive. Do not keep searching with the old authenticated session.
    if (_configuredCookieSnapshot.isNotEmpty) {
      _configuredCookieSnapshot = '';
      _cookie = '';
    }

    try {
      final cookie = await (_cookieRequest ??= _fetchCookie());
      _cookieRequest = null;

      if (cookie.isNotEmpty) {
        _cookie = cookie;
      }

      return _cookie;
    } catch (e) {
      _cookieRequest = null;
      CoreLog.error(e);
      return '';
    }
  }

  static Future<String> _fetchCookie() async {
    try {
      final response = await HttpClient.instance.get(
        host,
        queryParameters: const {'from_nav': '1'},
        header: defaultHeaders,
      );

      final setCookieValues = response.headers.map['set-cookie'] ?? const <String>[];

      final cookies = <String>[];

      for (final value in setCookieValues) {
        final cookie = value.split(';').first.trim();

        if (cookie.startsWith('ttwid=') || cookie.startsWith('UIFID_TEMP=')) {
          cookies.add(cookie);
        }
      }

      return cookies.join('; ');
    } catch (e) {
      CoreLog.error(e);
      return '';
    }
  }

  static Future<Map<String, dynamic>> _getHeaders(String keyword) async {
    final cookie = await _getCookie();

    return {
      ...defaultHeaders,
      'Referer': 'https://www.douyin.com/search/${Uri.encodeComponent(keyword)}?source=switch_tab&type=live',
      'Origin': 'https://www.douyin.com',
      'Sec-Fetch-Dest': 'empty',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Site': 'same-origin',
      if (cookie.isNotEmpty) 'Cookie': cookie,
    };
  }

  /// Mirrors zishu live_parser `search.dart::_isCaptchaBody`: an HTML shell,
  /// an empty payload or a captcha notice means the request was rejected by
  /// risk-control instead of returning the JSON API body.
  static bool _isCaptchaBody(String text) {
    final trimmed = text.trim();

    return trimmed.isEmpty ||
        trimmed.startsWith('<!DOCTYPE') ||
        trimmed.startsWith('<html') ||
        trimmed.contains('验证码');
  }

  /// 从 cookie 串里取指定字段值（对齐 zishu live_parser search.dart::_cookiePart）。
  static String _cookieValue(String cookie, String name) {
    for (final part in cookie.split(';')) {
      final index = part.indexOf('=');

      if (index <= 0) continue;

      if (part.substring(0, index).trim() == name) {
        return part.substring(index + 1).trim();
      }
    }

    return '';
  }

  /// Requests a signed search endpoint and decodes the body defensively.
  ///
  /// Returns the parsed rooms plus a failure tag ('' on success) so [search]
  /// can report one summary when the whole fallback chain runs dry. The URL is
  /// signed through [DouyinUtils.buildRequestUrl] (a_bogus + msToken), the same
  /// way as the category/recommend/enter endpoints.
  static Future<(List<LiveRoom>, String)> _fetchSignedSearch(
    String endpoint,
    Map<String, dynamic> params,
    Map<String, dynamic> headers,
  ) async {
    // 优先复用 cookie 里的真实 msToken（对齐 zishu search.dart 的做法），
    // 拿不到时由 buildRequestUrl 走缺省随机生成。
    final cookieMsToken = _cookieValue(await _getCookie(), 'msToken');

    if (cookieMsToken.isNotEmpty) {
      params['msToken'] = cookieMsToken;
    }

    final targetUrl = DouyinUtils.buildRequestUrl(endpoint, params);

    final body = await HttpClient.instance.getText(targetUrl, header: headers);

    if (_isCaptchaBody(body)) {
      CoreLog.w('抖音搜索命中验证码/风控响应: $endpoint');
      return (<LiveRoom>[], 'captcha');
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (e) {
      CoreLog.error(e);
      return (<LiveRoom>[], 'non-json');
    }

    final json = _asMap(decoded);

    if (json == null) {
      return (<LiveRoom>[], 'bad-payload');
    }

    final statusCode = json['status_code']?.toString() ?? '';

    if (statusCode != '0') {
      return (<LiveRoom>[], statusCode.isEmpty ? 'status_code_missing' : 'status_code=$statusCode');
    }

    return (_extractSearchVideos(json['data']), '');
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;

      final text = value.toString();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  static dynamic _mapValue(dynamic value, String key) {
    final map = _asMap(value);
    return map?[key];
  }

  static Map<String, dynamic>? _parseRawLiveData(dynamic item) {
    final itemMap = _asMap(item);

    if (itemMap == null) {
      return null;
    }

    final candidates = <dynamic>[
      _mapValue(_mapValue(itemMap, 'lives'), 'rawdata'),
      _mapValue(_mapValue(itemMap, 'lives'), 'raw_data'),
      _mapValue(_mapValue(itemMap, 'live'), 'rawdata'),
      _mapValue(_mapValue(itemMap, 'live_info'), 'rawdata'),
      _mapValue(_mapValue(_mapValue(itemMap, 'aweme_info'), 'live_info'), 'rawdata'),
      _mapValue(_mapValue(itemMap, 'data'), 'rawdata'),
      itemMap['rawdata'],
      itemMap['lives'],
      itemMap['live'],
      itemMap['live_info'],
      _mapValue(_mapValue(itemMap, 'aweme_info'), 'live_info'),
      itemMap['aweme_info'],
      itemMap['data'],
      itemMap,
    ];

    for (final candidate in candidates) {
      if (candidate is String) {
        try {
          final decoded = jsonDecode(candidate);

          if (decoded is Map) {
            return Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
      } else {
        final map = _asMap(candidate);

        if (map != null) {
          return map;
        }
      }
    }

    return null;
  }

  static LiveRoom? _normalizeSearchItem(Map<String, dynamic>? raw, {Map<String, dynamic>? fallback}) {
    if (raw == null) {
      return null;
    }

    fallback ??= {};

    final room = _asMap(raw['room']) ?? {};
    final owner = _asMap(raw['owner']) ?? {};
    final roomOwner = _asMap(room['owner']) ?? {};

    final roomId = _firstNonEmpty([
      raw['id_str'],
      raw['room_id_str'],
      room['id_str'],
      room['id'],
      raw['room_id'],
      raw['roomId'],
    ]);

    if (roomId.isEmpty) {
      return null;
    }

    final webRid = _firstNonEmpty([owner['web_rid'], raw['web_rid'], roomOwner['web_rid']]);

    final nickname = _firstNonEmpty([owner['nickname'], raw['nickname'], roomOwner['nickname'], fallback['nickname']]);

    final title = _firstNonEmpty([raw['title'], room['title'], fallback['title'], nickname]);

    final cover = _asMap(raw['cover']);
    final roomCover = _asMap(room['cover']);
    final avatarLarge = _asMap(owner['avatar_large']);
    final avatarThumb = _asMap(owner['avatar_thumb']);

    final coverList = roomCover?['url_list'];
    final rawCoverList = cover?['url_list'];
    final avatarList = avatarLarge?['url_list'];
    final avatarThumbList = avatarThumb?['url_list'];

    String getFirstUrl(dynamic value) {
      if (value is List && value.isNotEmpty) {
        return value.first?.toString() ?? '';
      }

      return '';
    }

    final pic = _firstNonEmpty([
      getFirstUrl(avatarList),
      getFirstUrl(rawCoverList),
      getFirstUrl(coverList),
      raw['cover_url'],
    ]);

    final roomOnline = douyinOnlineViewers(room);
    final onlineViewers = roomOnline.isNotEmpty ? roomOnline : douyinOnlineViewers(raw);
    final roomTotal = douyinTotalViewers(room);
    final totalViewers = roomTotal.isNotEmpty ? roomTotal : douyinTotalViewers(raw);
    final nativeAudience = totalViewers.isNotEmpty ? totalViewers : onlineViewers;

    String? tagText;

    final partitionRoadMap = room['partition_road_map'];

    if (partitionRoadMap is List && partitionRoadMap.isNotEmpty) {
      final firstPartition = _asMap(partitionRoadMap.first);

      tagText = firstPartition?['title']?.toString();
    }

    tagText = _firstNonEmpty([raw['video_feed_tag'], tagText, _mapValue(raw['partition'], 'title'), fallback['tag']]);

    final status =
        (raw['status'] is num ? (raw['status'] as num).toInt() : int.tryParse(raw['status']?.toString() ?? '') ?? 0) ==
        2;

    // Keep a deterministic identity. A millisecond timestamp produced invalid
    // room links, changed between refreshes and could collide for adjacent
    // results. The internal room id is a stable fallback when web_rid is absent.
    final realWebRid = webRid.isNotEmpty ? webRid : roomId;

    final avatar = _firstNonEmpty([getFirstUrl(avatarThumbList), getFirstUrl(avatarList)]);

    return LiveRoom(
      roomId: realWebRid,
      title: title,
      cover: pic,
      nick: nickname.isNotEmpty ? nickname : '抖音直播',
      avatar: avatar,
      platform: SiteIds.douyinSite,
      area: tagText,
      status: status,
      liveStatus: status ? LiveStatus.live : LiveStatus.offline,
      watching: nativeAudience,
      totalViewers: totalViewers,
      onlineViewers: onlineViewers,
      audienceMetricType: totalViewers.isNotEmpty ? AudienceMetricType.totalViewers : AudienceMetricType.onlineViewers,
      link: 'https://live.douyin.com/$realWebRid',
    );
  }

  static List<LiveRoom> _extractSearchVideos(dynamic payload) {
    if (payload is! List) {
      return [];
    }

    final result = <LiveRoom>[];
    final seen = <String>{};

    for (final item in payload) {
      final raw = _parseRawLiveData(item);

      final itemMap = _asMap(item) ?? {};

      final room = _normalizeSearchItem(
        raw,
        fallback: {
          'nickname': itemMap['nickname'],
          'title': itemMap['title'] ?? itemMap['desc'],
          'tag': itemMap['search_keyword'],
        },
      );

      if (room == null) {
        continue;
      }

      if (seen.contains(room.roomId)) {
        continue;
      }

      seen.add(room.roomId!);
      result.add(room);
    }

    return result;
  }

  @visibleForTesting
  static List<LiveRoom> parseSearchPayloadForTesting(dynamic payload) => _extractSearchVideos(payload);

  static Future<(List<LiveRoom>, String)> _searchByLiveApi(String keyword, int page, int pageSize) async {
    final count = pageSize.clamp(1, 50).toInt();
    final offset = count * (page - 1);

    final headers = await _getHeaders(keyword);

    final params = {
      'device_platform': 'webapp',
      'aid': '6383',
      'channel': 'channel_pc_web',
      'search_channel': 'aweme_live',
      'search_source': 'switch_tab',
      'query_correct_type': '1',
      'need_filter_settings': '1',
      'list_type': 'single',
      'keyword': keyword,
      'offset': offset.toString(),
      'count': count.toString(),
      'os_version': '10',
    };

    // buildRequestUrl 会追加 aid/msToken/browser_* 等公共参数并生成 a_bogus 签名，
    // 因此请求走完整 targetUrl（与 douyin_site.dart 的 enter/分类端点一致）。
    return _fetchSignedSearch('https://www.douyin.com/aweme/v1/web/live/search/', params, headers);
  }

  static Future<(List<LiveRoom>, String)> _searchByGeneralApi(String keyword, int page, int pageSize) async {
    final count = pageSize.clamp(1, 50).toInt();
    final offset = count * (page - 1);

    final headers = await _getHeaders(keyword);

    final params = {
      'device_platform': 'webapp',
      'aid': '6383',
      'channel': 'channel_pc_web',
      'search_channel': 'aweme_live',
      'keyword': keyword,
      'offset': offset.toString(),
      'count': count.toString(),
      'os_version': '10',
    };

    return _fetchSignedSearch('https://www.douyin.com/aweme/v1/web/general/search/stream/', params, headers);
  }

  static Future<(List<LiveRoom>, String)> _searchByPartition(String keyword, int page, int pageSize) async {
    final headers = await _getHeaders(keyword);

    final result = await HttpClient.instance.getJson(
      'https://live.douyin.com/webcast/web/partition/search/',
      queryParameters: {'keyword': keyword, 'aid': '6383'},
      header: headers,
    );

    final data = _asMap(result['data']);

    final partitions = data?['SearchResult'];

    if (partitions is! List || partitions.isEmpty) {
      final status = _mapValue(result, 'status_code')?.toString() ?? '';
      return (<LiveRoom>[], status.isEmpty ? 'status_code_missing' : 'status_code=$status,partition_list_empty');
    }

    final merged = <LiveRoom>[];
    final seen = <String>{};

    for (var i = 0; i < partitions.length && i < 3; i++) {
      final partitionItem = _asMap(partitions[i]);

      if (partitionItem == null) {
        continue;
      }

      final partition = _asMap(partitionItem['partition']);

      if (partition == null) {
        continue;
      }

      final partitionId = partition['id_str']?.toString();
      final partitionType = partition['type'];

      if (partitionId == null || partitionId.isEmpty || partitionType == null) {
        continue;
      }

      try {
        final rooms = await _getPartitionRooms(partitionId, partitionType.toString(), page: page, pageSize: pageSize);

        for (final room in rooms) {
          if (seen.contains(room.roomId)) {
            continue;
          }

          seen.add(room.roomId!);

          if (room.area == null || room.area!.isEmpty) {
            merged.add(room.copyWith(area: partition['title']?.toString() ?? keyword));
          } else {
            merged.add(room);
          }

          if (merged.length >= pageSize) {
            return (merged, '');
          }
        }
      } catch (e) {
        CoreLog.error(e);
      }
    }

    return (merged, merged.isEmpty ? 'status_code=0,partition_rooms_empty' : '');
  }

  static Future<List<LiveRoom>> _getPartitionRooms(
    String partition,
    String partitionType, {
    required int page,
    required int pageSize,
  }) async {
    final count = pageSize.clamp(1, 50).toInt();
    final params = {
      'aid': '6383',
      'app_name': 'douyin_web',
      'live_id': '1',
      'device_platform': 'web',
      'language': 'zh-CN',
      'browser_language': 'zh-CN',
      'browser_platform': 'Win32',
      'browser_name': 'Chrome',
      'browser_version': '120.0.0.0',
      'partition': partition,
      'partition_type': partitionType,
      'count': count.toString(),
      'offset': ((page - 1) * count).toString(),
      'cookie_enabled': 'true',
      'screen_width': '1920',
      'screen_height': '1080',
    };

    final headers = await _getHeaders('');

    final urls = [
      'https://live.douyin.com/webcast/web/partition/detail/room/v2/',
      'https://webcast.amemv.com/webcast/web/partition/detail/room/v2/',
    ];

    for (final url in urls) {
      try {
        final result = await HttpClient.instance.getJson(url, queryParameters: params, header: headers);

        if (result['status_code'] != 0) {
          continue;
        }

        final data = _asMap(result['data']);
        final list = data?['data'];

        if (list is! List || list.isEmpty) {
          continue;
        }

        final rooms = <LiveRoom>[];

        for (final item in list) {
          final itemMap = _asMap(item);

          if (itemMap == null) {
            continue;
          }

          final room = _asMap(itemMap['room']);

          if (room == null) {
            continue;
          }

          final owner = _asMap(room['owner']) ?? {};
          final cover = _asMap(room['cover']) ?? {};
          final avatar = _asMap(owner['avatar_thumb']) ?? {};
          final coverList = cover['url_list'];
          final avatarList = avatar['url_list'];

          final coverUrl = coverList is List && coverList.isNotEmpty ? coverList.first.toString() : '';

          final avatarUrl = avatarList is List && avatarList.isNotEmpty ? avatarList.first.toString() : '';

          final webRid = _firstNonEmpty([itemMap['web_rid'], owner['web_rid']]);

          final roomId = room['id_str']?.toString();

          if (roomId == null || roomId.isEmpty) {
            continue;
          }

          final rid = webRid.isNotEmpty ? webRid : roomId;

          final totalViewers = douyinTotalViewers(room);
          final onlineViewers = douyinOnlineViewers(room);
          final nativeAudience = totalViewers.isNotEmpty ? totalViewers : onlineViewers;

          rooms.add(
            LiveRoom(
              roomId: rid,
              title: room['title']?.toString() ?? '',
              cover: coverUrl,
              nick: owner['nickname']?.toString() ?? '',
              avatar: avatarUrl,
              platform: SiteIds.douyinSite,
              area: itemMap['tag_name']?.toString() ?? '',
              status: true,
              liveStatus: LiveStatus.live,
              watching: nativeAudience,
              totalViewers: totalViewers,
              onlineViewers: onlineViewers,
              audienceMetricType: totalViewers.isNotEmpty
                  ? AudienceMetricType.totalViewers
                  : AudienceMetricType.onlineViewers,
              link: 'https://live.douyin.com/$rid',
            ),
          );
        }

        return rooms;
      } catch (e) {
        CoreLog.error(e);
      }
    }

    return [];
  }

  static Future<List<LiveRoom>> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final kw = keyword.trim();
    final normalizedPage = page < 1 ? 1 : page;
    final normalizedPageSize = pageSize.clamp(1, 50).toInt();

    if (kw.isEmpty) {
      return [];
    }

    final failures = <String>[];

    List<LiveRoom> reportEmpty() {
      CoreLog.w('抖音搜索三级降级全部为空 keyword="$kw" page=$normalizedPage [${failures.join(' | ')}]');
      return const [];
    }

    try {
      try {
        final (rooms, note) = await _searchByLiveApi(kw, normalizedPage, normalizedPageSize);

        if (rooms.isNotEmpty) {
          return rooms;
        }

        failures.add('live:$note');
      } catch (e) {
        CoreLog.error(e);
        failures.add('live:error');
      }

      try {
        final (rooms, note) = await _searchByGeneralApi(kw, normalizedPage, normalizedPageSize);

        if (rooms.isNotEmpty) {
          return rooms;
        }

        failures.add('general:$note');
      } catch (e) {
        CoreLog.error(e);
        failures.add('general:error');
      }

      final (rooms, note) = await _searchByPartition(kw, normalizedPage, normalizedPageSize);

      if (rooms.isNotEmpty) {
        return rooms;
      }

      failures.add('partition:$note');

      return reportEmpty();
    } catch (e) {
      CoreLog.error(e);
      failures.add('partition:error');
      return reportEmpty();
    }
  }
}
