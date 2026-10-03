/// Pure Live 解析桥:把 `lib/core` 的 LiveSite 实现包装成 live_parser
/// 的 [SiteRegistration],供 zishu UI 经统一契约消费。
///
/// 与 live_parser 自带平台实现并存:注册时按 id 覆盖(bilibili/douyin/
/// huya/douyu),`--dart-define=PURE_LIVE_PARSER=true` 启用。
///
/// 设计要点:
/// * 站点实例经 `Sites.supportSites` 全量表查找(全平台支持);
/// * cookie 注入沿用 `ParserConfig`(app 侧 binding 已接线);
/// * resolveRoom 返回真实 streams(选中档位全部线路)+ availableQualities;
///   播放请求头对齐 pure_live PlaybackHeaderResolver 的四家分支。
library;

import 'dart:async';

import 'package:live_parser/live_parser.dart' hide LiveSite;

import 'browse_source.dart';

import 'package:pure_live/shared/platforms/live_input_recipe.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/domains/live/data/playback_header_resolver.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/core/models/live_area.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/shared/platforms/huya/huya_site.dart' show HuyaUrlDataModel;

import 'purelive_audience.dart';
import 'purelive_line_format.dart';

/// live_parser 站点 id(契约侧)→ pure_live 站点 id(lib/core 侧)。
const Map<String, String> kPureLiveSiteMap = {
  'bilibili': 'bilibili',
  'douyin': 'douyin',
  'huya': 'huya',
  'douyu': 'douyu',
};

const Map<String, String> kPureLiveSiteNames = {'bilibili': 'BiliBili', 'douyin': '抖音', 'huya': '虎牙', 'douyu': '斗鱼'};

/// 站点实例单例表:保留 huya UA 刷新、douyu 签名缓存、douyin cookie 等
/// 站点内进程级状态(每次新建会丢缓存导致重复签名请求)。
final Map<String, LiveSite> _pureLiveSiteInstances = {};

LiveSite _siteInstanceOf(String liveParserSite) {
  return _pureLiveSiteInstances.putIfAbsent(liveParserSite, () {
    for (final site in Sites.supportSites) {
      if (site.id == liveParserSite) return site.liveSite;
    }
    throw StateError('pure_live backend: 未支持的站点 "$liveParserSite"');
  });
}

/// 播放请求头:统一委托 pure_live 的 PlaybackHeaderResolver 站点契约
/// (UA/Origin/Referer/匿名 Cookie)。此前仅四家手写分支,长尾站点只回退
/// UA;17LIVE 的 wansu CDN 强校验 Referer(UA-only 实测 403),取流经
/// 本地代理即断(2026-10-03)。
Future<Map<String, String>> _playbackHeaders(String site, String roomId) =>
    PlaybackHeaderResolver.resolve(platform: site, roomId: roomId);

/// owned-input 配方提取:仅当适配器声明「真源但无导出 URL」时返回配方,
/// 通用 URL 平台(带直链)返回 null——后者由 resolveRoom 的 streams 常规承载。
LiveInputRecipe? pureLiveOwnedRecipeOf(LivePlayUrlResolution resolution) {
  if (resolution.urls.isNotEmpty) return null;
  return resolution.inputRecipe;
}

/// owned-input 配方解析:详情 → 档位 → 按名选档(口径同 resolveRoom)→
/// 原始解析取配方。房间不可播/无档/通用 URL 平台一律返回 null(不是错误)。
Future<LiveInputRecipe?> resolvePureLiveOwnedInputRecipe(
  LiveSite coreSite, {
  required String roomIdOrUrl,
  String? preferredQuality,
}) async {
  // Dart 3.13:LiveSite 与 LivePlayUrlResolver 无子类型关系时 `is` 被判恒假
  // (提升失效),`as` 是合法的(2026-10-02 最小 repro 实测)。
  final resolver = coreSite as LivePlayUrlResolver;
  final detail = await coreSite.getRoomDetail(LiveRoom(roomId: roomIdOrUrl, platform: coreSite.id));
  if (!detail.isLiveNow) return null;
  final qualities = await coreSite.getPlayQualites(liveroom: detail);
  if (qualities.isEmpty) return null;
  var chosen = qualities.first;
  if (preferredQuality != null && preferredQuality.isNotEmpty) {
    for (final q in qualities) {
      if (q.quality == preferredQuality || '${q.selectionId}' == preferredQuality) {
        chosen = q;
        break;
      }
    }
  }
  final resolution = await resolver.resolvePlayUrlsRaw(liveroom: detail, quality: chosen);
  return pureLiveOwnedRecipeOf(resolution);
}

