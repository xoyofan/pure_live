/// 抖音关注列表导入(真源:zishu_flutter
/// `packages/live_parser/lib/src/platforms/douyin/follow_import.dart` 的
/// pure_live 适配版,考古提交 e369366 → 2c8d208 → 04e8a4b)。
///
/// 对齐口径:
/// - 登录 cookie 必需:cookie 由调用方注入(DouyinSite 解析
///   ParserConfig/账号页 douyinCookie),不做 ttwid 匿名兜底 ——
///   关注列表与 profile/self 接口只认登录态(真源经
///   platformCredentialsProvider 注入 cookieOverride 同语义);
/// - 签名:与本仓搜索同源,走 [DouyinUtils.buildRequestUrl]
///   (a_bogus + msToken),UA 用 DouyinRequestParams.kDefaultUserAgent,
///   请求头与签名同源(对齐 douyin_search.dart 的 UA 失配规避口径);
/// - sec_uid 三级解析:profile/self → query/user → follow 页 HTML;
/// - 分页:following/list 按 offset 游标,50/页,has_more 停,上限 500 页;
/// - 字段映射:复刻 tool/import_zishu_data.dart 的 LiveRoom 装配口径
///   (nick=uname、area/typeName=category、离线占位),导入条目恒为
///   离线占位,在播状态交给组合同步随后的全量刷新(真源 04e8a4b 语义);
/// - 合并:[mergeImportedRooms] 复刻真源 follow_provider._mergeImported
///   的「合并重复」口径 —— 元信息(标题/主播/头像/封面/分类)以导入源
///   为准,在播状态/统计/标签等本地标记保留,离线占位不翻转在播条目。
library;

import 'dart:convert';
import 'dart:math';

import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/parser_config.dart';
import 'package:pure_live/core/common/site_ids.dart';
import 'package:pure_live/core/site/douyin/douyin_audience.dart';
import 'package:pure_live/core/utils/douyin/douyin_request_params.dart';
import 'package:pure_live/core/utils/douyin/douyin_utils.dart';

/// 关注导入进度(真源 DouyinFollowImportProgress 同形:第 page 页已发现
/// imported 个,total 为服务端给出的关注总数,未知为 0)。
class DouyinFollowImportProgress {
  const DouyinFollowImportProgress({required this.page, required this.imported, this.total = 0});

  final int page;
  final int imported;
  final int total;
}

/// 「导入抖音关注」能力位:[DouyinSite] 实现;UI 经
/// `Sites.of(Sites.douyinSite).liveSite is DouyinFollowImporter` 探测,
/// 与逐房间刷新的 LiveSiteRoomRefresher 能力位同一套用法。
///
/// 「导入直播中」([importFollowingLive])以**扩展**提供默认实现
/// ([DouyinFollowImporterLive]):接口本体不能加抽象成员 —— 本仓
/// DouyinSite 用 `implements` 实现该接口(implements 不继承方法体),
/// 加抽象成员会逼 DouyinSite 同步补实现,而 douyin_site.dart 不在本轨
/// 白名单内;扩展成员对所有实现者可见且零侵入,是 Dart 侧「接口默认
/// 实现」的等价机制。
abstract interface class DouyinFollowImporter {
  /// 拉取当前登录账号的全部关注并转为离线占位房间。
  Future<List<LiveRoom>> importFollowing({void Function(DouyinFollowImportProgress progress)? onProgress});

  /// 登录 cookie 是否就绪(无 cookie 时 UI 置灰导入按钮)。
  bool get hasFollowImportCookie;
}

/// 「导入直播中」默认实现(关注页抖音筛选下的直播关注导入):
/// 协议层直接走**只返回在播房间**的 `/webcast/feed/follow_top/`
/// (真源 fetchDouyinFollowLiveRooms 同端点)—— 而非「importFollowing
/// 结果按 isLiveNow 过滤」:关注列表接口(`following/list`)不带可信
/// 在播状态,导入条目恒为离线占位,过滤它恒得空集,等于假按钮。
extension DouyinFollowImporterLive on DouyinFollowImporter {
  /// 拉取当前登录账号关注中正在直播的房间(真源 follow_provider
  /// importDouyinLiveFollows 的协议位,complete 关注导入的轻量回退:
  /// `/following/list/` 被限流时仍可先把在播房间加入关注)。
  ///
  /// 登录 cookie 经 [DouyinFollowImport.fetchFollowingLive] 从
  /// ParserConfig 解析,口径与 [DouyinFollowImporter.hasFollowImportCookie]
  /// 对应的账号页 douyinCookie 一致。
  Future<List<LiveRoom>> importFollowingLive({void Function(DouyinFollowImportProgress progress)? onProgress}) {
    return DouyinFollowImport.fetchFollowingLive(onProgress: onProgress);
  }
}

