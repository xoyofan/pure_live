import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:pure_live/core/common/request_scope.dart';
import 'package:pure_live/core/interface/live_search.dart';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/modules/search/search_capability.dart';
import 'package:pure_live/modules/search/search_ranking.dart';
import 'package:url_launcher/url_launcher.dart';

const Duration liveSearchRequestTimeout = Duration(seconds: 12);
const int maxConsecutiveStagnantSearchPages = 2;
const int maxConcurrentNativeSearchSites = 12;

class SearchController extends GetxController {
  SearchController({List<Site>? searchSites, this.requestTimeout = liveSearchRequestTimeout})
    : sites = List<Site>.unmodifiable(searchSites ?? Sites().availableSites()) {
    if (requestTimeout <= Duration.zero) throw ArgumentError.value(requestTimeout, 'requestTimeout');
    scrollController.addListener(_handleSearchScroll);
  }

  /// A stable platform snapshot for the lifetime of this page.
  ///
  /// Rebuilding [Sites.availableSites] creates new adapter instances. Keeping
  /// one snapshot prevents the tab labels, selected index and paginated
  /// adapter state (notably Twitch cursors) from drifting apart mid-search.
  final List<Site> sites;
  final Duration requestTimeout;
  CancelToken? _searchCancel;
  bool _closed = false;
  bool get _active => !_closed && !isClosed;
  bool _isCurrent(int generation) => _active && generation == _searchGeneration;

  void _invalidateSearch({bool retireInitialTask = true}) {
    _searchGeneration++;
    _searchCancel?.cancel();
    _searchCancel = null;
    if (retireInitialTask) {
      _initialSearchKey = null;
      _initialSearchTask = null;
    }
  }

  var index = 0.obs;
  final results = <LiveRoom>[].obs;
  final loading = false.obs;
  final loadingMore = false.obs;
  final pendingSiteCount = 0.obs;
  final hasMore = false.obs;
  final searched = false.obs;
  final errorMessage = ''.obs;
  final includeOffline = true.obs;
  final sortMode = LiveSearchSortMode.smart.obs;
  final ScrollController scrollController = createPureLiveScrollController();
  bool _isWebView2Available = true;
  bool _webView2DialogOpen = false;
  int _searchGeneration = 0;
  int _currentPage = 0;
  String _activeKeyword = '';
  ({int platformIndex, String keyword})? _initialSearchKey;
  Future<void>? _initialSearchTask;
  final Map<String, LiveRoom> _rawResults = {};
  final Map<String, bool> _hasMoreByPlatform = {};
  final Map<String, int> _stagnantPagesByPlatform = {};
  final List<Worker> _audienceWorkers = [];
  void selectPlatform(int requestedIndex) {
    if (!_active) return;
    final selectedIndex = requestedIndex.clamp(0, sites.length).toInt();
    if (selectedIndex == index.v) return;
    _invalidateSearch();
    index.value = selectedIndex;
    if (!searched.v) return;
    if (searchController.text.trim().isNotEmpty) {
      doSearch();
      return;
    }
    // An empty draft must not leave old-platform results under a new tab.
    _activeKeyword = '';
    _currentPage = 0;
    _rawResults.clear();
    _hasMoreByPlatform.clear();
    _stagnantPagesByPlatform.clear();
    results.clear();
    // 主播档新增字段随切站一并清空(只加能力:房间档行为不变);空词下
    // direct 本就为 null(仅 onQueryChanged 写入),无需额外处理。
    _anchorSeen.clear();
    _anchorHasMoreByPlatform.clear();
    anchors.clear();
    loading.v = false;
    loadingMore.v = false;
    pendingSiteCount.v = 0;
    hasMore.v = false;
    searched.v = false;
    errorMessage.v = '';
  }

  void _handleSearchScroll() {
    if (!scrollController.hasClients || scrollController.position.extentAfter > 480) return;
    loadMore();
  }