/// 受限直播口径的展示文案(pure_live LiveRestriction 枚举名 → 中文)。
/// "受限=仍在播,只是这个客户端看不到"(上游 4.x 统一口径);
/// 空串/未知名返回 null(不渲染,不伪造)。
String? restrictionDisplayText(String restriction) => switch (restriction) {
  'needsLogin' => '需要登录',
  'paid' => '付费直播',
  'subscribersOnly' => '订阅可见',
  'private' => '私密直播',
  'appOnly' => '仅App内可看',
  'regionBlocked' => '地区限制',
  'password' => '密码房间',
  'adult' => '成人内容',
  'unplayable' => '平台未提供播放',
  _ => null,
};

/// pure_live 撤回指令 → zishu 契约目标;非撤回消息返回 null。
DanmakuRetraction? pureliveDanmakuRetractionFrom(LiveMessage message) {
  if (message.type != LiveMessageType.retraction) return null;
  final target = message.data;
  if (target is! LiveRetraction) return null;
  if (target.all) return const DanmakuRetraction.all();
  final messageId = target.messageId ?? '';
  if (messageId.isNotEmpty) return DanmakuRetraction.message(messageId);
  return DanmakuRetraction.user(target.userId ?? '');
}

/// 平台表情编码 → 富文本段(文本段+表情图段按序)。
///
/// zishu 契约 `DanmakuSegment.emoji`(text=[编码], url=图片)由渲染层画图;
/// 编码在正文中不出现/无 url 的条目跳过。重叠匹配取先出现者,扫描从左到右。
List<DanmakuSegment> pureliveDanmakuSegmentsFromEmotes(String text, List<LiveEmote> emotes) {
  if (emotes.isEmpty || text.isEmpty) return const <DanmakuSegment>[];
  final matches = <({int start, int end, LiveEmote emote})>[];
  for (final emote in emotes) {
    if (emote.code.isEmpty || emote.url.isEmpty) continue;
    var start = text.indexOf(emote.code);
    while (start != -1) {
      matches.add((start: start, end: start + emote.code.length, emote: emote));
      start = text.indexOf(emote.code, start + emote.code.length);
    }
  }
  if (matches.isEmpty) return const <DanmakuSegment>[];
  matches.sort((a, b) => a.start.compareTo(b.start));
  final segments = <DanmakuSegment>[];
  var cursor = 0;
  for (final m in matches) {
    if (m.start < cursor) continue; // 与已消费区间重叠,跳过
    if (m.start > cursor) {
      segments.add(DanmakuSegment.text(text.substring(cursor, m.start)));
    }
    segments.add(DanmakuSegment.emoji(text: m.emote.code, url: m.emote.url, name: m.emote.code));
    cursor = m.end;
  }
  if (cursor < text.length) {
    segments.add(DanmakuSegment.text(text.substring(cursor)));
  }
  return segments;
}

RoomState _stateOf(LiveRoom room) {
  switch (room.liveStatus) {
    case LiveStatus.live:
      return RoomState.live;
    case LiveStatus.replay:
      return RoomState.replay;
    case LiveStatus.carousel:
      // 轮播房(主播不在,循环播旧视频):可播放但非实时直播,
      // 不再压成 offline——上游 4.x 把它从 offline 分离(2026-10-03)。
      return RoomState.carousel;
    default:
      return RoomState.offline;
  }
}

/// pure_live LiveRoom 能提供的统计快照(仅观看/关注;vip/svip 无数据源)。
///
/// 观看走 [audienceDisplayOf] 统一口径(legacy watching 优先,缺口回落
/// audienceValue;'0' 哨兵/'null'/空串不冒充人数);[RoomRecord] 契约
/// 「空串=未提供」在构造边界归一为 null,真实 0 保留。
RoomRecord pureliveStatsRecord(LiveRoom room, String site) {
  final audience = audienceDisplayOf(room);
  final followers = (room.followers ?? '').trim();
  return RoomRecord(
    site: site,
    roomId: room.roomId ?? '',
    roomState: _stateOf(room),
    audience: audience.isEmpty ? null : audience,
    followers: followers.isEmpty ? null : followers,
  );
}

