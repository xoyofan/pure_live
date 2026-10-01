/// 房间 VIP/SVIP 统计接口:侧栏信息头第三行(贵宾/超粉·大航海·会员)数据源。
///
/// 口径逐站对齐 zishu 真源(packages/live_parser 各站 `refreshRoomSummary`):
/// - douyu(getAnchorNewCard 资料卡,真源 douyu_site.dart:83-93):一次请求,
///   vip = `roomInfo.functionShow.giftCard.total`、svip =
///   `anchorLevel.dFansInfo.curDfansNum`(与粉丝数同一张卡,零额外网络)。
/// - huya(真源 huya_site.dart:121-151):profileRoom 取 presenterUid
///   (`profileInfo.uid ?? liveData.uid`)与 channelId(`liveData.liveChannel ??
///   liveData.channel ?? uid`),仅在播时走 wup:贵宾 = `liveui/getVipBarList`
///   的 iTotalNum,超粉 = `wupui/getSuperFansInfo`+`getSuperFansRankPanel`
///   并发、置信度校验通过者(协议封装见 core/site/huya/huya_vip_wup.dart)。
/// - bilibili(真源 bilibili_site.dart:116-130):大航海 = `guardTab/topList`
///   的 `data.info.num`,仅在播(live_status==1)且 uid>0 时取;**真 0 合法**
///   (formatExactCountOrZero 口径),只有取不到才空;uid 取我们 getInfoByRoom
///   的 `room_info.uid`。vip 列 web 真源本就为空(粉丝勋章 web 侧不提供),
///   不伪造。
/// - douyin(真源 douyin_site.dart:37-58 + room_api.dart:559-626):enter 响应
///   取 owner/内部房间号,status==2 时打带 a_bogus 签名的 `/webcast/user/profile/`,
///   vip = `fans_club.total_fans_count`、svip = `subscribe_info.member_count`
///   (数值优先、「1.2万」类文本兜底,均还原为完整数字)。
///
/// 数据诚实性:任何失败(超时/网络/结构不符/site 不在四平台)返回
/// `const RoomVipStats()`,null 字段由侧栏渲染「—」,不造假数据;数值格式化
/// 照抄真源 `formatExactCount`(完整数字,0/非法为空)与
/// `formatExactCountOrZero`(B 站大航海保留真 0)。
///
/// 性能:`site:roomId` 内存缓存 TTL 60s(侧栏重建不重复打请求),只缓存
/// 「取数链路完整走完」的结果(字段全空也可能是上游口径下确实没有);
/// 失败不入缓存,下一次重建可重试;并发调用共享同一在途 Future。整体单次
/// 10s 超时。
library;

import 'dart:async';
import 'dart:convert';

import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/parser_config.dart';
import 'package:pure_live/core/common/site_ids.dart';
import 'package:pure_live/core/site/bilibili/bilibili_site.dart';
import 'package:pure_live/core/site/douyin/douyin_site.dart';
import 'package:pure_live/core/site/douyu/douyu_utils.dart';
import 'package:pure_live/core/site/huya/huya_request_params.dart';
import 'package:pure_live/core/site/huya/huya_vip_wup.dart';
import 'package:pure_live/core/utils/douyin/douyin_utils.dart';

/// 单房间 VIP/SVIP 统计快照;null 字段 = 未取到,展示层渲染「—」。
class RoomVipStats {
  const RoomVipStats({this.vip, this.svip});

  final String? vip;
  final String? svip;
}

final Map<String, ({DateTime at, RoomVipStats stats})> _vipStatsCache = {};
final Map<String, Future<RoomVipStats>> _vipStatsInFlight = {};
const Duration _vipStatsTtl = Duration(seconds: 60);