class DouyinFollowImport {
  DouyinFollowImport._();

  /// web 端关注接口宿主(与真源同为 www.douyin.com 而非 live.douyin.com)。
  static const String _webHost = 'https://www.douyin.com';

  /// 分页上限(真源同款护栏:游标异常时不再无限请求)。
  static const int _maxPages = 500;

  /// 拉取当前抖音账号的全部关注用户,转为离线占位 [LiveRoom] 列表。
  ///
  /// 关注接口与直播状态接口分开:前者用于导入全部关注(含未开播),
  /// 后者只返回正在直播的关注(本仓未移植,组合同步用全量刷新替代)。
  /// 接口按 max_time 顺序游标分页,不并发请求。
  static Future<List<LiveRoom>> fetchFollowing({
    required String cookie,
    void Function(DouyinFollowImportProgress progress)? onProgress,
  }) async {
    final sessionCookie = cookie.trim();
    if (sessionCookie.isEmpty) {
      throw StateError('导入抖音关注需要登录 Cookie');
    }

    final secUid = await _fetchDouyinSecUid(sessionCookie);
    if (secUid.isEmpty) {
      throw StateError('无法获取抖音当前账号 sec_uid');
    }

    final rooms = <LiveRoom>[];
    final seen = <String>{};
    var offset = 0;
    var sourceType = 2;
    for (var page = 0; page < _maxPages; page++) {
      final params = <String, dynamic>{
        'device_platform': 'webapp',
        'sec_user_id': secUid,
        'max_time': '0',
        'min_time': '0',
        'offset': '$offset',
        'count': '50',
        'source_type': '$sourceType',
        'address_book_access': '2',
        'gps_access': '1',
        'is_top': '0',
        ..._webIdentityParams(sessionCookie),
      };

      final json = await _signedWebGet(
        '$_webHost/aweme/v1/web/user/following/list/',
        cookie: sessionCookie,
        referer: '$_webHost/user/$secUid',
        params: params,
      );
      final statusCode = _asInt(json['status_code']);
      if (statusCode != 0) {
        throw StateError('抖音关注列表获取失败(code=$statusCode)');
      }

      _collectFollowingRooms(json, rooms, seen);
      final total = _asInt(json['total']);
      final hasMore = _asBool(json['has_more'] ?? json['hasMore']);
      onProgress?.call(DouyinFollowImportProgress(page: page + 1, imported: rooms.length, total: total));
      if (!hasMore) break;
      final nextOffset = _asInt(json['offset']);
      offset = nextOffset > offset ? nextOffset : offset + 50;
      sourceType = 1;
    }
    return rooms;
  }

  /// 分页上限(真源 fetchDouyinFollowLiveRooms 同款护栏:游标异常时停)。
  static const int _maxFollowLivePages = 200;

  /// 登录 cookie:与 [DouyinSite] 关注导入同源(ParserConfig 账号页
  /// douyinCookie,trim 后判空;不做 ttwid 匿名兜底)。此处按同一表达式
  /// 解析而非从 DouyinSite 取 —— 该字段是其私有 getter,本轨白名单不含
  /// douyin_site.dart;两侧口径耦合点在此注释锚定,cookie 来源变更须同改。
  static String _followImportCookie() => (ParserConfig.instance?.persistentCookieFor(SiteIds.douyinSite) ?? '').trim();