/// 读适配器塞进 `LiveRoom.data` 的桥接暂存字段(soop cateNo / 分类 cid /
/// 虎牙 identityLabel / 斗鱼·B站 promoTag / 斗鱼 startedAtMs);缺键或空串
/// 返回 null(数据诚实:接口没有就不填,不伪造)。
String? _dataString(LiveRoom room, String key) {
  final data = room.data;
  if (data is! Map) return null;
  final value = data[key]?.toString().trim() ?? '';
  return value.isEmpty ? null : value;
}

/// 把 pure_live LiveRoom 映射为 live_parser RoomPayload(不含流)。
///
/// 分类契约(zishu live_parser 同构):LiveRoom 无分类 id 字段,适配器把
/// 详情接口的分类号塞进 `data['cid']`(B站 area_id / 斗鱼 betard cate_id /
/// 虎牙 liveData.gid,虎牙经 HuyaUrlDataModel.cid);payload.cid = 分类 id
/// → 播放页收藏星/分类跳转。soop 与抖音无二级分类 id:cid 即房间号(soop
/// 另把 CHANNEL `CATE` 填 [RoomPayload.cateNo],收藏分类优先用 cateNo)。
/// 斗鱼 `data['startedAtMs']`(betard show_time)换算 payload.startedAt,
/// 播放页元信息条显示真实开播时间。
RoomPayload pureliveRoomToPayload(
  LiveRoom room,
  String site, {
  List<StreamQuality> streams = const <StreamQuality>[],
  List<QualityOption> availableQualities = const <QualityOption>[],
  int startAtMs = 0,
}) {
  final data = room.data;
  final cateNo = data is Map ? (data['cateNo']?.toString().trim() ?? '') : '';
  final startedAtMs = data is Map ? int.tryParse(data['startedAtMs']?.toString() ?? '') : null;
  // 开播时间:上游 8 家解析直填 LiveRoom.startedAt(bilibili/douyin/twitch/
  // acfun/seventeen/showroom/inke/cc),优先直读;斗鱼遗留 startedAtMs 兜底。
  final directStartedAt = room.startedAt;
  final startedAt =
      directStartedAt ??
      (startedAtMs != null && startedAtMs > 0 ? DateTime.fromMillisecondsSinceEpoch(startedAtMs) : null);
  final bridgedCid = switch (data) {
    Map m => (m['cid']?.toString().trim() ?? ''),
    HuyaUrlDataModel h => h.cid.trim(),
    _ => '',
  };
  final cid = site == Sites.soopSite || site == Sites.douyinSite ? (room.roomId ?? '') : bridgedCid;
  return RoomPayload(
    site: site,
    roomId: room.roomId ?? '',
    sourceUrl: room.link ?? '',
    anchorName: room.nick ?? '',
    title: room.title ?? '',
    cover: room.cover ?? '',
    avatar: room.avatar ?? '',
    category: room.area ?? '',
    cid: cid,
    cateNo: cateNo,
    startedAt: startedAt,
    startAtMs: startAtMs,
    // 受限直播口径(上游 4.x):枚举名透传,空串=无限制。
    restriction: room.effectiveRestriction == LiveRestriction.none ? '' : room.effectiveRestriction.name,
    roomState: _stateOf(room),
    streams: streams,
    availableQualities: availableQualities,
    source: 'purelive/$site',
    fetchedAt: DateTime.now(),
  );
}

/// 房间解析器:resolve/refresh/recovery 共用同一个 LiveSite 调用。
/// resolve 在开播时顺带解析默认档位(或 preferredQuality 命中档)的
/// 全部线路,供 zishu 播放内核直接起播;线路切换经 preferredQuality 重解析。
class PureLiveRoomResolver implements RoomResolver, RoomSummaryRefresher, RoomRecoveryResolver {
  PureLiveRoomResolver(this.site);

  final String site;