  TextEditingController searchController = TextEditingController();
  String buildSearchUrl(String platform, String keyword) {
    final q = Uri.encodeComponent(keyword);
    switch (platform) {
      case Sites.weiboSite:
        throw StateError('Weibo supports exact broadcast lookup, not web keyword search');
      case Sites.niconicoSite:
        return 'https://live.nicovideo.jp/search?keyword=$q&status=onair';
      case Sites.showroomSite:
        throw StateError('SHOWROOM web keyword search is not exposed');
      case Sites.xiaohongshuSite:
        throw StateError('Xiaohongshu supports exact broadcast-room lookup, not web keyword search');
      case Sites.kilakilaSite:
        return 'https://live.kilakila.cn/aboutus/serach/kw/$q';
      case Sites.inkeSite:
        throw StateError('Inke supports exact UID lookup, not web keyword search');
      case Sites.missevanSite:
        throw StateError('Missevan uses native keyword search, not web search');
      case Sites.ccSite:
        return "https://cc.163.com/search/all/?query=$q&only=all";
      case Sites.kuaishouSite:
        return "https://live.kuaishou.com/search?keyword=$q";
      case Sites.huyaSite:
        return "https://www.huya.com/search?hsk=$q";
      case Sites.bilibiliSite:
        return "https://search.bilibili.com/live?keyword=$q&from_source=webtop_search&spm_id_from=444.7&search_source=3";
      case Sites.douyuSite:
        return "https://www.douyu.com/search?kw=$q&dyshid=0-ed88b042da9bbc4cf4abc97500021601";
      case Sites.douyinSite:
        return "https://www.douyin.com/search/$q?type=live";
      case Sites.twitchSite:
        return "https://www.twitch.tv/search?term=$q";
      case Sites.soopSite:
        return "https://www.sooplive.co.kr/?szKeyword=$q";
      case Sites.yySite:
        return "https://www.yy.com/search-$q";
      case Sites.picartoSite:
        return 'https://picarto.tv/search?q=$q';
      case Sites.twitcastingSite:
        return 'https://twitcasting.tv/search/text/?tw_search_query=$q';
      case Sites.acfunSite:
        return 'https://www.acfun.cn/search?keyword=$q&type=user';
      default:
        return "https://www.baidu.com/s?wd=$q&rsv_spt=1&rsv_iqid=0x84b83a1e077a0c1a&issp=1&f=8&rsv_bp=1&rsv_idx=2&ie=utf-8&tn=baiduhome_pg&rsv_dl=tb_click&rsv_enter=1&rsv_sug3=3&rsv_sug1=2&rsv_sug7=100&rsv_btype=i&prefixsug=12&rsp=0&inputT=1112&rsv_sug4=1287";
    }
  }

  /// 判断是否安装了 WebView2
  Future<bool> isWebView2Installed() async {
    if (!Platform.isWindows) return true;

    try {
      var result64 = await Process.run('reg', [
        'query',
        r'HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
        '/v',
        'pv',
      ]);

      var resultUser = await Process.run('reg', [
        'query',
        r'HKEY_CURRENT_USER\Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
        '/v',
        'pv',
      ]);

      if ((result64.exitCode == 0 && result64.stdout.toString().contains('REG_SZ')) ||
          (resultUser.exitCode == 0 && resultUser.stdout.toString().contains('REG_SZ'))) {
        return true;
      }
    } catch (e) {
      debugPrint("检测 WebView2 失败: $e");
    }
    return false;
  }

  Future<void> doSearch() {
    if (!_active) return Future<void>.value();
    final keyword = searchController.text.trim();
    if (keyword.isEmpty) {
      ToastUtil.show(i18n("please_input_keyword"));
      return Future<void>.value();
    }

    final key = (platformIndex: index.v, keyword: keyword);
    final inFlight = _initialSearchTask;
    // Enter and the toolbar action can dispatch in the same frame. Preserve
    // the useful request (including a partially completed all-site search)
    // instead of cancelling it and issuing an identical network fan-out.
    if (inFlight != null && _initialSearchKey == key) return inFlight;

    late final Future<void> task;
    task = _startSearch(keyword).whenComplete(() {
      if (!identical(_initialSearchTask, task)) return;
      _initialSearchKey = null;
      _initialSearchTask = null;
    });
    _initialSearchKey = key;
    _initialSearchTask = task;
    return task;
  }

  Future<void> _startSearch(String keyword) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (scrollController.hasClients) scrollController.jumpTo(0);
    _invalidateSearch(retireInitialTask: false);
    final generation = _searchGeneration;
    _searchCancel = CancelToken();
    _activeKeyword = keyword;
    _currentPage = 0;
    loading.v = true;
    loadingMore.v = false;
    pendingSiteCount.v = 0;
    hasMore.v = false;
    searched.v = true;
    errorMessage.v = '';
    _rawResults.clear();
    _hasMoreByPlatform.clear();
    _stagnantPagesByPlatform.clear();
    results.clear();
    // 主播档状态同步清空(两档互斥渲染,新搜不留另一档残留;真源 setType
    // 「结果列表随之整体切换,不残留另一档行」同口径)。
    anchors.clear();
    _anchorSeen.clear();
    _anchorHasMoreByPlatform.clear();