/// 取房间 VIP/SVIP 统计(侧栏信息头第三行契约,签名与侧栏轨逐字一致)。
///
/// [site] 取 SiteIds 值(douyu/huya/bilibili/douyin);其余平台直接返回空。
/// 整体 10s 超时,任何失败返回 `const RoomVipStats()`,不抛错不打断侧栏。
Future<RoomVipStats> fetchRoomVipStats({required String site, required String roomId}) async {
  final normalizedSite = site.trim().toLowerCase();
  final normalizedRoomId = roomId.trim();
  final supported = switch (normalizedSite) {
    SiteIds.douyuSite || SiteIds.huyaSite || SiteIds.bilibiliSite || SiteIds.douyinSite => true,
    _ => false,
  };
  if (!supported || normalizedRoomId.isEmpty) return const RoomVipStats();

  final key = '$normalizedSite:$normalizedRoomId';
  final now = DateTime.now();
  final cached = _vipStatsCache[key];
  if (cached != null && now.difference(cached.at) < _vipStatsTtl) {
    return cached.stats;
  }
  final pending = _vipStatsInFlight[key];
  if (pending != null) return pending;

  final future = _fetchVipStatsWithTimeout(normalizedSite, normalizedRoomId);
  _vipStatsInFlight[key] = future;
  try {
    final stats = await future;
    _pruneVipStatsCache(now);
    _vipStatsCache[key] = (at: DateTime.now(), stats: stats);
    return stats;
  } finally {
    if (identical(_vipStatsInFlight[key], future)) _vipStatsInFlight.remove(key);
  }
}

void _pruneVipStatsCache(DateTime now) {
  if (_vipStatsCache.length < 256) return;
  _vipStatsCache.removeWhere((_, entry) => now.difference(entry.at) >= _vipStatsTtl);
  // 极端刷房场景下缓存仍膨胀则整体清空:缓存只防重建重复打请求,清空仅退回
  // 多请求一次,不影响正确性。
  if (_vipStatsCache.length >= 256) _vipStatsCache.clear();
}

Future<RoomVipStats> _fetchVipStatsWithTimeout(String site, String roomId) async {
  try {
    final future = switch (site) {
      SiteIds.douyuSite => _fetchDouyuVipStats(roomId),
      SiteIds.huyaSite => _fetchHuyaVipStats(roomId),
      SiteIds.bilibiliSite => _fetchBilibiliVipStats(roomId),
      _ => _fetchDouyinVipStats(roomId),
    };
    return await future.timeout(const Duration(seconds: 10));
  } catch (_) {
    // 超时/网络/结构异常一律空快照:null 字段 → 「—」,不冒充有效数值。
    return const RoomVipStats();
  }
}

// ---------------------------------------------------------------------------
// douyu:getAnchorNewCard 资料卡(真源 room_api.dart:212-233 fetchDouyuAnchorCard)
// ---------------------------------------------------------------------------

Future<RoomVipStats> _fetchDouyuVipStats(String roomId) async {
  // app 内斗鱼 roomId 均为数字 rid;别名串不回源 HTML 解析(与统计轻量口径一致)。
  if (int.tryParse(roomId) == null) return const RoomVipStats();
  // 真源为 GET ?rid=&client_sys=web(参数/头照抄 fetchDouyuAnchorCard),请求基建
  // 复用仓库 DouyuUtils.requestHeaders(referer 按房间对齐真源)。
  final payload = await HttpClient.instance.getJson(
    'https://www.douyu.com/wgapi/livenc/liveweb/getAnchorNewCard',
    queryParameters: {'rid': roomId, 'client_sys': 'web'},
    header: DouyuUtils.requestHeaders(roomId),
  );
  // 真源不校验业务码:资料卡缺失/风控(非 JSON 由 dio 抛错)→ 字段取空。
  final data = _mapOf(payload is Map ? payload['data'] : null);
  final giftCard = _mapOf(_mapOf(data['functionShow'])['giftCard']);
  final dFansInfo = _mapOf(_mapOf(data['anchorLevel'])['dFansInfo']);
  return RoomVipStats(vip: _formatExactCount(giftCard['total']), svip: _formatExactCount(dFansInfo['curDfansNum']));
}