  @override
  Future<RoomPayload> resolveRoom(RoomRequest request) async {
    final coreSite = _siteInstanceOf(site);
    final detail = await coreSite.getRoomDetail(LiveRoom(roomId: request.roomIdOrUrl, platform: site));

    // 离线/未开播:无流可给,只返回元信息。
    if (detail.liveStatus != LiveStatus.live) {
      return pureliveRoomToPayload(detail, site);
    }

    // 画质档位。
    final qualities = await coreSite.getPlayQualites(liveroom: detail);
    if (qualities.isEmpty) {
      return pureliveRoomToPayload(detail, site);
    }

    // 选档:preferredQuality 名称/ID 匹配,否则默认第一档(最高)。
    var chosen = qualities.first;
    if (request.preferredQuality != null && request.preferredQuality!.isNotEmpty) {
      for (final q in qualities) {
        if (q.quality == request.preferredQuality || '${q.selectionId}' == request.preferredQuality) {
          chosen = q;
          break;
        }
      }
    }

    // 取流:该档位下全部线路。走契约扩展 resolvePlayUrls(实现站拿 raw
    // resolution,其余站回落 getPlayUrls)——轮播房的 startAt 起播偏移
    // 只有 raw 契约携带(B 站循环稿件 play_time,2026-10-03)。
    final resolution = await coreSite.resolvePlayUrls(liveroom: detail, quality: chosen);
    final urls = resolution.urls;
    final headers = await _playbackHeaders(site, detail.roomId ?? '');
    final chosenIndex = qualities.indexOf(chosen);

    return pureliveRoomToPayload(
      detail,
      site,
      startAtMs: resolution.startAt.inMilliseconds,
      streams: [
        StreamQuality(
          name: chosen.quality,
          rate: (qualities.length - chosenIndex) * 100,
          lines: [
            for (var i = 0; i < urls.length; i++)
              StreamLine(name: '线路${i + 1}', format: pureLiveLineFormat(urls[i]), url: urls[i], headers: headers),
          ],
        ),
      ],
      availableQualities: [for (final q in qualities) QualityOption(name: q.quality, rate: 0)],
    );
  }

  @override
  Future<RoomPayload> recoverRoom(RoomRequest request) => resolveRoom(request);

  @override
  Future<RoomRecord> refreshRoomSummary(RoomRequest request) async {
    final coreSite = _siteInstanceOf(site);
    final detail = await coreSite.getRoomDetail(LiveRoom(roomId: request.roomIdOrUrl, platform: site));
    final payload = pureliveRoomToPayload(detail, site);
    // 统计快照(2026-10-02 用户口径: 直播页观看/贵宾/超粉/钻粉要解析显示):
    // pure_live LiveRoom 只有观看/粉丝测量值,vip/svip 无数据源留空
    // (数据诚实性: 不伪造);native 覆盖平台由注册层委托原生解析器补全。
    return RoomRecord.fromPayload(payload).mergeRefresh(pureliveStatsRecord(detail, site));
  }
}

/// ── 栏目浏览:分类索引 + 分类房间/推荐流 ──
///
/// fetchCategories 把 pure_live 的 LiveCategory{name, id, children[]} 映射为
/// 一级分组+二级瓦片;fetchRooms 在 cid 为空(推荐流)时走
/// getRecommendRooms,否则走 getCategoryRooms。列表条目不预取画质
/// (与 resolveRoom 同口径, 直播地址短时效)。
class PureLiveBrowseRepository implements BrowseRepository {
  PureLiveBrowseRepository(this.site);

  final String site;

  LiveSite get _coreSite => _siteInstanceOf(site);

  @override
  Future<CategoryResult> fetchCategories(String site) async {
    final categories = await _coreSite.getCategores(1, 100);
    final groups = [
      for (final category in categories)
        CategoryGroup(
          id: category.id,
          name: category.name,
          items: [
            for (final area in category.children)
              CategoryItem(cid: area.areaId ?? '', name: area.areaName ?? '', pic: area.areaPic ?? ''),
          ],
        ),
    ];
    // soop 目录/房间分类中文化:目录预热(SoopSite.getSubCategores)填充
    // 「分类号→中文名」进程表,房间条目按 broad_cate_no 反查后 area 直接
    // 是中文展示名;展示层 displayCategoryName 仍作兜底二次映射。
    return CategoryResult(site: site, groups: groups);
  }

