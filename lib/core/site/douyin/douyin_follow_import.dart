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
import 'package:pure_live/core/common/site_ids.dart';
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
abstract interface class DouyinFollowImporter {
  /// 拉取当前登录账号的全部关注并转为离线占位房间。
  Future<List<LiveRoom>> importFollowing({void Function(DouyinFollowImportProgress progress)? onProgress});

  /// 登录 cookie 是否就绪(无 cookie 时 UI 置灰导入按钮)。
  bool get hasFollowImportCookie;
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