  /// 拉取当前登录账号关注中**正在直播**的房间([DouyinFollowImporterLive
  /// .importFollowingLive] 的协议实现)。
  ///
  /// - 端点 `/webcast/feed/follow_top/`:返回关注直播流,翻页游标为
  ///   `extra.follow_session_id` + `extra.max_time`(真源
  ///   fetchDouyinFollowLiveRooms 同参数表;与 following/list 的 offset
  ///   游标不同源,不混用);
  /// - 响应 envelope 解析与首页 feed 同形(data 列表 / data.data 两种代次),
  ///   房间恒带在播状态(feed 只含在播间,导入占位无需刷新回填);
  /// - [cookie] 缺省走 [_followImportCookie];空 cookie 抛 StateError
  ///   (与 [fetchFollowing] 同语义,UI 侧经 hasFollowImportCookie 置灰);
  /// - [onProgress]:feed 无关注总数(total 恒 0,不伪造),报第 page 页
  ///   已发现 imported 个。
  static Future<List<LiveRoom>> fetchFollowingLive({
    String? cookie,
    void Function(DouyinFollowImportProgress progress)? onProgress,
  }) async {
    final sessionCookie = (cookie ?? _followImportCookie()).trim();
    if (sessionCookie.isEmpty) {
      throw StateError('导入抖音直播关注需要登录 Cookie');
    }

    final rooms = <LiveRoom>[];
    final seen = <String>{};
    var followSessionId = '0';
    var maxTime = '0';
    for (var page = 0; page < _maxFollowLivePages; page++) {
      // webcast 系端点在 live 宿主(真源 signedDouyinGet 基址
      // live.douyin.com;本仓 getRecommendRooms 的 /webcast/feed/ 同宿主),
      // 与 aweme 系的 following/list(www 宿主)不同源。
      final json = await _signedWebGet(
        'https://live.douyin.com/webcast/feed/follow_top/',
        cookie: sessionCookie,
        referer: 'https://live.douyin.com/',
        params: <String, dynamic>{
          'aid': '6383',
          'app_name': 'douyin_web',
          'live_id': '1',
          'device_platform': 'web',
          'language': 'zh-CN',
          'enter_from': 'link_share',
          'cookie_enabled': 'true',
          'screen_width': '1920',
          'screen_height': '1080',
          'browser_language': 'zh-CN',
          'browser_platform': 'Win32',
          'browser_name': 'Chrome',
          'browser_version': '141.0.0.0',
          'os_name': 'Windows',
          'os_version': '10',
          'enter_source': 'homepage_pc_followtop',
          'need_pinned_info': '0',
          'source_key': 'web_homepage_follow_top',
          'webcast_version_code': '170400',
          'version_code': '170400',
          'need_map': '1',
          'follow_session_id': followSessionId,
          'maxtime': maxTime,
        },
      );
      final statusCode = _asInt(json['status_code']);
      if (statusCode != 0) {
        throw StateError('抖音关注直播流获取失败(code=$statusCode)');
      }

      _collectFollowingLiveRooms(json, rooms, seen);
      onProgress?.call(DouyinFollowImportProgress(page: page + 1, imported: rooms.length));

      final extra = json['extra'] is Map ? Map<String, dynamic>.from(json['extra'] as Map) : const <String, dynamic>{};
      if (!_asBool(extra['has_more'])) break;
      final nextSessionId = _firstText([extra['follow_session_id']]);
      final nextMaxTime = _firstText([extra['max_time']]);
      // 游标缺失或未推进:停,不再空转请求(真源同款护栏)。
      if (nextSessionId.isEmpty || nextMaxTime.isEmpty) break;
      if (nextSessionId == followSessionId && nextMaxTime == maxTime) break;
      followSessionId = nextSessionId;
      maxTime = nextMaxTime;
    }
    return rooms;
  }

  /// 递归收集 follow_top feed 的房间 envelope(响应与首页 feed 同形:
  /// envelope 内嵌 data(JSON 字符串或 Map)/ room / 自身三代候选,
  /// 对齐 DouyinSite.parseRecommendRooms 的形状兼容口径)。
  static void _collectFollowingLiveRooms(Object? value, List<LiveRoom> rooms, Set<String> seen) {
    final rawData = value is Map ? value['data'] : null;
    final entries = rawData is Map ? rawData['data'] : rawData;
    if (entries is! List) return;
    for (final raw in entries) {
      final room = _followLiveRoomFromEnvelope(raw);
      if (room != null && seen.add(room.normalizedRoomId)) rooms.add(room);
    }
  }

