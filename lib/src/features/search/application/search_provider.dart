/// 搜索应用层:平台(site)+ 关键词 → 命中列表与直达项。
/// Widget 只依赖 [SearchState] 与 live_parser 契约模型;命中数据源经
/// [searchSourceProvider] 注入(fixture / 真实解析由编译开关切换)。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_parser/live_parser.dart';

import '../../../shared/application/search_source.dart';
import '../application/search_source_provider.dart';

/// 输入防抖间隔:停顿 300ms 后才真正执行一次查询。
const Duration kSearchDebounce = Duration(milliseconds: 300);

/// 纯数字输入 → 房间号直达。
final RegExp _roomIdPattern = RegExp(r'^\d+$');

/// 含 douyu.com 的输入 → 链接直达,从链接中提取房间号。
final RegExp _douyuLinkPattern = RegExp(r'douyu\.com/(\d+)');

/// 含 niconico 观察页的输入 → 链接直达,提取节目号(`lv…`)。
final RegExp _niconicoLinkPattern = RegExp(r'live\.nicovideo\.jp/watch/(lv[1-9][0-9]{0,17})');

/// 含 17.live 直播页的输入 → 链接直达,提取房间号(语言前缀 `/en/` 等可选,
/// 与 SeventeenLiveLink.parse 同口径)。
final RegExp _seventeenLinkPattern = RegExp(
  r'17\.live/(?:[a-z]{2}(?:-[a-z]{2,4})?/)?live/([1-9][0-9]{0,11})',
  caseSensitive: false,
);

/// niconico 节目号裸输入(与 NiconicoWatch.validateProgramId 同口径)。
final RegExp _niconicoIdPattern = RegExp(r'^lv[1-9][0-9]{0,17}$');

/// TwitCasting 频道根 URL 的频道名形状(与 TwitcastingApi.channelName 同口径:
/// `c:`/`g:`/`f:`/`ig:` 前缀可选——频道页 URL 形如 `/c:tbk_1`,漏掉前缀会把
/// 整类官方/社区频道判成不可直达)。大小写不敏感,归一由解析层小写完成。
final RegExp _twitcastingChannelName = RegExp(r'^(?:(?:c|g|f|ig):)?[a-zA-Z0-9_]{1,64}$');

/// 直达项类型。
enum DirectKind { roomId, link }

/// 直达目标:纯数字房间号,或 douyu.com / niconico 链接解析出的房间。
class DirectTarget {
  const DirectTarget({required this.kind, required this.roomId, this.url});

  final DirectKind kind;

  /// 直达房间号。
  final String roomId;

  /// [DirectKind.link] 时的原始输入,用于副行展示。
  final String? url;
}

/// 命中项 UI 侧包装:携带平台归属,彻底去掉对 fixture 的反查。
///
/// [SearchHit] 契约无 site 字段,real 数据下无法靠 id 反查平台。改为在状态中
/// 显式保存 (site, hit) 对,UI 用 [site] 拼路由、用 [hit] 渲染。
class SearchHitItem {
  const SearchHitItem({required this.site, required this.hit});

  /// 命中所属平台 id。
  final String site;

  /// 真实命中数据(live_parser 契约模型)。
  final SearchHit hit;
}

/// 搜索页状态:当前平台 + 关键词 + 档位 + 命中结果 + 直达项 + 错误标记。
class SearchState {
  const SearchState({
    this.site = 'douyu',
    this.type = SearchType.rooms,
    this.query = '',
    this.searching = false,
    this.hits = const [],
    this.direct,
    this.error,
  });

  /// 当前平台 id(`all` = 全平台聚合)。
  final String site;

  /// 搜索档位:主播 / 房间(对齐 web `SearchDialog.vue` 的 `activeTab`,
  /// 默认「房间优先」同 `syncDefaultTab`)。随查询透传给解析契约
  /// `SearchRequest.type`,驱动服务端同款 `anchors|rooms` 分流。
  final SearchType type;

  /// 输入框当前关键词(未 trim,随输入实时更新)。
  final String query;