// ---------------------------------------------------------------------------
// huya:profileRoom 取身份 → wup 贵宾/超粉(真源 huya_site.dart:121-151)
// ---------------------------------------------------------------------------

Future<RoomVipStats> _fetchHuyaVipStats(String roomId) async {
  if (int.tryParse(roomId) == null) return const RoomVipStats();
  final profileText = await HttpClient.instance.getText(
    'https://mp.huya.com/cache.php',
    queryParameters: {'m': 'Live', 'do': 'profileRoom', 'roomid': roomId, 'showSecret': 1},
    // 头与仓库 huya_site 的 profileRoom 调用同源(HuyaRequestParams UA),匿名即可,
    // 不挂账号 cookie:统计与关注状态完全分离(真源同口径)。
    header: {
      'Origin': 'https://www.huya.com',
      'Referer': 'https://www.huya.com/',
      'user-agent': HuyaRequestParams.kUserAgent,
    },
  );
  final decoded = jsonDecode(profileText);
  final data = _mapOf(decoded is Map ? decoded['data'] : null);
  final profileInfo = _mapOf(data['profileInfo']);
  final liveData = _mapOf(data['liveData']);
  // 在播门槛:liveStatus == 'ON'(真源 HuyaRoomState.live 的轻量近似;录播循环
  // 需二次页面探测,统计链路不做,代价仅为个别回放房间多一次 wup 查询)。
  final isLive = data['liveStatus']?.toString().trim().toUpperCase() == 'ON';
  final presenterUid = _firstPositiveInt([profileInfo['uid'], liveData['uid']]);
  final channelId = _firstPositiveInt([liveData['liveChannel'], liveData['channel']]);
  if (!isLive || presenterUid <= 0) return const RoomVipStats();
  // channelId 缺失回退 presenterUid(真源 wupChannelId 同口径);两个 wup 并发。
  final wupChannelId = channelId > 0 ? channelId : presenterUid;
  final (vipCount, superFanCount) = await (
    fetchHuyaVipBarCount(presenterUid: presenterUid, channelId: wupChannelId),
    fetchHuyaSuperFanCount(presenterUid: presenterUid, channelId: wupChannelId),
  ).wait;
  return RoomVipStats(
    // 贵宾:>0 才展示(真源 vipCount > 0 门槛)。
    vip: vipCount != null && vipCount > 0 ? '$vipCount' : null,
    // 超粉:完整数字,0/不可信留空(formatExactCount 口径)。
    svip: _formatExactCount(superFanCount),
  );
}

// ---------------------------------------------------------------------------
// bilibili:getInfoByRoom 取 uid → guardTab/topList 大航海(真源
// bilibili_site.dart:116-130 + room_api.dart:150-182 fetchBilibiliGuardTotal)
// ---------------------------------------------------------------------------

Future<RoomVipStats> _fetchBilibiliVipStats(String roomId) async {
  final site = BiliBiliSite();
  final roomInfo = await site.getRoomInfo(roomId: roomId);
  final roomMeta = _mapOf(roomInfo['room_info']);
  final anchorUid = _firstPositiveInt([roomMeta['uid']]);
  // 大航海门槛:仅 live_status==1 在播(真源 fetchBilibiliGuardTotal 同门槛)。
  final isLive = _asInt(roomMeta['live_status']) == 1;
  if (!isLive || anchorUid <= 0) return const RoomVipStats();
  const guardUrl = 'https://api.live.bilibili.com/xlive/app-room/v2/guardTab/topList';
  // 参数对齐真源(roomid/ruid/page/page_size),经仓库 getWbiSign 签名
  // (真源 bilibiliFetchJson 对带参请求同样做 WBI 签名)。
  final signed = await site.getWbiSign('$guardUrl?roomid=$roomId&ruid=$anchorUid&page=1&page_size=50');
  final result = await HttpClient.instance.getJson(guardUrl, queryParameters: signed, header: await site.getHeader());
  final data = _mapOf(result is Map ? result['data'] : null);
  final info = _mapOf(data['info']);
  // 风控响应没有 info.num(实测返回 {"error":-1}):缺失 = 没取到 → null,
  // 不把「没取到」说成「一个大航海都没有」(真源 containsKey('num') 同判断)。
  if (!info.containsKey('num')) return const RoomVipStats();
  return RoomVipStats(svip: _formatExactCountOrZero(info['num']));
}

