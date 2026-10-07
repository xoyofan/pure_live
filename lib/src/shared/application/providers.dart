/// 全局 providers:数据源端口注入。G1 接线时把 fixture 换成
/// DirectLiveParserGateway 实现,Widget 与 controller 不变。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/user/application/platform_credentials_provider.dart';
import 'browse_source.dart';
import 'fixture_sources.dart';

import 'package:live_parser/live_parser.dart' show buildSiteRegistry;
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/core/network/parser_config.dart' show ParserConfig;
import 'package:pure_live/core/network/site_ids.dart' show SiteIds;
import 'package:pure_live/src/shared/application/zishu_parser_config.dart' show ZishuParserConfig;

import 'parser_sources.dart';
import 'purelive_backend.dart';

import 'package:live_parser/live_parser.dart' show RoomSummaryRefresher, SiteRegistry;

/// 通过 `--dart-define=ZISHU_REAL_PARSER=true` 启用真实 live_parser。
/// 默认 fixture，避免 widget 测试和离线开发依赖公网。
const bool useRealParser = bool.fromEnvironment('ZISHU_REAL_PARSER', defaultValue: true);

/// 用 pure_live 解析(lib/core LiveSite)覆盖 live_parser 自带的四家
/// (bilibili/douyin/huya/douyu)。注册项按 id 覆盖,UI 契约不变。
const bool usePureLiveBackend = bool.fromEnvironment('PURE_LIVE_PARSER', defaultValue: true);

/// 带覆盖的 registry 构建:PURE_LIVE_PARSER 时在标准 registry 上重注册
/// purelive 后端的全部平台(Sites.supportSites 每一个, 排除 all)。
SiteRegistry buildRegistryWithPureLive({String douyinCookie = '', String xhsCookie = '', String bilibiliCookie = ''}) {
  final registry = buildSiteRegistry(douyinCookie: douyinCookie, xhsCookie: xhsCookie, bilibiliCookie: bilibiliCookie);
  if (usePureLiveBackend) {
    for (final site in Sites.supportSites) {
      if (site.id == Sites.allSite) continue;
      // 统计刷新委托:native 解析器自带实测过的观看/贵宾/超粉/钻粉快照
      // (pure_live 适配层无 vip/svip 数据源),播放/线路仍走 purelive。
      final native = registry.byId(site.id);
      final nativeResolver = native?.resolver;
      final nativeStats = nativeResolver is RoomSummaryRefresher ? nativeResolver : null;
      // native browse 保留名单:pure_live 适配层无该目录(YouTube 实测恒空)
      // 或卡片信息密度远低于 zishu 原生实现(douyu/twitch——native browse
      // 产出 RoomSummary.chips 特色标签行/identityLabel 榜单角标/promoTag,
      // 上游适配器只有骨架字段)的站点,保留 native browse(2026-10-07 用户
      // 口径「参考 zishu 原来的代码」);播放/统计/解析仍走 purelive。
      const nativeBrowseSites = {Sites.youtubeSite, Sites.douyuSite, Sites.twitchSite};
      final nativeBrowse = nativeBrowseSites.contains(site.id) ? native?.browse : null;
      registry.register(
        buildPureLiveRegistration(site.id, nativeStatsRefresher: nativeStats, browseOverride: nativeBrowse),
      );
    }
  }
  return registry;
}

/// 栏目浏览数据源(首页/分类/搜索底卡)。
final browseSourceProvider = Provider<BrowseSource>((ref) {
  if (!useRealParser) return const FixtureBrowseSource();
  final douyinCookie = ref.watch(platformCredentialsProvider.select((state) => state.credentialFor('douyin').value));
  final xhsCookie = ref.watch(platformCredentialsProvider.select((state) => state.credentialFor('xhs').value));
  final bilibiliCookie = ref.watch(
    platformCredentialsProvider.select((state) => state.credentialFor('bilibili').value),
  );
  // zishu 运行时把用户凭证接进 pure_live 解析核心(ParserConfig): 旧 UI 的
  // bindParserRuntimeToApp 不跑, 不注入则 bilibili 等适配器匿名(-352 风控)。
  ParserConfig.instance = ZishuParserConfig({SiteIds.bilibiliSite: bilibiliCookie, SiteIds.douyinSite: douyinCookie});
  return ParserBrowseSource(
    douyinCookie: douyinCookie,
    xhsCookie: xhsCookie,
    bilibiliCookie: bilibiliCookie,
    registry: buildRegistryWithPureLive(
      douyinCookie: douyinCookie,
      xhsCookie: xhsCookie,
      bilibiliCookie: bilibiliCookie,
    ),
  );
});

/// owned-input 播放配方解析源(niconico 等配方平台):fixture 源不具备 →
/// null,播放页据此回落「无线路」路径。见 [OwnedInputResolver]。
final ownedInputProvider = Provider<OwnedInputResolver?>((ref) {
  if (!useRealParser) return null;
  return const PureLiveOwnedInputResolver();
});

/// 房间解析数据源(播放页)。
final roomSourceProvider = Provider<RoomSource>((ref) {
  if (!useRealParser) return const FixtureRoomSource();
  final douyinCookie = ref.watch(platformCredentialsProvider.select((state) => state.credentialFor('douyin').value));
  final xhsCookie = ref.watch(platformCredentialsProvider.select((state) => state.credentialFor('xhs').value));
  // B 站登录 Cookie(凭证页粘贴,含 SESSDATA):解锁低清晰度档 ——
  // 匿名请求 qn=80/150 都被服务器强制回落 250 超清(2026-09-29 实测),
  // 劣化网络下超清码率(~312KB/s)超出可用带宽会反复 stall。
  final bilibiliCookie = ref.watch(
    platformCredentialsProvider.select((state) => state.credentialFor('bilibili').value),
  );
  return ParserRoomSource(
    douyinCookie: douyinCookie,
    xhsCookie: xhsCookie,
    bilibiliCookie: bilibiliCookie,
    registry: buildRegistryWithPureLive(
      douyinCookie: douyinCookie,
      xhsCookie: xhsCookie,
      bilibiliCookie: bilibiliCookie,
    ),
  );
});

/// 房间状态刷新能力:真实解析源实现 [RoomRefresher] 时暴露;
/// fixture 源不实现 → null,关注列表保持「样例数据、零网络」的既有行为
/// (定时轮询件也据此不建 timer)。
final roomRefresherProvider = Provider<RoomRefresher?>((ref) {
  final source = ref.watch(roomSourceProvider);
  return source is RoomRefresher ? source : null;
});

/// 关注直播批量快照源;当前由真实解析源按平台能力提供。
final followLiveRefresherProvider = Provider<FollowLiveRefresher?>((ref) {
  final source = ref.watch(roomSourceProvider);
  if (source is FollowLiveRefresher) {
    return source as FollowLiveRefresher;
  }
  return null;
});

/// 平台关注列表导入源;真实解析源按平台能力提供。
final followImportSourceProvider = Provider<FollowImportSource?>((ref) {
  final source = ref.watch(roomSourceProvider);
  if (source is FollowImportSource) return source as FollowImportSource;
  return null;
});