  @override
  Future<RoomListResult> fetchRooms(RoomListRequest request) async {
    final coreSite = _siteInstanceOf(site);
    final cid = request.cid ?? '';
    final summaries = <RoomSummary>[];

    if (cid.isEmpty) {
      // 推荐流:无分类上下文,cid 留空(zishu browse._toResult 同口径)。
      final rooms = await coreSite.getRecommendRooms(page: request.page, pageSize: request.limit);
      for (final room in rooms) {
        summaries.add(pureliveBrowseSummary(room, site, cid: ''));
      }
    } else {
      // 分类房间:cid 即 LiveArea.areaId(soop 分类号)。areaName 传占位,
      // soop 房间分类名由解析层按条目 broad_cate_no 自查,不再沿用此值。
      final area = LiveArea(platform: site, areaId: cid, areaName: cid);
      final rooms = await coreSite.getCategoryRooms(area, page: request.page, pageSize: request.limit);
      for (final room in rooms) {
        summaries.add(pureliveBrowseSummary(room, site, cid: cid));
      }
    }

    return RoomListResult(
      rooms: [for (final summary in summaries) RoomRecord.fromSummary(summary)],
      page: request.page,
      hasMore: summaries.length >= request.limit,
    );
  }
}

/// 浏览列表条目 → RoomSummary:cid 用请求的分类号(卡片分类反查/我的分类
/// 判重按分类号;推荐流无分类上下文为空),category 用解析层已反查的
/// 展示名(soop 为中文,其余平台为上游原名)。identityLabel(虎牙右上
/// 身份角标)/promoTag(斗鱼·B站特色 chip)从适配器暂存提取。
RoomSummary pureliveBrowseSummary(LiveRoom room, String site, {required String cid}) {
  return RoomSummary(
    site: site,
    roomId: room.roomId ?? '',
    title: room.title ?? '',
    anchorName: room.nick ?? '',
    cid: cid,
    category: room.area ?? '',
    online: audienceDisplayOf(room),
    cover: room.cover ?? '',
    avatar: room.avatar ?? '',
    promoTag: _dataString(room, 'promoTag'),
    identityLabel: _dataString(room, 'identityLabel'),
    roomState: room.liveStatus == LiveStatus.live ? RoomState.live : RoomState.offline,
  );
}

/// ── 搜索:searchRooms → SearchResult(hits) ──
/// owned-input 配方解析源(2026-10-02 用户口径「播放策略用 purelive 的」):
/// niconico/bigo/fc2 等配方平台经 purelive 适配器取配方,座位由播放侧经
/// purelive 播放绑定开合。独立于 PureLiveRoomResolver——两类契约家族
/// (live_parser RoomResolver 与 zishu RoomSource)的 resolveRoom 签名互斥,
/// 不能同挂一个类。
class PureLiveOwnedInputResolver implements OwnedInputResolver {
  const PureLiveOwnedInputResolver();

  @override
  Future<LiveInputRecipe?> resolveOwnedInputRecipe({
    required String site,
    required String roomIdOrUrl,
    String? preferredQuality,
  }) {
    final coreSite = _siteInstanceOf(site);
    return resolvePureLiveOwnedInputRecipe(coreSite, roomIdOrUrl: roomIdOrUrl, preferredQuality: preferredQuality);
  }
}

class PureLiveSearchRepository implements SearchRepository {
  PureLiveSearchRepository(this.site);

  final String site;

  @override
  Future<SearchResult> search(SearchRequest request) async {
    final coreSite = _siteInstanceOf(site);
    final rooms = await coreSite.searchRooms(request.query, page: 1, pageSize: request.limit);
    final hits = [
      for (final room in rooms)
        SearchHit(
          id: room.roomId ?? '',
          anchor: room.nick ?? '',
          title: room.title ?? '',
          avatar: room.avatar ?? '',
          cover: room.cover ?? '',
          state: room.liveStatus == LiveStatus.live ? SearchHitState.live : SearchHitState.offline,
          category: room.area ?? '',
          online: audienceDisplayOf(room),
        ),
    ];
    return SearchResult(site: site, hits: hits);
  }
}

/// ── 弹幕:pure_live LiveDanmaku 回调 → Stream 适配 ──
class PureLiveDanmakuConnector implements DanmakuConnector {
  const PureLiveDanmakuConnector(this.site);

  final String site;

  @override
  SiteCapabilities get capabilities => const SiteCapabilities(danmaku: true);

  @override
  Future<DanmakuSession> connect(DanmakuSessionRequest request) {
    final session = _PureLiveDanmakuSession(site: site, roomId: request.roomId);
    session.start();
    return Future.value(session);
  }
}

class _PureLiveDanmakuSession implements DanmakuSession {
  _PureLiveDanmakuSession({required this.site, required this.roomId});

  /// 由连接器在注册后调用(私有构造外的唯一启动入口)。
  void start() => _start();

  final String site;
  final String roomId;

  LiveDanmaku? _danmaku;