  /// 单条 feed envelope → 在播 [LiveRoom];无房间号/无房间形状返回 null。
  static LiveRoom? _followLiveRoomFromEnvelope(Object? raw) {
    final envelope = _mapOf(raw);
    if (envelope == null) return null;
    final embedded = _mapOf(_decodeEmbeddedJson(envelope['data']));
    final nestedRoom = _mapOf(envelope['room']);
    final room = <Map<String, dynamic>?>[embedded, nestedRoom, envelope].firstWhere(
      (candidate) => candidate != null && _looksLikeLiveFeedRoom(candidate),
      orElse: () => null,
    );
    if (room == null) return null;

    final owner = _mapOf(room['owner']) ?? _mapOf(envelope['owner']) ?? const <String, dynamic>{};
    final roomId = _firstText([
      envelope['web_rid'],
      owner['web_rid'],
      room['web_rid'],
      room['id_str'],
      room['id'],
    ]);
    if (roomId.isEmpty) return null;

    final nick = _firstText([owner['nickname'], envelope['nickname']]);
    final title = _firstText([room['title'], envelope['title'], nick]);
    final totalViewers = douyinTotalViewers(room);
    final onlineViewers = douyinOnlineViewers(room);
    final cover = _imageUrl(room['cover']);
    final avatar = _firstText([
      _imageUrl(owner['avatar_thumb']),
      _imageUrl(owner['avatar_large']),
      _imageUrl(envelope['avatar_thumb']),
    ]);
    return LiveRoom(
      roomId: roomId,
      userId: '',
      title: title,
      nick: nick,
      avatar: avatar,
      cover: cover.isEmpty ? _imageUrl(envelope['cover']) : cover,
      area: _followLiveCategory(envelope, room),
      typeName: '',
      watching: totalViewers.isNotEmpty ? totalViewers : onlineViewers,
      followers: '0',
      platform: SiteIds.douyinSite,
      link: 'https://live.douyin.com/$roomId',
      status: true,
      liveStatus: LiveStatus.live,
      totalViewers: totalViewers,
      onlineViewers: onlineViewers,
      audienceMetricType: totalViewers.isNotEmpty ? AudienceMetricType.totalViewers : AudienceMetricType.onlineViewers,
    );
  }

