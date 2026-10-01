/// Pure Live 解析桥:把 `lib/core` 的 LiveSite 实现包装成 live_parser
/// 的 [SiteRegistration],供 zishu UI 经统一契约消费。
///
/// 与 live_parser 自带平台实现并存:注册时按 id 覆盖(bilibili/douyin/
/// huya/douyu),`--dart-define=PURE_LIVE_PARSER=true` 启用。
///
/// 设计要点:
/// * 站点实例经 `Sites.supportSites`(lib/core/sites.dart)单源获取,
///   cookie 注入沿用 `ParserConfig`(app 侧 binding 已接线);
/// * 播放地址**不**在 resolveRoom 预取 —— 直播地址短时效,流地址由
///   播放内核经 [PureLiveStreamSource] 在取流时解析(见 zishu 播放内核
///   的 stream-source 约定);因此 [PureLiveRoomResolver] 返回的
///   streams 为空、availableQualities 为实际档位。
library;

import 'package:live_parser/live_parser.dart' hide LiveSite;
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/site/bilibili/bilibili_site.dart';
import 'package:pure_live/core/site/douyin/douyin_site.dart';
import 'package:pure_live/core/site/douyu/douyu_site.dart';
import 'package:pure_live/core/site/huya/huya_site.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/model/live_play_quality.dart';

/// live_parser 站点 id(契约侧)→ pure_live 站点 id(lib/core 侧)。
const Map<String, String> kPureLiveSiteMap = {
  'bilibili': 'bilibili',
  'douyin': 'douyin',
  'huya': 'huya',
  'douyu': 'douyu',
};

/** 只实例化已 sidecar 化的四家 —— 不经过 lib/core/sites.dart(它会
 * 拖入全部 30+ 站点,其中未转换的站点仍带旧 UI/插件依赖链)。 */
LiveSite? _siteOf(String liveParserSite) {
  switch (liveParserSite) {
    case 'bilibili':
      return BiliBiliSite();
    case 'douyin':
      return DouyinSite();
    case 'huya':
      return HuyaSite();
    case 'douyu':
      return DouyuSite();
  }
  return null;
}

const Map<String, String> kPureLiveSiteNames = {
  'bilibili': 'BiliBili',
  'douyin': '抖音',
  'huya': '虎牙',
  'douyu': '斗鱼',
};

RoomState _stateOf(LiveRoom room) {
  switch (room.liveStatus) {
    case LiveStatus.live:
      return RoomState.live;
    case LiveStatus.replay:
      return RoomState.replay;
    default:
      return RoomState.offline;
  }
}

/// 把 pure_live LiveRoom 映射为 live_parser RoomPayload。
///
/// streams 恒为空(取流时再签,见库文档注释);画质档位单独查询。
Future<RoomPayload> _roomToPayload(LiveRoom room, String site) async {
  final coreSite = _siteOf(site)!;

  // 档位:只在开播时取,失败按无档位处理(UI 回退只读信息)。
  var qualities = const <QualityOption>[];
  if (room.liveStatus == LiveStatus.live) {
    try {
      final q = await coreSite.getPlayQualites(detail: room);
      qualities = [
        for (final item in q)
          QualityOption(name: item.quality, rate: 0),
      ];
    } catch (_) {
      qualities = const <QualityOption>[];
    }
  }

  return RoomPayload(
    site: site,
    roomId: room.roomId ?? '',
    sourceUrl: room.link ?? '',
    anchorName: room.nick ?? '',
    title: room.title ?? '',
    cover: room.cover ?? '',
    avatar: room.avatar ?? '',
    category: room.area ?? '',
    cid: '',
    roomState: _stateOf(room),
    streams: const <StreamQuality>[],
    availableQualities: qualities,
    source: 'purelive/$site',
    fetchedAt: DateTime.now(),
  );
}

/// 房间解析器:resolve/refresh/recovery 共用同一个 LiveSite 调用。
class PureLiveRoomResolver
    implements RoomResolver, RoomSummaryRefresher, RoomRecoveryResolver {
  PureLiveRoomResolver(this.site);

  final String site;

  @override
  Future<RoomPayload> resolveRoom(RoomRequest request) async {
    final coreSite = _siteOf(site)!;
    final detail =
        await coreSite.getRoomDetail(platform: site, roomId: request.roomIdOrUrl);
    return _roomToPayload(detail, site);
  }

  @override
  Future<RoomPayload> recoverRoom(RoomRequest request) => resolveRoom(request);

  @override
  Future<RoomRecord> refreshRoomSummary(RoomRequest request) async {
    final payload = await resolveRoom(request);
    return RoomRecord.fromPayload(payload);
  }
}

/// 播放地址解析:在 UI 选择画质后取流。
class PureLiveStreamSource {
  PureLiveStreamSource(this.site);

  final String site;

  Future<List<StreamLine>> linesFor(String roomId, String quality) async {
    final coreSite = _siteOf(site)!;
    final room = await coreSite.getRoomDetail(platform: site, roomId: roomId);
    final qualities = await coreSite.getPlayQualites(detail: room);
    LivePlayQuality? chosen;
    for (final item in qualities) {
      if (item.quality == quality) {
        chosen = item;
        break;
      }
    }
    chosen ??= qualities.isEmpty ? null : qualities.first;
    if (chosen == null) {
      throw StateError('pure_live backend: $site/$roomId 无可用画质');
    }
    final urls = await coreSite.getPlayUrls(detail: room, quality: chosen);
    return [
      for (var i = 0; i < urls.length; i++)
        StreamLine(
          name: '线路${i + 1}',
          format: urls[i].toLowerCase().endsWith('.m3u8') ? 'hls' : 'flv',
          url: urls[i],
          headers: const <String, String>{},
        ),
    ];
  }
}

/// 组装一个 pure_live 后端的站点注册项(browse/search/danmaku 暂不挂,
/// 后续任务按同模式增补 —— capabilities 如实声明,不占位伪装)。
SiteRegistration buildPureLiveRegistration(String liveParserSite) {
  if (_siteOf(liveParserSite) == null) {
    throw StateError('pure_live backend: 未支持的站点 "$liveParserSite"');
  }
  return SiteRegistration(
    id: liveParserSite,
    name: kPureLiveSiteNames[liveParserSite] ?? liveParserSite,
    capabilities: const SiteCapabilities(
      multiQuality: true,
      multiLine: true,
    ),
    resolver: PureLiveRoomResolver(liveParserSite),
  );
}