  final StreamController<DanmakuMessage> _messages = StreamController<DanmakuMessage>.broadcast();
  final StreamController<DanmakuSessionState> _states = StreamController<DanmakuSessionState>.broadcast();

  Future<void> _start() async {
    final coreSite = _siteInstanceOf(site);
    try {
      final room = await coreSite.getRoomDetail(LiveRoom(roomId: roomId, platform: site));
      final args = room.danmakuData;
      final danmaku = coreSite.getDanmaku();
      danmaku.onMessage = (message) {
        // 全类型透传(2026-10-03 上游合并轮):此前只放行 chat,
        // bilibili 的礼物/公告/撤回/醒目留言、斗鱼礼物、虎牙下播通知
        // 全在桥上被丢弃。在线人数无 zishu 消费面,维持丢弃。
        final DanmakuMessageType? type = switch (message.type) {
          LiveMessageType.chat => DanmakuMessageType.chat,
          LiveMessageType.gift => DanmakuMessageType.gift,
          LiveMessageType.superChat => DanmakuMessageType.superChat,
          LiveMessageType.notice => DanmakuMessageType.notice,
          LiveMessageType.retraction => DanmakuMessageType.retraction,
          LiveMessageType.online => null,
        };
        if (type == null) return;
        _messages.add(
          DanmakuMessage(
            type: type,
            roomId: roomId,
            userName: message.userName,
            userId: message.userId,
            text: message.message,
            id: message.messageId,
            sentAt: message.sentAt,
            segments: pureliveDanmakuSegmentsFromEmotes(message.message, message.emotes),
            retraction: pureliveDanmakuRetractionFrom(message),
          ),
        );
      };
      danmaku.onReady = () {
        _states.add(DanmakuSessionState.connected);
      };
      danmaku.onReconnect = (msg) {
        _states.add(DanmakuSessionState.connecting);
      };
      danmaku.onClose = (msg) {
        _states.add(DanmakuSessionState.disconnected);
      };
      _danmaku = danmaku;
      _states.add(DanmakuSessionState.connecting);
      await danmaku.start(args);
    } catch (_) {
      _states.add(DanmakuSessionState.disconnected);
    }
  }

  @override
  Stream<DanmakuMessage> get messages => _messages.stream;

  @override
  Stream<DanmakuSessionState> get states => _states.stream;

  @override
  Future<void> close() async {
    _danmaku?.onMessage = null;
    _danmaku?.onReconnect = null;
    _danmaku?.onClose = null;
    _danmaku?.onReady = null;
    await _danmaku?.stop();
    _danmaku = null;
  }
}

/// 组装一个 pure_live 后端的站点注册项(browse/search/danmaku 全挂,
/// capabilities 如实声明)。由宿主 buildRegistryWithPureLive 按 id 覆盖。
SiteRegistration buildPureLiveRegistration(String liveParserSite, {RoomSummaryRefresher? nativeStatsRefresher}) {
  // _siteInstanceOf 对未支持站点直接抛 StateError,此处无需判空。
  _siteInstanceOf(liveParserSite);
  return SiteRegistration(
    id: liveParserSite,
    name: kPureLiveSiteNames[liveParserSite] ?? liveParserSite,
    capabilities: const SiteCapabilities(
      browse: true,
      roomSearch: true,
      danmaku: true,
      multiQuality: true,
      multiLine: true,
    ),
    resolver: nativeStatsRefresher == null
        ? PureLiveRoomResolver(liveParserSite)
        : _NativeStatsPureLiveResolver(liveParserSite, nativeStatsRefresher),
    browse: PureLiveBrowseRepository(liveParserSite),
    search: PureLiveSearchRepository(liveParserSite),
    danmaku: PureLiveDanmakuConnector(liveParserSite),
  );
}

/// 播放/线路/弹幕走 pure_live,统计刷新委托 native 解析器(2026-10-02
/// 用户口径: 直播页观看/贵宾/超粉/钻粉要解析显示;pure_live 适配层没有
/// vip/svip 数据源,而 native 解析器自带实测过的完整统计快照链)。
class _NativeStatsPureLiveResolver extends PureLiveRoomResolver {
  _NativeStatsPureLiveResolver(super.site, this._statsRefresher);

  final RoomSummaryRefresher _statsRefresher;

  @override
  Future<RoomRecord> refreshRoomSummary(RoomRequest request) => _statsRefresher.refreshRoomSummary(request);
}