  /// envelope 内嵌 data 兼容:直接是 Map,或是 JSON 字符串(新版 feed 把
  /// 房间塞进字符串编码的 data 字段,首页 feed 同款)。
  static Object? _decodeEmbeddedJson(Object? value) {
    if (value is Map) return value;
    final text = value?.toString().trim() ?? '';
    if (!text.startsWith('{')) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  static Map<String, dynamic>? _mapOf(Object? value) => value is Map ? Map<String, dynamic>.from(value) : null;

  static bool _looksLikeLiveFeedRoom(Map<String, dynamic> value) =>
      value['owner'] is Map || value['title'] != null || value['id_str'] != null || value['stream_url'] is Map;

  /// follow feed 的分类:tag_name 直取,缺失走 partition_road_map/tags 的
  /// 标签表;全缺回落「关注」—— 与本文件导入占位分类同口径(feed 房间
  /// 无分类不是「热门推荐」,不伪造真源首页 feed 的兜底文案)。
  static String _followLiveCategory(Map<String, dynamic> envelope, Map<String, dynamic> room) {
    final direct = _firstText([room['tag_name'], envelope['tag_name']]);
    if (direct.isNotEmpty) return direct;
    for (final source in [room['partition_road_map'], envelope['tags']]) {
      if (source is! List) continue;
      for (final rawTag in source) {
        final tag = _mapOf(rawTag);
        if (tag == null) continue;
        final text = _firstText([tag['title'], tag['name'], tag['tag_name']]);
        if (text.isNotEmpty) return text;
      }
    }
    return '关注';
  }

  /// 导入结果与已有收藏合并(真源「组合同步:合并重复」口径)。
  ///
  /// - 按 identityKey(`platform:roomId`)索引:导入列表内部同 key 重复
  ///   天然去重(后写赢),与已有条目同 key 的只做元信息合并;
  /// - 元信息(标题/主播/头像/封面/分类)以导入源非空者为准;
  /// - 在播状态/统计/标签/录播等本地标记一律保留 —— 关注列表接口不带
  ///   可信在播状态,导入源的离线占位不得把在播条目刷成离线;
  /// - 本地没有的 key 作为新条目按导入顺序追加。
  ///
  /// 返回 (合并后的完整列表, 本次新增条数)。无新增且元信息未变时,
  /// 合并产物与原列表逐字段相等,调用方按既有落库快照比较即可跳过写盘。
  static (List<LiveRoom>, int) mergeImportedRooms(List<LiveRoom> current, List<LiveRoom> imported) {
    final freshByKey = {for (final room in imported) room.identityKey: room};
    if (freshByKey.isEmpty) return (current, 0);

    final existingKeys = {for (final room in current) room.identityKey};
    final additions = <LiveRoom>[
      for (final entry in freshByKey.entries)
        if (!existingKeys.contains(entry.key)) entry.value,
    ];

    final merged = <LiveRoom>[
      for (final room in current)
        freshByKey.containsKey(room.identityKey) ? _mergeImported(room, freshByKey[room.identityKey]!) : room,
      ...additions,
    ];
    return (merged, additions.length);
  }

  /// 同 key 条目的房间记录合并(真源 _mergeImported 逐字段口径)。
  static LiveRoom _mergeImported(LiveRoom current, LiveRoom fresh) {
    if (!current.hasSameIdentity(fresh)) return current;

    String pick(String? incoming, String? existing) =>
        incoming != null && incoming.trim().isNotEmpty ? incoming : (existing ?? '');

    // 在播状态/统计/标签等字段不进 copyWith,天然保留本地值。
    return current.copyWith(
      title: pick(fresh.title, current.title),
      nick: pick(fresh.nick, current.nick),
      avatar: pick(fresh.avatar, current.avatar),
      cover: pick(fresh.cover, current.cover),
      area: pick(fresh.area, current.area),
      typeName: pick(fresh.typeName, current.typeName),
    );
  }

  /// web 端接口公共身份参数(真源 _douyinWebBaseParams 的精简移植:
  /// verifyFp/webid 从 cookie 还原,取不到再随机;设备/浏览器档位由
  /// buildRequestUrl 统一追加,不在此重复)。
  static Map<String, String> _webIdentityParams(String cookie) {
    final verifyFp = _cookiePart(cookie, 's_v_web_id').isNotEmpty
        ? _cookiePart(cookie, 's_v_web_id')
        : _buildVerifyFp();
    final webId = _cookiePart(cookie, 'webid').isNotEmpty
        ? _cookiePart(cookie, 'webid')
        : _cookiePart(cookie, 'UIFID').isNotEmpty
        ? _cookiePart(cookie, 'UIFID')
        : '${1000000000 + Random.secure().nextInt(2000000000)}';
    return {'verifyFp': verifyFp, 'fp': verifyFp, 'webid': webId};
  }

  /// 签名 GET(搜索同源):buildRequestUrl 追加公共参数并生成 a_bogus,
  /// 响应按 JSON 解析;命中验证码/风控时以 HTML 壳形态出现,直接抛错。
  static Future<Map<String, dynamic>> _signedWebGet(
    String endpoint, {
    required String cookie,
    required String referer,
    required Map<String, dynamic> params,
  }) async {
    // 优先复用 cookie 里的真实 msToken(对齐 douyin_search 的做法)。
    final cookieMsToken = _cookiePart(cookie, 'msToken');
    if (cookieMsToken.isNotEmpty) {
      params['msToken'] = cookieMsToken;
    }

    final targetUrl = DouyinUtils.buildRequestUrl(endpoint, params);
    final body = await HttpClient.instance.getText(
      targetUrl,
      header: {
        'User-Agent': DouyinRequestParams.kDefaultUserAgent,
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'zh-CN,zh;q=0.9',
        'Referer': referer,
        'Origin': _webHost,
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-origin',
        'Cookie': cookie,
      },
    );

    final trimmed = body.trim();
    if (trimmed.isEmpty || trimmed.startsWith('<!DOCTYPE') || trimmed.startsWith('<html') || trimmed.contains('验证码')) {
      throw StateError('抖音关注接口命中验证码/风控响应');
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException catch (error) {
      CoreLog.error(error);
      throw StateError('抖音关注接口返回了非 JSON 响应');
    }
    if (decoded is! Map) {
      throw StateError('抖音关注接口返回了非对象 JSON');
    }
    return Map<String, dynamic>.from(decoded);
  }

  /// 解析当前登录账号的 sec_uid(真源三级降级:profile/self →
  /// query/user → follow 页 HTML 的 RENDER_DATA/SIGI_STATE)。
  static Future<String> _fetchDouyinSecUid(String cookie) async {
    for (final path in ['/aweme/v1/web/user/profile/self/', '/aweme/v1/web/query/user/']) {
      try {
        final json = await _signedWebGet(
          '$_webHost$path',
          cookie: cookie,
          referer: '$_webHost/',
          params: {'device_platform': 'webapp'},
        );
        final secUid = _findSecUid(json);
        if (secUid.isNotEmpty) return secUid;
      } catch (_) {
        // profile/self 被限流时继续尝试 query/user(真源同款降级注释)。
      }
    }
    try {
      final html = await HttpClient.instance.getText(
        '$_webHost/follow',
        header: {
          'User-Agent': DouyinRequestParams.kDefaultUserAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9',
          'Referer': '$_webHost/',
          'Cookie': cookie,
        },
      );
      final match = RegExp(
        r'<script[^>]+(?:id="RENDER_DATA"|id="SIGI_STATE")[^>]*>(.*?)</script>',
        dotAll: true,
      ).firstMatch(html);
      if (match != null) {
        final decoded = Uri.decodeComponent(match.group(1) ?? '');
        final htmlSecUid = _findSecUid(jsonDecode(decoded));
        if (htmlSecUid.isNotEmpty) return htmlSecUid;
      }
    } catch (_) {
      // HTML 页面也可能被风控替换为登录壳,继续走统一错误。
    }
    return '';
  }

  /// 深度遍历 JSON 找 `sec_uid`/`secUid`(真源 _findSecUid 同款:只认
  /// `MS4wLjABAAAA` 前缀,避免误取普通 uid)。
  static String _findSecUid(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        if (entry.key == 'sec_uid' || entry.key == 'secUid') {
          final text = entry.value?.toString() ?? '';
          if (text.startsWith('MS4wLjABAAAA')) return text;
        }
      }
      for (final child in value.values) {
        final found = _findSecUid(child);
        if (found.isNotEmpty) return found;
      }
    } else if (value is List) {
      for (final child in value) {
        final found = _findSecUid(child);
        if (found.isNotEmpty) return found;
      }
    }
    return '';
  }