  /// 防抖等待/查询进行中(结果尚未刷新)。
  final bool searching;

  /// 命中的主播/房间列表(已携带平台归属)。
  final List<SearchHitItem> hits;

  /// 快捷直达项(房间号 / 链接),无则为 null。
  final DirectTarget? direct;

  /// 最近一次查询的错误信息(非空表示查询失败;结果保留上次,不抛到 widget)。
  final String? error;

  /// 关键词是否非空(去除首尾空白)。
  bool get hasQuery => query.trim().isNotEmpty;

  SearchState copyWith({
    String? site,
    SearchType? type,
    String? query,
    bool? searching,
    List<SearchHitItem>? hits,
    DirectTarget? direct,
    bool clearDirect = false,
    String? error,
    bool clearError = false,
  }) {
    return SearchState(
      site: site ?? this.site,
      // type 恒非空(rooms/anchors),copyWith 仅用于在两档间切换。
      type: type ?? this.type,
      query: query ?? this.query,
      searching: searching ?? this.searching,
      hits: hits ?? this.hits,
      direct: clearDirect ? null : (direct ?? this.direct),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 搜索控制器:持有 query 与结果;输入防抖 300ms,
/// 以 generation fence 保证只有最新一次查询能写入状态。
class SearchController extends Notifier<SearchState> {
  int _generation = 0;
  late final SearchSource _source;

  @override
  SearchState build() {
    _source = ref.watch(searchSourceProvider);
    return const SearchState();
  }

  /// 切换平台,并按当前关键词重新查询(仍走防抖)。
  ///
  /// 同时把档位重置回「房间」默认档 —— 对齐 web 切站时的
  /// `syncDefaultTab`(SearchDialog.vue:268)。
  void setSite(String site) {
    if (site == state.site) return;
    state = state.copyWith(site: site, type: SearchType.rooms, clearError: true);
    _scheduleSearch();
  }

  /// 切换搜索档位(主播 / 房间),并按当前关键词以新档位重新查询。
  ///
  /// 对齐 web `onTabChange`:web 切档会清空输入重查;这里保留输入、
  /// 直接以现有关键词换档重查(结果列表随之整体切换,不残留另一档行)。
  void setType(SearchType type) {
    if (type == state.type) return;
    state = state.copyWith(type: type, clearError: true);
    _scheduleSearch();
  }

  /// 关键词实时变更入口(由输入框 onChanged 触发)。
  void setQuery(String query) {
    state = state.copyWith(query: query, clearError: true);
    _scheduleSearch();
  }

  /// 防抖调度:每次变更使上一代查询失效。
  void _scheduleSearch() {
    final generation = ++_generation;
    final keyword = state.query.trim();
    if (keyword.isEmpty) {
      // 清空输入:立即回到空态,同时令未完成的查询全部过期。
      state = state.copyWith(searching: false, hits: const [], clearDirect: true, clearError: true);
      return;
    }
    state = state.copyWith(searching: true, clearError: true);
    Future<void>.delayed(kSearchDebounce, () {
      // generation fence:期间有新输入/切平台,则丢弃本次过期查询。
      if (!ref.mounted || generation != _generation) return;
      _resolve(state.site, keyword, generation);
    });
  }

  /// 异步查询并写入状态;保留防抖与 generation fence。
  Future<void> _resolve(String site, String keyword, int generation) async {
    final type = state.type;
    try {
      final hits = await _searchAttributed(site, keyword, type);
      // generation fence:期间有新输入/切平台/切档,则丢弃本次结果。
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(searching: false, hits: hits, direct: _resolveDirect(site, keyword), clearError: true);
    } on Object catch (e) {
      // 查询失败:保留上次结果与输入,仅标记 error;不抛到 widget、不整页空白。
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(searching: false, error: _errorMessage(e));
    }
  }

  /// 调用数据源并携带平台归属:[site] 为单站时整批归属该站;
  /// `all` 时并发聚合 [ParserSearchSource.aggregateSites],各站命中归属各自平台。
  ///
  /// [type] 档位随查询透传(主播/房间),实现 UI 双档取数分流。
  ///
  /// 单站失败直接向上抛出(由 [_resolve] 统一以 [SearchState.error] 表达,
  /// 不整页空白、不抛到 widget);仅 `all` 聚合模式下才逐站隔离失败。
  Future<List<SearchHitItem>> _searchAttributed(String site, String keyword, SearchType type) async {
    if (site == 'all') {
      final results = await Future.wait([
        for (final s in _source.aggregateSites) _searchSiteIsolated(s, keyword, type),
      ]);
      return results.expand((items) => items).toList(growable: false);
    }
    final hits = await _source.search(site: site, keyword: keyword, type: type);
    return [for (final hit in hits) SearchHitItem(site: site, hit: hit)];
  }

  /// 单站隔离查询(仅用于 `all` 聚合):失败返回空,该站本轮空缺,
  /// 不影响其余平台结果,整页不空白。
  Future<List<SearchHitItem>> _searchSiteIsolated(String site, String keyword, SearchType type) async {
    try {
      final hits = await _source.search(site: site, keyword: keyword, type: type);
      return [for (final hit in hits) SearchHitItem(site: site, hit: hit)];
    } on Object {
      return const [];
    }
  }

  String _errorMessage(Object e) => e is StateError ? e.message : e.toString();

  /// 直达识别:见顶层 [resolveSearchDirect]。
  DirectTarget? _resolveDirect(String site, String keyword) => resolveSearchDirect(site, keyword);
}

/// 直达识别(纯函数):纯数字 → 房间号;含 douyu.com / niconico 观察页 /
/// 17.live 直播页 → 链接直达;TwitCasting 频道根 URL → 频道直达(电影/回放
/// 链接不识别,与 pure_live「不静默替换旧场次」口径一致);选定 niconico
/// 平台时 `lv…` 裸节目号 → 房间号直达(全站模式下不识别,避免普通搜索词误判)。
DirectTarget? resolveSearchDirect(String site, String keyword) {
  if (_roomIdPattern.hasMatch(keyword)) {
    return DirectTarget(kind: DirectKind.roomId, roomId: keyword);
  }
  final niconicoId = _niconicoIdPattern.firstMatch(keyword);
  if (niconicoId != null && site == 'niconico') {
    return DirectTarget(kind: DirectKind.roomId, roomId: keyword);
  }
  final douyu = _douyuLinkPattern.firstMatch(keyword);
  if (douyu != null) {
    return DirectTarget(kind: DirectKind.link, roomId: douyu.group(1)!, url: keyword);
  }
  final niconico = _niconicoLinkPattern.firstMatch(keyword);
  if (niconico != null) {
    return DirectTarget(kind: DirectKind.link, roomId: niconico.group(1)!, url: keyword);
  }
  final seventeen = _seventeenLinkPattern.firstMatch(keyword);
  if (seventeen != null) {
    return DirectTarget(kind: DirectKind.link, roomId: seventeen.group(1)!, url: keyword);
  }
  final twitcasting = _twitcastingChannelRoot(keyword);
  if (twitcasting != null) {
    return DirectTarget(kind: DirectKind.link, roomId: twitcasting, url: keyword);
  }
  return null;
}

/// TwitCasting 频道根 URL → 频道名(与 TwitcastingApi.channelFromUri 同口径:
/// host 白名单 + 单段 path + 频道名形状;movie/archive 多段路径返回 null)。
String? _twitcastingChannelRoot(String keyword) {
  final uri = Uri.tryParse(keyword.trim());
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return null;
  if (!{'twitcasting.tv', 'www.twitcasting.tv'}.contains(uri.host.toLowerCase())) return null;
  final segments = [
    for (final segment in uri.pathSegments)
      if (segment.isNotEmpty) segment,
  ];
  if (segments.length != 1 || !_twitcastingChannelName.hasMatch(segments.single)) return null;
  return segments.single;
}

/// 搜索页全局 provider(keep-alive:返回搜索页保留上次输入与结果)。
final searchProvider = NotifierProvider<SearchController, SearchState>(SearchController.new);