// ---------------------------------------------------------------------------
// douyin:enter 取 owner/内部房间号 → 带签名 /webcast/user/profile/(真源
// douyin_site.dart:37-58 + room_api.dart:517-626)
// ---------------------------------------------------------------------------

Future<RoomVipStats> _fetchDouyinVipStats(String webRid) async {
  final site = DouyinSite();
  // ① enter:与仓库 getRoomDetailByWebRidApi 同一条 buildRequestUrl 签名链,
  //    响应里取房间内部号与 owner 主键(真源 fetchDouyinWebStreamData 同源)。
  final enterUrl = DouyinUtils.buildRequestUrl('https://live.douyin.com/webcast/room/web/enter/', {
    'app_name': 'douyin_web',
    'enter_from': 'web_live',
    'live_id': '1',
    'web_rid': webRid,
    'is_need_double_stream': 'false',
  });
  final enter = await HttpClient.instance.getJson(enterUrl, header: await site.getRequestHeaders());
  final enterData = _mapOf(enter is Map ? enter['data'] : null);
  final roomList = enterData['data'];
  final room = roomList is List && roomList.isNotEmpty ? _mapOf(roomList.first) : const <String, dynamic>{};
  // 在播门槛:status == 2(真源 fetchDouyinAudienceExtras 的 status==2 门槛;
  // 4=未开播,其余在播,但资料卡只认 2)。
  if (_asInt(room['status']) != 2) return const RoomVipStats();
  final owner = _mapOf(room['owner']);
  final anchorId = '${owner['id_str'] ?? ''}'.trim();
  final secUid = '${owner['sec_uid'] ?? ''}'.trim();
  final internalRoomId = '${room['id_str'] ?? room['id'] ?? ''}'.trim();
  if (anchorId.isEmpty || internalRoomId.isEmpty) return const RoomVipStats();
  // ② 主播资料卡:msToken 优先取账号 cookie 真值(仓库 douyin_search 同口径),
  //    缺省由 buildRequestUrl 随机补;风控/非 JSON 重试一次(真源 signedDouyinGet
  //    同构,重签时 a_bogus/msToken 随时间刷新)。
  final cookie = (ParserConfig.instance?.cookieFor(SiteIds.douyinSite) ?? '').trim();
  final cookieMsToken = _cookieValue(cookie, 'msToken');
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      final profileUrl = DouyinUtils.buildRequestUrl('https://live.douyin.com/webcast/user/profile/', {
        'aid': '6383',
        'app_name': 'douyin_web',
        'live_id': '1',
        'device_platform': 'web',
        'anchor_id': anchorId,
        'sec_anchor_id': secUid,
        'room_id': internalRoomId,
        'target_uid': anchorId,
        'user_id': anchorId,
        'sec_user_id': secUid,
        if (cookieMsToken.isNotEmpty) 'msToken': cookieMsToken,
      });
      final headers = await site.getRequestHeaders()
        ..['Referer'] = 'https://live.douyin.com/$webRid';
      final body = await HttpClient.instance.getText(profileUrl, header: headers);
      final trimmed = body.trim();
      if (trimmed.isEmpty || trimmed.startsWith('<!DOCTYPE') || trimmed.startsWith('<html')) {
        throw const FormatException('抖音资料卡触发风控');
      }
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map || _asInt(decoded['status_code']) != 0) {
        throw StateError('抖音资料卡 status_code 异常');
      }
      final profile = _mapOf(_mapOf(decoded['data'])['user_profile']);
      final fansClub = _mapOf(profile['fans_club']);
      final subscribe = _mapOf(profile['subscribe_info']);
      return RoomVipStats(
        vip: _douyinProfileCount(fansClub['total_fans_count'], fansClub['total_fans_count_str']),
        svip: _douyinProfileCount(subscribe['member_count'], subscribe['member_count_str']),
      );
    } catch (_) {
      if (attempt == 1) return const RoomVipStats();
    }
  }
  return const RoomVipStats();
}