  /// 递归收集关注用户并转离线占位房间(真源 _collectFollowingRooms 同款:
  /// 关注列表响应是深层嵌套,按「有 web_rid/room_id + nickname 的 user
  /// 节点」识别,seen 按 roomId 去重)。
  static void _collectFollowingRooms(Object? value, List<LiveRoom> rooms, Set<String> seen) {
    if (value is List) {
      for (final item in value) {
        _collectFollowingRooms(item, rooms, seen);
      }
      return;
    }
    if (value is! Map) return;

    final user = value['user'] is Map ? Map<String, dynamic>.from(value['user'] as Map) : value;
    final roomId = _firstText([
      user['web_rid'],
      user['room_id_str'],
      user['room_id'],
      user['roomId'],
      user['unique_id'],
      user['display_id'],
    ]);
    final nickname = _firstText([user['nickname'], user['nick_name']]);
    if (roomId.isNotEmpty && nickname.isNotEmpty && seen.add(roomId)) {
      final avatar = _imageUrl(user['avatar_thumb']);
      rooms.add(
        // 字段映射对齐 tool/import_zishu_data.dart:nick=uname、
        // area/typeName=category(导入占位为「关注」)、离线占位。
        LiveRoom(
          roomId: roomId,
          userId: '',
          title: nickname,
          nick: nickname,
          avatar: avatar,
          cover: avatar,
          area: '关注',
          typeName: '关注',
          watching: '',
          followers: '0',
          platform: SiteIds.douyinSite,
          link: 'https://live.douyin.com/$roomId',
          status: false,
          liveStatus: LiveStatus.offline,
        ),
      );
    }
    for (final child in value.values) {
      if (child is Map || child is List) _collectFollowingRooms(child, rooms, seen);
    }
  }

  static String _imageUrl(Object? value) {
    final map = value is Map ? value : const <dynamic, dynamic>{};
    final list = map['url_list'];
    if (list is! List || list.isEmpty) return '';
    return _httpsUrl(list.first);
  }

  /// `//`、`http://` 图片地址统一为 HTTPS(真源 httpsDouyinUrl 同款)。
  static String _httpsUrl(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return '';
    if (value.startsWith('//')) return 'https:$value';
    if (value.startsWith('http://')) return 'https://${value.substring(7)}';
    return value;
  }

  static String _firstText(Iterable<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  /// cookie 取指定字段值(对齐 douyin_search._cookieValue)。
  static String _cookiePart(String cookie, String name) {
    for (final part in cookie.split(';')) {
      final pair = part.trim().split('=');
      if (pair.length >= 2 && pair.first == name) return pair.skip(1).join('=');
    }
    return '';
  }

  /// verify_fp 兜底生成(真源 _buildVerifyFp 同款格式)。
  static String _buildVerifyFp() {
    final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final random = Random.secure();
    String digits(int count) => List.generate(count, (_) => random.nextInt(10)).join();
    return 'verify_${stamp}_${digits(8)}_${digits(4)}_${digits(4)}_${digits(4)}_${digits(12)}';
  }

  static int _asInt(Object? value) => int.tryParse(value?.toString().trim() ?? '') ?? 0;

  static bool _asBool(Object? value) {
    if (value is bool) return value;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'true' || text == '1';
  }
}