    // 档位分发:主播档走 searchAnchors 并行管线,房间档保持既有管线不动。
    if (searchType.v == SearchType.anchors) {
      await _anchorSearchPage(keyword: keyword, page: 1, generation: generation, append: false);
    } else {
      await _searchPage(keyword: keyword, page: 1, generation: generation, append: false);
    }
  }

  Future<void> loadMore() async {
    if (!_active || loading.v || loadingMore.v || !hasMore.v || _activeKeyword.isEmpty) return;
    final generation = _searchGeneration;
    // 主播档分页:page/pageSize 与房间档同口径(每站单页,翻页追加)。
    if (searchType.v == SearchType.anchors) {
      loadingMore.v = true;
      await _anchorSearchPage(keyword: _activeKeyword, page: _currentPage + 1, generation: generation, append: true);
      return;
    }
    loadingMore.v = true;
    await _searchPage(keyword: _activeKeyword, page: _currentPage + 1, generation: generation, append: true);
  }

  Future<void> _searchPage({
    required String keyword,
    required int page,
    required int generation,
    required bool append,
  }) async {
    final selectedSites = index.v == 0 ? sites : (index.v <= sites.length ? [sites[index.v - 1]] : <Site>[]);
    if (!append) {
      for (final site in selectedSites) {
        final capability = LiveSearchCapabilities.forPlatform(site.id);
        _hasMoreByPlatform[site.id] = capability.supportsNativeSearch;
        _stagnantPagesByPlatform[site.id] = 0;
      }
    }
    final searchableSites = selectedSites.where((site) {
      final capability = LiveSearchCapabilities.forPlatform(site.id);
      return capability.supportsNativeSearch && (!append || (_hasMoreByPlatform[site.id] ?? true));
    }).toList();

    if (searchableSites.isEmpty) {
      if (!_isCurrent(generation)) return;
      if (selectedSites.length == 1 &&
          !LiveSearchCapabilities.forPlatform(selectedSites.single.id).supportsNativeSearch) {
        final capability = LiveSearchCapabilities.forPlatform(selectedSites.single.id);
        errorMessage.v = i18n(
          capability.supportsWebSearch ? 'search_web_only_platform' : 'search_coverage_unavailable',
          args: {'site': selectedSites.single.name},
        );
      }
      _applyFiltersAndSort();
      hasMore.v = false;
      loading.v = false;
      loadingMore.v = false;
      pendingSiteCount.v = 0;
      return;
    }

    pendingSiteCount.v = searchableSites.length;
    final failures = <String>[];
    var completed = 0;
    final cancel = _searchCancel!;
    final batchStream = _searchSitesBounded(searchableSites, keyword, page, cancel);

    // Render completed platforms immediately instead of holding the whole
    // result grid behind the slowest network request.
    await for (final batch in batchStream) {
      // Drain cancelled batches as well, so this operation settles after all
      // cancellation-aware provider futures; never write a retired generation.
      if (!_isCurrent(generation)) continue;
      final capability = LiveSearchCapabilities.forPlatform(batch.site.id);
      final beforeCount = _rawResults.length;
      for (final room in batch.rooms) {
        _rawResults[_roomKey(room)] = room;
      }
      final addedCount = _rawResults.length - beforeCount;
      if (batch.failed) failures.add(batch.site.name);
      _hasMoreByPlatform[batch.site.id] = _canLoadAnotherPage(
        site: batch.site,
        keyword: keyword,
        capability: capability,
        batch: batch,
        addedCount: addedCount,
      );
      completed++;
      pendingSiteCount.v = searchableSites.length - completed;
      _applyFiltersAndSort();
      if (results.isNotEmpty || completed == searchableSites.length) {
        loading.v = false;
      }
    }

    if (!_isCurrent(generation)) return;
    _currentPage = page;
    hasMore.v = selectedSites.any((site) => _hasMoreByPlatform[site.id] ?? false);
    if (failures.isNotEmpty) {
      errorMessage.v = i18n('search_partial_failure', args: {'sites': failures.join('、')});
    } else {
      errorMessage.v = '';
    }
    loading.v = false;
    loadingMore.v = false;
    pendingSiteCount.v = 0;
  }

  Stream<_SiteSearchBatch> _searchSitesBounded(
    List<Site> searchableSites,
    String keyword,
    int page,
    CancelToken cancel,
  ) async* {
    final active = <int, Future<_SiteSearchBatch>>{};
    var next = 0;

    void fillSlots() {
      while (!cancel.isCancelled && active.length < maxConcurrentNativeSearchSites && next < searchableSites.length) {
        final index = next++;
        active[index] = _searchSite(searchableSites[index], keyword, page, cancel);
      }
    }

    fillSlots();
    while (active.isNotEmpty) {
      final completed = await Future.any(
        active.entries.map((entry) => entry.value.then((batch) => (index: entry.key, batch: batch))),
      );
      active.remove(completed.index);
      yield completed.batch;
      // Retired searches drain started requests but never open queued sites.
      fillSlots();
    }
  }

  bool _canLoadAnotherPage({
    required Site site,
    required String keyword,
    required LiveSearchCapability capability,
    required _SiteSearchBatch batch,
    required int addedCount,
  }) {
    if (!capability.supportsPagination ||
        (site.liveSite is LiveSearchPaginationPolicy &&
            !(site.liveSite as LiveSearchPaginationPolicy).supportsSearchPaginationFor(keyword)) ||
        batch.failed ||
        batch.rooms.isEmpty) {
      _stagnantPagesByPlatform.remove(site.id);
      return false;
    }
    if (addedCount > 0) {
      _stagnantPagesByPlatform[site.id] = 0;
      return true;
    }

    // Search endpoints commonly overlap their page boundary by one response.
    // Preserve a bounded chance to reach the next unique page, while stopping
    // sticky endpoints that repeat the same payload forever.
    final stagnantPages = (_stagnantPagesByPlatform[site.id] ?? 0) + 1;
    _stagnantPagesByPlatform[site.id] = stagnantPages;
    return stagnantPages < maxConsecutiveStagnantSearchPages;
  }

  Future<_SiteSearchBatch> _searchSite(Site site, String keyword, int page, CancelToken cancel) async {
    try {
      final rooms = await withRequestCancellation(cancel, (transport) async {
        if (transport.isCancelled) throw transport.cancelError!;
        var expired = false;
        final timer = Timer(requestTimeout, () {
          expired = true;
          transport.cancel();
        });
        try {
          final work = site.liveSite.searchRoomsWithCancellation(keyword, page: page, pageSize: 20, cancel: transport);
          // Legacy APIs have no transport cancellation contract. Stop waiting
          // for them without claiming their underlying HTTP has been stopped.
          final result = site.liveSite is LiveCancellableSearch
              ? await work
              : await Future.any<List<LiveRoom>>([
                  work,
                  transport.whenCancel.then<List<LiveRoom>>((_) => throw transport.cancelError!),
                ]);
          if (transport.isCancelled) throw transport.cancelError!;
          return result;
        } catch (_) {
          if (expired && !cancel.isCancelled) throw TimeoutException('Native search deadline', requestTimeout);
          rethrow;
        } finally {
          timer.cancel();
        }
      });
      return _SiteSearchBatch(site: site, rooms: rooms);
    } catch (error) {
      if (!cancel.isCancelled) debugPrint('Native search failed for ${site.id}: $error');
      return _SiteSearchBatch(site: site, rooms: const [], failed: true);
    }
  }

  String _roomKey(LiveRoom room) {
    final platform = room.platform?.trim().toLowerCase() ?? 'unknown';
    final roomId = room.roomId?.trim() ?? '';
    if (roomId.isNotEmpty) return '$platform:$roomId';
    return '$platform:${room.nick?.trim()}:${room.title?.trim()}';
  }

  bool get hasFilteredOfflineResults => _rawResults.isNotEmpty && results.isEmpty && !includeOffline.v;

  void _applyFiltersAndSort() {
    if (!_active) return;
    final platformOrder = sites.map((site) => site.id).toList();
    results.assignAll(
      LiveSearchRanking.apply(
        rooms: _rawResults.values,
        mode: sortMode.v,
        includeOffline: includeOffline.v,
        platformOrder: platformOrder,
        audienceCompare: _compareAudience,
      ),
    );
  }

  void setIncludeOffline(bool value) {
    if (!_active) return;
    includeOffline.v = value;
    _applyFiltersAndSort();
  }

  void setSortMode(LiveSearchSortMode value) {
    if (!_active) return;
    sortMode.v = value;
    _applyFiltersAndSort();
  }

  // ============================================================
  // 主播档(锚点搜索)与直达识别 —— zishu 搜索弹窗新增能力(只加不改):
  // searchType 默认 rooms,搜索页(kSearch 路由)不触碰这些字段,
  // 既有 doSearch / loadMore / selectPlatform 对房间档的行为完全不变。
  // ============================================================

  /// searchAnchors 有真实实现的站点(2026-10-01 逐站核对 lib/core/site/*):
  /// - 独立主播搜索 API:bilibili(:786)/ douyu(:619)/ huya(:930)/ yy(:749);
  /// - 由各自 searchRooms 派生:cc(:380)/ acfun(:113);
  /// - douyin(:886)覆盖但直接抛「暂不支持」;kuaishou(:580)/ twitch(:936)/
  ///   iptv(:356)覆盖但恒返回空 —— 均按不支持计(数据诚实,不空挂主播档)。
  /// interface 默认实现(live_site.dart:218)返回空表,即未覆盖站一律不支持。
  static const Set<String> anchorSearchSites = {
    Sites.bilibiliSite,
    Sites.douyuSite,
    Sites.huyaSite,
    Sites.yySite,
    Sites.ccSite,
    Sites.acfunSite,
  };

  /// 主播档每页条数:与房间档 searchRoomsWithCancellation 的 pageSize:20 同口径。
  static const int _kAnchorPageSize = 20;

  /// 直达识别正则,逐字照真源 zishu search_provider.dart:18/21:
  /// `^\d+$` 纯数字 → 房间号;`douyu\.com/(\d+)` 同时命中
  /// www.douyu.com/{id} 与 live.douyu.com/{id} 两种直播间链接。
  static final RegExp _roomIdPattern = RegExp(r'^\d+$');
  static final RegExp _douyuLinkPattern = RegExp(r'douyu\.com/(\d+)');

  /// 直达识别(真源 search_provider.dart:236-249 同构)。真源以原始输入解析,
  /// 此处先 trim(回车场景更宽容;对 `^\d+$` 是严格放宽,不引入新语义)。
  static DirectTarget? resolveSearchDirect(String input) {
    final keyword = input.trim();
    if (keyword.isEmpty) return null;
    if (_roomIdPattern.hasMatch(keyword)) {
      return DirectTarget(kind: DirectKind.room, roomId: keyword);
    }
    final match = _douyuLinkPattern.firstMatch(keyword);
    if (match != null) {
      return DirectTarget(kind: DirectKind.link, roomId: match.group(1)!, url: keyword);
    }
    return null;
  }

  /// 当前档位(默认 rooms:搜索页无档位 UI,既有语义不变)。
  final searchType = SearchType.rooms.obs;

  /// 主播档命中(带平台归属;LiveAnchorItem 无 platform 字段,全平台聚合时
  /// 无法反查,真源 SearchHitItem 同口径)。
  final anchors = <SearchAnchorHit>[].obs;

  /// 直达项:输入实时解析(见 [onQueryChanged]),与搜索动作解耦。
  final direct = Rxn<DirectTarget>();

  /// 主播档去重(platform:roomId)与各站翻页余量,生命周期同房间档各 Map。
  final Set<String> _anchorSeen = {};
  final Map<String, bool> _anchorHasMoreByPlatform = {};

  /// 当前选中项是否可用主播档(index 0 = 全平台:任一站可用即可)。
  bool supportsAnchorSearchAt(int platformIndex) {
    bool capable(Site site) => anchorSearchSites.contains(site.id.toLowerCase());
    if (platformIndex == 0) return sites.any(capable);
    if (platformIndex < 0 || platformIndex > sites.length) return false;
    return capable(sites[platformIndex - 1]);
  }

  /// 房间档结果是否对应当前输入(Enter「进首个结果」防陈旧结果误导航)。
  bool get hasFreshRoomResults =>
      searched.v &&
      searchType.v == SearchType.rooms &&
      _activeKeyword == searchController.text.trim() &&
      results.isNotEmpty;

  /// 主播档结果是否对应当前输入(同上,主播档口径)。
  bool get hasFreshAnchorResults =>
      searched.v &&
      searchType.v == SearchType.anchors &&
      _activeKeyword == searchController.text.trim() &&
      anchors.isNotEmpty;

  /// 输入实时变化入口(真源 setQuery 的直达解析部分):只解析直达项,
  /// 不触发搜索 —— 本仓搜索仍由回车/按钮驱动,为既有语义。
  void onQueryChanged(String text) {
    if (!_active) return;
    direct.value = resolveSearchDirect(text);
  }

  /// 清空输入并回到未搜索空态(真源 setQuery('') 空词立即回空态同口径,
  /// 供输入行清空钮使用)。
  void clearDraft() {
    if (!_active) return;
    _invalidateSearch();
    searchController.clear();
    direct.value = null;
    _activeKeyword = '';
    _currentPage = 0;
    _rawResults.clear();
    _hasMoreByPlatform.clear();
    _stagnantPagesByPlatform.clear();
    _anchorSeen.clear();
    _anchorHasMoreByPlatform.clear();
    results.clear();
    anchors.clear();
    loading.v = false;
    loadingMore.v = false;
    pendingSiteCount.v = 0;
    hasMore.v = false;
    searched.v = false;
    errorMessage.v = '';
  }

  /// 切换档位(真源 SearchController.setType 语义):现有关键词按新档重查;
  /// 未搜索/空词时清两档结果回空态 —— 但**保留已输入草稿与直达解析**
  /// (真源切档不清输入,清输入是独立动作,见 clearDraft)。
  void setType(SearchType value) {
    if (!_active || value == searchType.v) return;
    _invalidateSearch();
    searchType.value = value;
    if (searched.v && searchController.text.trim().isNotEmpty) {
      doSearch();
      return;
    }
    _activeKeyword = '';
    _currentPage = 0;
    _rawResults.clear();
    _hasMoreByPlatform.clear();
    _stagnantPagesByPlatform.clear();
    _anchorSeen.clear();
    _anchorHasMoreByPlatform.clear();
    results.clear();
    anchors.clear();
    loading.v = false;
    loadingMore.v = false;
    pendingSiteCount.v = 0;
    hasMore.v = false;
    searched.v = false;
    errorMessage.v = '';
  }

  /// 主播档单页:并行打各已实现站的 searchAnchors(page/pageSize 同房间档),
  /// 结果按站点完成顺序追加(交错拼接),分站失败隔离进 errorMessage ——
  /// 全部照既有房间档 _searchPage 管线口径。
  Future<void> _anchorSearchPage({
    required String keyword,
    required int page,
    required int generation,
    required bool append,
  }) async {
    final selectedSites = index.v == 0 ? sites : (index.v <= sites.length ? [sites[index.v - 1]] : <Site>[]);
    if (!append) {
      for (final site in selectedSites) {
        _anchorHasMoreByPlatform[site.id] = anchorSearchSites.contains(site.id.toLowerCase());
      }
    }
    final anchorSites = selectedSites
        .where(
          (site) =>
              anchorSearchSites.contains(site.id.toLowerCase()) &&
              (!append || (_anchorHasMoreByPlatform[site.id] ?? true)),
        )
        .toList();

    if (anchorSites.isEmpty) {
      if (!_isCurrent(generation)) return;
      // 单选了不支持主播档的站:UI 层按能力位隐藏主播档,这里是切站竞态兜底;
      // 文案无 i18n key(记录),语义对齐真源 search_view.dart:198。
      if (selectedSites.length == 1 && !anchorSearchSites.contains(selectedSites.single.id.toLowerCase())) {
        errorMessage.v = '「${selectedSites.single.name}」暂不支持主播搜索';
      }
      hasMore.v = false;
      loading.v = false;
      loadingMore.v = false;
      pendingSiteCount.v = 0;
      return;
    }

    pendingSiteCount.v = anchorSites.length;
    final failures = <String>[];
    var completed = 0;
    final cancel = _searchCancel!;
    final batchStream = _anchorSitesBounded(anchorSites, keyword, page, cancel);

    // 与房间档一致:站点完成即渲染,不等最慢的请求。
    await for (final batch in batchStream) {
      if (!_isCurrent(generation)) continue;
      for (final anchor in batch.anchors) {
        // 站内按 roomId 去重(翻页边界常有一条重叠,照房间档去重口径)。
        if (_anchorSeen.add('${batch.site.id}:${anchor.roomId}')) {
          anchors.add(SearchAnchorHit(site: batch.site, anchor: anchor));
        }
      }
      if (batch.failed) failures.add(batch.site.name);
      // 翻页余量:满页才认为可能有下一页(数据诚实,不虚标「加载更多」)。
      _anchorHasMoreByPlatform[batch.site.id] = !batch.failed && batch.anchors.length >= _kAnchorPageSize;
      completed++;
      pendingSiteCount.v = anchorSites.length - completed;
      if (anchors.isNotEmpty || completed == anchorSites.length) {
        loading.v = false;
      }
    }

    if (!_isCurrent(generation)) return;
    _currentPage = page;
    hasMore.v = anchorSites.any((site) => _anchorHasMoreByPlatform[site.id] ?? false);
    if (failures.isNotEmpty) {
      errorMessage.v = i18n('search_partial_failure', args: {'sites': failures.join('、')});
    } else {
      errorMessage.v = '';
    }
    loading.v = false;
    loadingMore.v = false;
    pendingSiteCount.v = 0;
  }

  /// 有界并发站点流:与房间档 _searchSitesBounded 同构(并发上限共用
  /// maxConcurrentNativeSearchSites),单站调用换成 searchAnchors。
  Stream<_SiteAnchorBatch> _anchorSitesBounded(
    List<Site> anchorSites,
    String keyword,
    int page,
    CancelToken cancel,
  ) async* {
    final active = <int, Future<_SiteAnchorBatch>>{};
    var next = 0;

    void fillSlots() {
      while (!cancel.isCancelled && active.length < maxConcurrentNativeSearchSites && next < anchorSites.length) {
        final slot = next++;
        active[slot] = _searchAnchorSite(anchorSites[slot], keyword, page, cancel);
      }
    }

    fillSlots();
    while (active.isNotEmpty) {
      final completed = await Future.any(
        active.entries.map((entry) => entry.value.then((batch) => (slot: entry.key, batch: batch))),
      );
      active.remove(completed.slot);
      yield completed.batch;
      // 已废弃代次的查询只排水已发出请求,不再排队后续站点。
      fillSlots();
    }
  }

  /// 单站主播搜索:searchAnchors 无 LiveCancellableSearch 取消契约,照房间档
  /// legacy 口径用 transport.whenCancel 竞速 + 同一 requestTimeout 兜底。
  Future<_SiteAnchorBatch> _searchAnchorSite(Site site, String keyword, int page, CancelToken cancel) async {
    try {
      final anchors = await withRequestCancellation(cancel, (transport) async {
        if (transport.isCancelled) throw transport.cancelError!;
        var expired = false;
        final timer = Timer(requestTimeout, () {
          expired = true;
          transport.cancel();
        });
        try {
          final result = await Future.any<List<LiveAnchorItem>>([
            site.liveSite.searchAnchors(keyword, page: page, pageSize: _kAnchorPageSize),
            transport.whenCancel.then<List<LiveAnchorItem>>((_) => throw transport.cancelError!),
          ]);
          if (transport.isCancelled) throw transport.cancelError!;
          return result;
        } catch (_) {
          if (expired && !cancel.isCancelled) throw TimeoutException('Anchor search deadline', requestTimeout);
          rethrow;
        } finally {
          timer.cancel();
        }
      });
      return _SiteAnchorBatch(site: site, anchors: anchors);
    } catch (error) {
      if (!cancel.isCancelled) debugPrint('Anchor search failed for ${site.id}: $error');
      return _SiteAnchorBatch(site: site, anchors: const [], failed: true);
    }
  }

  String get capabilityText {
    if (index.v > 0 && index.v <= sites.length) {
      final site = sites[index.v - 1];
      final capability = LiveSearchCapabilities.forPlatform(site.id);
      if (site.id == Sites.acfunSite) return i18n('search_coverage_acfun');
      if (site.id == Sites.weiboSite) return i18n('search_coverage_weibo');
      if (site.id == Sites.kilakilaSite) return i18n('search_coverage_kilakila');
      return switch (capability.coverage) {
        NativeSearchCoverage.roomLookup => i18n('search_coverage_room_lookup', args: {'site': site.name}),
        NativeSearchCoverage.showcaseSnapshot => i18n('search_coverage_showcase_snapshot', args: {'site': site.name}),
        NativeSearchCoverage.channelLookup => i18n('search_coverage_channel_lookup', args: {'site': site.name}),
        NativeSearchCoverage.liveAndOffline => i18n('search_coverage_live_and_offline', args: {'site': site.name}),
        NativeSearchCoverage.liveOnly => i18n('search_coverage_live_only', args: {'site': site.name}),
        NativeSearchCoverage.localChannels => i18n('search_coverage_local', args: {'site': site.name}),
        NativeSearchCoverage.webOnly => i18n('search_coverage_web_only', args: {'site': site.name}),
        NativeSearchCoverage.unavailable => i18n('search_coverage_unavailable', args: {'site': site.name}),
      };
    }

    final nativeCount = sites.where((site) => LiveSearchCapabilities.forPlatform(site.id).supportsNativeSearch).length;
    final webOnlySites = sites
        .where((site) => LiveSearchCapabilities.forPlatform(site.id).coverage == NativeSearchCoverage.webOnly)
        .map((site) => site.name)
        .join('、');
    final unavailableSites = sites
        .where((site) => LiveSearchCapabilities.forPlatform(site.id).coverage == NativeSearchCoverage.unavailable)
        .map((site) => site.name)
        .join('、');
    final summary = i18n(
      webOnlySites.isNotEmpty
          ? 'search_coverage_all'
          : (nativeCount == sites.length ? 'search_coverage_all_native' : 'search_coverage_native_partial'),
      args: {'native': '$nativeCount', 'total': '${sites.length}', 'sites': webOnlySites},
    );
    final lookupSites = sites
        .where((site) => LiveSearchCapabilities.forPlatform(site.id).coverage == NativeSearchCoverage.channelLookup)
        .map((site) => site.name)
        .join('、');
    final roomLookupSites = sites
        .where(
          (site) =>
              site.id != Sites.weiboSite &&
              LiveSearchCapabilities.forPlatform(site.id).coverage == NativeSearchCoverage.roomLookup,
        )
        .map((site) => site.name)
        .join('、');
    final snapshotSites = sites
        .where((site) => LiveSearchCapabilities.forPlatform(site.id).coverage == NativeSearchCoverage.showcaseSnapshot)
        .map((site) => site.name)
        .join('、');
    return [
      summary,
      if (unavailableSites.isNotEmpty) i18n('search_coverage_unavailable', args: {'site': unavailableSites}),
      if (lookupSites.isNotEmpty) i18n('search_coverage_channel_lookup', args: {'site': lookupSites}),
      if (roomLookupSites.isNotEmpty) i18n('search_coverage_room_lookup', args: {'site': roomLookupSites}),
      if (sites.any((site) => site.id == Sites.weiboSite)) i18n('search_coverage_weibo'),
      if (snapshotSites.isNotEmpty) i18n('search_coverage_showcase_snapshot', args: {'site': snapshotSites}),
    ].join(' ');
  }

  int _compareAudience(LiveRoom left, LiveRoom right) {
    final app = SettingsService.to.app;
    return LiveRoom.compareAudienceRanking(
      left,
      right,
      preferRealOnline: app.preferRealOnlineCounts.v,
      platformEnabled: app.isRealOnlineEnabledFor,
    );
  }

  bool get canSearchNatively {
    if (index.v == 0) {
      return sites.any((site) => LiveSearchCapabilities.forPlatform(site.id).supportsNativeSearch);
    }
    if (index.v < 0 || index.v > sites.length) return false;
    return LiveSearchCapabilities.forPlatform(sites[index.v - 1].id).supportsNativeSearch;
  }

  bool get canOpenWebSearch {
    if (index.v <= 0 || index.v > sites.length) return false;
    return LiveSearchCapabilities.forPlatform(sites[index.v - 1].id).supportsWebSearch;
  }

  Future<void> openWebSearch() async {
    if (!_active) return;
    if (index.v == 0) {
      ToastUtil.show(i18n('select_platform_for_web_search'));
      return;
    }
    if (index.v > sites.length) return;
    final site = sites[index.v - 1];
    if (!LiveSearchCapabilities.forPlatform(site.id).supportsWebSearch) {
      ToastUtil.show(i18n('search_web_unavailable', args: {'site': site.name}));
      return;
    }
    final keyword = searchController.text.trim();
    if (keyword.isEmpty) {
      ToastUtil.show(i18n('please_input_keyword'));
      return;
    }
    final url = buildSearchUrl(site.id, keyword);
    if (Platform.isLinux) {
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (_active && !opened) ToastUtil.show(i18n('external_browser_not_opened'));
      return;
    }
    if (Platform.isWindows && !_isWebView2Available) {
      showWebView2MissingDialog();
      return;
    }
    Get.toNamed(RoutePath.kWebSearch, arguments: {'url': url, 'platform': site.id});
  }

  void showWebView2MissingDialog() {
    if (!_active || _webView2DialogOpen) return;
    _webView2DialogOpen = true;
    unawaited(_showWebView2MissingDialog());
  }

  Future<void> _showWebView2MissingDialog() async {
    try {
      final openDownload = await Get.dialog<bool>(
        Builder(
          builder: (BuildContext dialogContext) => AlertDialog(
            scrollable: true,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.report_problem_rounded, color: Theme.of(dialogContext).colorScheme.error),
                const SizedBox(width: 8),
                Flexible(child: Text(i18n('webview2_missing_title'))),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(i18n('webview2_missing_content'), style: const TextStyle(height: 1.4)),
            ),
            actionsOverflowDirection: VerticalDirection.down,
            actionsOverflowButtonSpacing: 8,
            actions: [
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(i18n('cancel')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: Theme.of(dialogContext).colorScheme.primary,
                  foregroundColor: Theme.of(dialogContext).colorScheme.onPrimary,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(i18n('webview2_open_download'), textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
        barrierDismissible: false,
      );
      if (openDownload != true || !_active) return;

      final url = Uri.parse('https://developer.microsoft.com/microsoft-edge/webview2/');
      final canOpen = await canLaunchUrl(url);
      if (!_active) return;
      final opened = canOpen && await launchUrl(url, mode: LaunchMode.externalApplication);
      if (_active && !opened) ToastUtil.show(i18n('webview2_open_error'));
    } catch (error, stackTrace) {
      debugPrint('Opening the WebView2 download page failed: $error\n$stackTrace');
      if (_active) ToastUtil.show(i18n('webview2_open_error'));
    } finally {
      _webView2DialogOpen = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    _audienceWorkers.add(ever(SettingsService.to.app.preferRealOnlineCounts, (_) => _applyFiltersAndSort()));
    _audienceWorkers.add(ever(SettingsService.to.app.realOnlinePlatforms, (_) => _applyFiltersAndSort()));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_active && Platform.isWindows) {
        final available = await isWebView2Installed();
        if (!_active) return;
        _isWebView2Available = available;
        if (!_isWebView2Available) {
          showWebView2MissingDialog();
        }
      }
    });
  }

  @override
  void onClose() {
    if (_closed) return;
    _closed = true;
    _invalidateSearch();
    scrollController
      ..removeListener(_handleSearchScroll)
      ..dispose();
    searchController.dispose();
    for (final worker in _audienceWorkers) {
      worker.dispose();
    }
    super.onClose();
  }
}