// ---------------------------------------------------------------------------
// 格式化与取值小工具(逐条照抄真源 utils/format_online.dart 等实现)
// ---------------------------------------------------------------------------

/// 真源 formatExactCount:完整数字不做万/千省略;0/非法返回 null(留空)。
String? _formatExactCount(Object? count) {
  final value = count is num ? count : num.tryParse('${count ?? ''}'.trim());
  if (value == null || value <= 0) return null;
  return value.truncate().toString();
}

/// 真源 formatExactCountOrZero:保留真 0(「上游确实报告一个都没有」);
/// 只有不可解析/负数才为 null。B 站大航海用。
String? _formatExactCountOrZero(Object? count) {
  final value = count is num ? count : num.tryParse('${count ?? ''}'.trim());
  if (value == null || value < 0) return null;
  if (value == 0) return '0';
  return value.truncate().toString();
}

/// 真源 tryParseOnlineCount:把「1.2万 / 3.4千 / 1234」还原为整数;
/// 空/不可解析返回 null(合法 0 保留)。
int? _parseOnlineCount(Object? count) {
  final text = '${count ?? ''}'.trim().replaceAll(',', '');
  if (text.isEmpty) return null;
  final match = RegExp(r'^([\d.]+)\s*([万千wk]?)$').firstMatch(text.toLowerCase());
  if (match == null) return null;
  final value = double.tryParse(match.group(1)!);
  if (value == null) return null;
  return switch (match.group(2)) {
    '万' || 'w' => (value * 10000).round(),
    '千' || 'k' => (value * 1000).round(),
    _ => value.round(),
  };
}

/// 真源 _douyinProfileCount(web pickProfileCount 口径):数值优先,缺失时
/// 还原「1.2万」类字符串;0/缺失一律 null(不落伪造 0)。
String? _douyinProfileCount(Object? raw, Object? text) {
  final numeric = _parseOnlineCount(raw);
  if (numeric != null && numeric > 0) return _formatExactCount(numeric);
  final cleaned = '${text ?? ''}'.replaceFirst(RegExp(r'人$'), '').replaceAll('+', '').trim();
  final fromText = _parseOnlineCount(cleaned);
  return fromText != null && fromText > 0 ? _formatExactCount(fromText) : null;
}

/// 取第一个可解析且 >0 的整数(uid/liveChannel 等主键类字段,0 视为缺失);
/// 真源 huya_site.dart _firstPositiveInt 同口径(num 原生类型一并兼容)。
int _firstPositiveInt(List<Object?> values) {
  for (final value in values) {
    final parsed = value is num ? value.toInt() : int.tryParse('${value ?? ''}'.trim());
    if (parsed != null && parsed > 0) return parsed;
  }
  return 0;
}

int _asInt(Object? value) => value is num ? value.toInt() : int.tryParse('${value ?? ''}'.trim()) ?? 0;

Map<String, dynamic> _mapOf(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

/// 从 cookie 串取指定字段值(仓库 douyin_search.dart _cookieValue 同口径)。
String _cookieValue(String cookie, String name) {
  for (final part in cookie.split(';')) {
    final index = part.indexOf('=');
    if (index <= 0) continue;
    if (part.substring(0, index).trim() == name) {
      return part.substring(index + 1).trim();
    }
  }
  return '';
}