class _SiteSearchBatch {
  const _SiteSearchBatch({required this.site, required this.rooms, this.failed = false});

  final Site site;
  final List<LiveRoom> rooms;
  final bool failed;
}

class _SiteAnchorBatch {
  const _SiteAnchorBatch({required this.site, required this.anchors, this.failed = false});

  final Site site;
  final List<LiveAnchorItem> anchors;
  final bool failed;
}

/// 搜索档位:主播 / 房间(真源 zishu search_provider.dart `SearchType` 同构,
/// 对齐 web SearchDialog 的 activeTab)。搜索页(kSearch 路由)无档位 UI,
/// 恒为 rooms;档位只由 zishu 搜索弹窗经 [SearchController.setType] 驱动。
enum SearchType { anchors, rooms }

/// 直达项类型(真源 DirectKind 同构):room = 纯数字房间号;link = douyu 链接。
enum DirectKind { room, link }

/// 直达目标:纯数字房间号,或 douyu.com 链接解析出的房间(真源 DirectTarget
/// 同构)。[url] 为 link 直达时的原始输入,供结果 tile 副行展示。
class DirectTarget {
  const DirectTarget({required this.kind, required this.roomId, this.url});

  final DirectKind kind;

  /// 直达房间号。
  final String roomId;

  final String? url;
}

/// 主播档命中项:携带平台归属(LiveAnchorItem 无 platform 字段,全平台聚合时
/// 无法反查;真源 SearchHitItem 同口径)。UI 用 [site] 拼角标/进房参数。
class SearchAnchorHit {
  const SearchAnchorHit({required this.site, required this.anchor});

  final Site site;
  final LiveAnchorItem anchor;
}
