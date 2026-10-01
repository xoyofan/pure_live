// zishu 播放页侧栏「推荐」tab 编排:GetX 版跨平台交错推荐流。
//
// 真源基准(逐段精读后移植):zishu_flutter
// `lib/src/features/play/application/play_recommend_provider.dart`(571 行,
// 真源自述对齐 SFVideoLive web 的 `usePlayRecommend`);取数与合并规则逐条
// 复刻,状态容器按 pure_live 惯例从 Riverpod 换成 GetX:
// - [RecommendStreamController](GetxController)+ Rx 字段,面板 `Obx` 直读;
// - 站点固定序 [kRecommendSiteOrder] ∩ `Sites.isSupported`:douyu → huya →
//   bilibili → douyin → soop(顺序即展示权重,交错时排前者先出现;soop 的
//   `SoopSite.getRecommendRooms`/`getCategoryRooms` 均已实现,入列,
//   见 lib/core/site/soop/soop_site.dart:214/329);
// - 每站每轮按 [kRecommendPerSite] 条取数,按站点桶**交错**合并(真源
//   :127-153 `interleaveRecommendBuckets` 逐行移植):第 i 轮各站各出一条,
//   前几屏就是多平台混合而不是被单站占满;
// - 分类:当前房间分类名先经跨平台归一(`findCrossCategory`,
//   lib/zishu/domain/category_display.dart),再把归一后的分类定位到各站
//   `LiveArea`(cid 直连优先,名称精确 → 双向包含,真源 mapRecommendCid
//   :91-115 口径);分类流空 → 该站回落热门流并记一次兜底(据此出提示);
//   该站整体失败 → 本站本轮留空,不拖垮别人(真源 :537-540);
// - 分页:各站页号一起递增,滚动触底触发;某站连续空页按
//   [kRecommendEmptyPageRetries] 重试(真源 loadMore :365-374 语义);
// - 展示前统一过滤:只留在播(`LiveRoom.isLiveNow`,真源 roomState == live
//   同义)、剔除当前房间、按 `platform:roomId`(`LiveRoom.identityKey`,
//   live_room.dart:539)去重 —— 剔除发生在每轮取数合并后的交错阶段
//   (真源同款,:147);
// - 综合兜底:有分类上下文却一条都没取到 → 退「全站热门」并提示
//   [kRecommendMixedFallbackHint](真源 loadFirst :320-325)。
//
// 与真源的差异(报告口径):
// - 各站分类索引(`getCategores(1, 1000)`,与 AreasListController 同口径)
//   按站点缓存一次、失败不缓存下轮重试;真源每轮重取(它的接口轻,我们的
//   分类目录是千级条目重接口);
// - 每站请求显式带 `pageSize: kRecommendPerSite`;soop 热门接口上游忽略
//   pageSize 返回整页(sooplive main_broad_list_api 无条数字段),整页入桶
//   不截断防丢数据 —— 真源 BrowseSource 默认 30 同样整页入桶,口径一致;
// - LiveRoom 无分类 id 字段(仅 soop 把分类号借 typeName 承载,见
//   zishu_room_card.dart:96-101 同款读取),真源「同平台且房间自带 cid 直用
//   cid」分支仅 soop 生效。

import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/zishu/domain/category_display.dart';
import 'package:pure_live/zishu/domain/cross_categories_data_models.dart';

/// 推荐站点固定顺序(真源 [kRecommendSiteOrder = douyu, huya, bilibili,
/// douyin, ...] 的 pure_live 支持面裁剪:本仓库 [Sites.isSupported] 命中
/// 且 `getRecommendRooms` 有真实实现的前五个;顺序即展示权重)。
const List<String> kRecommendSiteOrder = <String>['douyu', 'huya', 'bilibili', 'douyin', 'soop'];

/// 每站每页取几条(真源 kRecommendPerSite = 3,web `RECOMMEND_PER_SITE`)。
const int kRecommendPerSite = 3;

/// 连续空页的最大重试轮数(真源 kRecommendEmptyPageRetries = 3)。
///
/// 各站分页粒度不同,某一页可能整页都是已在列表里的房间;不重试就会误判
/// 「没有更多了」。
const int kRecommendEmptyPageRetries = 3;

/// 分类兜底提示文案(真源 :57:映射到该站分类但该分类无结果,已改用热门)。
const String kRecommendCategoryFallbackHint = '当前分类暂无推荐，已为你展示热门直播';

/// 综合兜底提示文案(真源 :60:分类上下文整体无结果,已改用全站热门)。
const String kRecommendMixedFallbackHint = '已展示综合推荐';

/// 分类目录拉取口径(与 AreasListController.fetchAllServerData 同值:
/// `getCategores(1, 1000)`)。
const int _kCategoryPageSize = 1000;

/// 当前可推荐站点:固定顺序 ∩ 本仓库支持的平台(真源 `recommendSites()`
/// :64-67 的 supportedSiteIds 过滤口径)。
List<String> recommendSites() => <String>[
  for (final site in kRecommendSiteOrder)
    if (Sites.isSupported(site)) site,
];

/// 分类名归一(真源 :73-82 逐行移植):去首尾空白 + 转小写 + 去掉内部空白
/// 与常见分隔符。各平台分类文案大小写/间距不一(「英雄联盟」/「英雄 联盟」
/// /「LOL」),映射必须先把噪声抹平,否则同名分类也匹配不上。
String normalizeRecommendCategory(String value) {
  final buffer = StringBuffer();
  for (final rune in value.trim().toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    if (ch.trim().isEmpty) continue;
    if (ch == '-' || ch == '_' || ch == '·' || ch == '/') continue;
    buffer.write(ch);
  }
  return buffer.toString();
}

/// 能否推荐给用户(真源 [isRecommendableRoom] :119-120:状态真源判在播,
/// 不用 online/统计数字推断)。LiveRoom 侧同义判据是 [LiveRoom.isLiveNow]
/// (live_room.dart:528,effectiveLiveStatus == live)。
bool isRecommendableRoom(LiveRoom room) => room.isLiveNow;

/// 把当前房间的分类定位到 [site] 平台的分类项(真源 `mapRecommendCid`
/// :91-115 口径的 LiveArea 版)。
///
/// - 先用跨平台条目里该站的分类 cid 直连(soop/bilibili 走 `siteCids`,
///   斗鱼/虎牙/抖音走顶层级字段)—— cid 命中最准,不做名字匹配;
/// - 再按**分类名**在该站分类索引里找:归一后先精确,再双向包含
///   (「英雄联盟」↔「英雄联盟手游」这类带后缀的档名,真源 :109-113);
/// - 依次尝试跨平台 canonical 名与当前房间原始名(真源只比原始名;
///   canonical 名先试可让跨平台命中更稳,原始名兜底覆盖表外分类);
/// - 找不到返回 null,由调用方走热门兜底。
LiveArea? mapRecommendArea({
  required String site,
  required List<LiveArea>? index,
  required CrossCategoryEntry? entry,
  required String rawName,
}) {
  if (index == null || index.isEmpty) return null;

  if (entry != null) {
    final cidHits = <String>{};
    for (final cid in entry.siteCids[site] ?? const <String>[]) {
      final text = cid.trim();
      if (text.isNotEmpty) cidHits.add(text);
    }
    final topLevel = switch (site) {
      'douyu' => entry.douyu,
      'huya' => entry.huya,
      'douyin' => entry.douyin,
      _ => null,
    };
    if (topLevel != null && topLevel.trim().isNotEmpty) cidHits.add(topLevel.trim());
    if (cidHits.isNotEmpty) {
      for (final area in index) {
        final id = (area.areaId ?? '').trim();
        if (id.isNotEmpty && cidHits.contains(id)) return area;
      }
    }
  }

  final candidates = <String>[if (entry != null) entry.name, rawName];
  for (final name in candidates) {
    final target = normalizeRecommendCategory(name);
    if (target.isEmpty) continue;
    for (final area in index) {
      if (normalizeRecommendCategory(area.areaName ?? '') == target) return area;
    }
    for (final area in index) {
      final name2 = normalizeRecommendCategory(area.areaName ?? '');
      if (name2.isEmpty) continue;
      if (name2.contains(target) || target.contains(name2)) return area;
    }
  }
  return null;
}

/// 按站点桶交错合并出展示列表(真源 :127-153 逐行移植,RoomRecord → LiveRoom)。
///
/// 逐轮(i=0,1,2…)遍历站点顺序各取第 i 条:多平台混合、且每站内部保持
/// 接口侧的相关度排序。合并时顺手做三件事 —— 跳过未开播、剔除当前房间、按
/// `platform:roomId` 去重(跨站同号房间也算不同房间)。
List<LiveRoom> interleaveRecommendBuckets({
  required List<String> sites,
  required Map<String, List<LiveRoom>> buckets,
  required int perSite,
  required String currentIdentityKey,
}) {
  var maxLen = perSite;
  for (final site in sites) {
    final length = buckets[site]?.length ?? 0;
    if (length > maxLen) maxLen = length;
  }
  final seen = <String>{};
  final result = <LiveRoom>[];
  for (var index = 0; index < maxLen; index++) {
    for (final site in sites) {
      final bucket = buckets[site];
      if (bucket == null || index >= bucket.length) continue;
      final room = bucket[index];
      if (!isRecommendableRoom(room)) continue;
      if (room.identityKey == currentIdentityKey) continue;
      if (!seen.add(room.identityKey)) continue;
      result.add(room);
    }
  }
  return result;
}

/// 单站一页的取数结果(真源 `_SiteFetch` :257-274 同构)。
class _SiteFetch {
  const _SiteFetch({
    required this.rooms,
    required this.hasMore,
    this.usedCategoryFallback = false,
    this.usedHotOnly = false,
  });

  final List<LiveRoom> rooms;
  final bool hasMore;

  /// 分类线路取数为空 → 改用该站热门(分类兜底)。
  final bool usedCategoryFallback;

  /// 该站没有分类映射,本来就走热门(有分类上下文时才需要提示)。
  final bool usedHotOnly;
}

/// 播放页侧栏「推荐」编排控制器(真源 `PlayRecommendController` 的 GetX 版)。
///
/// 面板只消费本类的 Rx 状态;取数/合并/分页/兜底全在这里。实例由面板
/// State 持有(initState 创建、dispose 关闭,不走 Get 全局注册 —— 单播放
/// 页场景无跨页共享诉求,避开 tag 管理与注册表残留)。
class RecommendStreamController extends GetxController {
  // 私有字段无法走命名 initializing formal(Dart 尚无 private named
  // parameters),lint 的 this._room 建议不可行,就地豁免。
  // ignore: prefer_initializing_formals
  RecommendStreamController({required LiveRoom room}) : _room = room {
    _recomputeContext();
  }

  /// 当前房间快照(切房/分类上下文变化经 [rebind] 换入)。
  LiveRoom _room;

  /// 当前房间稳定键(`platform:roomId`),用于展示时剔除自己。
  String get _currentIdentityKey => _room.identityKey;

  // ---- 分类上下文(当前房间 → 跨平台归一) -------------------------------

  /// 当前房间原始分类名(trim 后;空串 = 无分类上下文)。
  String _rawCategoryName = '';

  /// 当前房间分类的跨平台归一条目(findCrossCategory 结果;null = 表外)。
  late CrossCategoryEntry? _crossEntry;

  void _recomputeContext() {
    final site = _room.normalizedPlatformId;
    final rawName = (_room.area ?? '').trim();
    // soop 把房间分类号借 typeName 承载(zishu_room_card.dart:96-101 同款
    // 读取),作 cid 传给 findCrossCategory:韩文原生名不在 cross 别名表时
    // 仍可靠 cid 命中。其它平台 typeName 是分组名,有自身语义,不传。
    final cidText = site == Sites.soopSite ? (_room.typeName ?? '').trim() : '';
    _rawCategoryName = rawName;
    _crossEntry = findCrossCategory(site, rawName, cidText);
  }

  /// 是否有分类上下文(真源 `_hasContext` :300-301:分类名或 cid 任一非空;
  /// 本仓库无 cid 字段,以归一条目或原始名非空为准)。
  bool get _hasContext => _crossEntry != null || _rawCategoryName.isNotEmpty;

  // ---- 对面板暴露的 Rx 状态(真源 `PlayRecommendState` 字段一一对应) ----

  /// 已合并好的展示列表(跨站交错、已过滤)。
  final RxList<LiveRoom> rooms = <LiveRoom>[].obs;

  /// 首屏骨架占位卡数量(>0 时面板渲染灰底占位)。
  final RxInt placeholderCount = 0.obs;

  /// 首屏加载中。
  final RxBool loading = false.obs;

  /// 追加加载中。
  final RxBool loadingMore = false.obs;

  /// 是否还有更多(任一站点还有下一页)。
  final RxBool hasMore = true.obs;

  /// 兜底提示文案(空串 = 不提示)。
  final RxString fallbackHint = ''.obs;

  /// 错误/空态文案(空串 = 无)。
  final RxString error = ''.obs;

  // ---- 编排内部状态(非响应式;真源同名字段同义) -------------------------

  /// 站点桶(原始取数结果,未过滤;展示时统一交错 + 过滤)。
  final Map<String, List<LiveRoom>> _buckets = <String, List<LiveRoom>>{};

  /// 各站是否还有下一页。
  final Map<String, bool> _siteHasMore = <String, bool>{};

  /// 命中「分类映射成功但分类无结果 → 热门兜底」的站点。
  final Set<String> _categoryFallbackSites = <String>{};

  /// 没有分类映射、直接走热门的站点(有分类上下文时用于提示)。
  final Set<String> _hotOnlySites = <String>{};

  /// 各站分类索引缓存(站点分类目录与当前房间无关,跨轮/跨房复用;
  /// 真源每轮重取 —— 它接口轻,我们千级目录不该每轮重打)。
  final Map<String, List<LiveArea>?> _categoryIndex = <String, List<LiveArea>?>{};

  int _page = 1;
  bool _busy = false;
  bool _forcedMixed = false;

  /// 加载代际:rebind 切房时自增。旧请求的收尾写状态前比对代际,过期即
  /// 静默让位(真源靠 Riverpod family 的 autoDispose 换实例实现同语义;
  /// 本控制器实例跨切房复用,需要显式代际)。
  int _generation = 0;

  /// rebind 落在加载中时的补跑标记:当前加载结束后再排一轮首屏。
  bool _pendingFirst = false;

  /// 首屏加载(面板 initState 的 microtask 里调用;防重入,rebind 竞态时
  /// 排队补跑)。
  Future<void> loadFirst() async {
    if (_busy) {
      _pendingFirst = true;
      return;
    }
    _busy = true;
    final generation = ++_generation;
    final sites = recommendSites();
    _resetBuckets(sites);
    placeholderCount.value = kRecommendPerSite * sites.length;
    loading.value = true;
    loadingMore.value = false;
    hasMore.value = true;
    try {
      await _loadPage(1, sites: sites);
      if (isClosed || generation != _generation) return;
      if (_display(sites).isEmpty && _hasContext) {
        // 有分类上下文却一条都没取到 → 退到「全站热门」(真源 :320-325,
        // web 同样退到综合推荐)。
        _resetBuckets(sites);
        _forcedMixed = true;
        await _loadPage(1, sites: sites, forceHot: true);
        if (isClosed || generation != _generation) return;
      }
      final display = _display(sites);
      rooms.assignAll(display);
      loading.value = false;
      placeholderCount.value = 0;
      hasMore.value = display.isNotEmpty && _anySiteHasMore(sites);
      fallbackHint.value = display.isEmpty ? '' : _hint(sites);
      error.value = display.isEmpty ? '暂无推荐' : '';
    } catch (_) {
      if (isClosed || generation != _generation) return;
      loading.value = false;
      placeholderCount.value = 0;
      hasMore.value = false;
      error.value = '加载失败，请稍后重试';
    } finally {
      _busy = false;
      // 加载期间来过 rebind:结束后补一轮,保证最终状态对齐最新房间上下文。
      if (_pendingFirst && !isClosed) {
        _pendingFirst = false;
        unawaited(Future<void>.microtask(loadFirst));
      }
    }
  }

  /// 追加下一页(滚动到底部触发;真源 loadMore :348-388 语义逐行移植)。
  Future<void> loadMore() async {
    if (_busy || loading.value || loadingMore.value || !hasMore.value) return;
    _busy = true;
    final generation = _generation;
    final sites = recommendSites();
    final active = <String>[
      for (final site in sites)
        if (_siteHasMore[site] ?? false) site,
    ];
    loadingMore.value = true;
    try {
      if (active.isEmpty) {
        loadingMore.value = false;
        hasMore.value = false;
        return;
      }
      var page = _page + 1;
      var attempts = 0;
      while (attempts < kRecommendEmptyPageRetries) {
        final before = rooms.length;
        await _loadPage(page, sites: active);
        if (isClosed || generation != _generation) return;
        _page = page;
        rooms.assignAll(_display(sites));
        if (rooms.length > before) break;
        if (!_anySiteHasMore(sites)) break;
        attempts += 1;
        page += 1;
      }
      final display = rooms.toList(growable: false);
      hasMore.value = _anySiteHasMore(sites);
      fallbackHint.value = display.isEmpty ? '' : _hint(sites);
      error.value = display.isEmpty ? '暂无推荐' : '';
    } catch (_) {
      // 追加失败保留已有列表,只收起「还有更多」,避免滚动时反复空转
      // (真源 :381-384 同款)。
      if (isClosed || generation != _generation) return;
      hasMore.value = false;
    } finally {
      _busy = false;
      // 无条件收起:即使本轮因切房代际过期让位,新一轮流也不会置回 true,
      // 不重置会让底部「加载更多…」悬挂。
      loadingMore.value = false;
    }
  }

  /// 切房 / 当前房间分类上下文变化时重置编排并重拉首屏。
  ///
  /// identityKey + 分类名 + soop 分类号任一变化才算切房;面板在
  /// didUpdateWidget 里调用,重载经 microtask 派发,保证不在构建/更新周期内
  /// 触发请求(真源面板 initState/didUpdateWidget 同款时序)。
  void rebind(LiveRoom room) {
    final contextKey =
        '${room.identityKey}|${(room.area ?? '').trim()}|'
        '${room.normalizedPlatformId == Sites.soopSite ? (room.typeName ?? '').trim() : ''}';
    final oldContextKey =
        '$_currentIdentityKey|$_rawCategoryName|'
        '${_room.normalizedPlatformId == Sites.soopSite ? (_room.typeName ?? '').trim() : ''}';
    if (contextKey == oldContextKey) return;
    _room = room;
    _recomputeContext();
    // 代际自增:在途请求的收尾写状态前比对代际,过期即让位;新首屏经
    // microtask 派发(若恰有加载在途,loadFirst 会转成排队补跑)。
    _generation++;
    unawaited(Future<void>.microtask(loadFirst));
  }

  void _resetBuckets(List<String> sites) {
    _buckets.clear();
    _siteHasMore.clear();
    _categoryFallbackSites.clear();
    _hotOnlySites.clear();
    _forcedMixed = false;
    _page = 1;
    for (final site in sites) {
      _buckets[site] = <LiveRoom>[];
      _siteHasMore[site] = true;
    }
  }

  /// 拉取 [sites] 的 [page] 页并合并进站点桶(真源 `_loadPage` :407-447)。
  Future<void> _loadPage(int page, {required List<String> sites, bool forceHot = false}) async {
    if (sites.isEmpty) return;
    final fetched = await Future.wait(<Future<_SiteFetch>>[
      for (final site in sites) _fetchSite(site, page, forceHot: forceHot),
    ]);
    if (isClosed) return;
    for (var index = 0; index < sites.length; index++) {
      final site = sites[index];
      final result = fetched[index];
      final bucket = _buckets.putIfAbsent(site, () => <LiveRoom>[]);
      final seen = <String>{for (final room in bucket) room.identityKey};
      for (final room in result.rooms) {
        // 整页入桶不截断:soop 热门接口上游忽略 pageSize,截断会跳过该页
        // 其余房间(真源 BrowseSource 默认 30 同样整页入桶)。
        if (seen.add(room.identityKey)) bucket.add(room);
      }
      _siteHasMore[site] = result.hasMore;
      if (result.usedCategoryFallback) {
        _categoryFallbackSites.add(site);
      } else {
        _categoryFallbackSites.remove(site);
      }
      if (result.usedHotOnly) {
        _hotOnlySites.add(site);
      } else {
        _hotOnlySites.remove(site);
      }
    }
  }

  /// 某站分类索引:拉一次并缓存;失败不缓存,下一轮重试(真源每轮都重取)。
  Future<List<LiveArea>?> _indexFor(String site) async {
    if (_categoryIndex.containsKey(site)) return _categoryIndex[site];
    try {
      final categories = await Sites.of(site).liveSite.getCategores(1, _kCategoryPageSize);
      final flat = <LiveArea>[for (final category in categories) ...category.children];
      _categoryIndex[site] = flat;
    } catch (_) {
      // 目录失败按无分类处理:该站本轮走热门,不拖垮别的站。
      return null;
    }
    return _categoryIndex[site];
  }

  /// 单站一页取数:分类线路优先,空/失败回落该站热门(真源 `_fetchSite`
  /// :482-527 逐段移植)。
  Future<_SiteFetch> _fetchSite(String site, int page, {required bool forceHot}) async {
    if (!forceHot) {
      // 同平台且房间自带分类号(soop typeName)时不需要目录映射,跳过目录
      // 请求 —— 侧栏推荐是次级请求,不该为它多打一轮网络(真源
      // `_loadCategories` :460-463 的跳过口径)。
      final needIndex = !(site == _room.normalizedPlatformId && (_room.typeName ?? '').trim().isNotEmpty);
      final index = needIndex ? await _indexFor(site) : null;
      final area = mapRecommendArea(site: site, index: index, entry: _crossEntry, rawName: _rawCategoryName);
      if (area != null) {
        try {
          final related = await Sites.of(site).liveSite.getCategoryRooms(area, page: page, pageSize: kRecommendPerSite);
          if (related.isNotEmpty) {
            return _SiteFetch(rooms: related, hasMore: related.length >= kRecommendPerSite);
          }
        } catch (_) {
          // 分类线路失败 → 落到下面的热门兜底(真源 :510-513)。
        }
        final hot = await _fetchHot(site, page);
        return _SiteFetch(rooms: hot.rooms, hasMore: hot.hasMore, usedCategoryFallback: hot.rooms.isNotEmpty);
      }
    }
    final hot = await _fetchHot(site, page);
    return _SiteFetch(rooms: hot.rooms, hasMore: hot.hasMore, usedHotOnly: !forceHot);
  }

  /// 该站推荐(热门)列表(真源 `_fetchHot` :530-541):失败单站隔离 ——
  /// 本站留空、无更多,不影响其它站。
  Future<_SiteFetch> _fetchHot(String site, int page) async {
    try {
      final result = await Sites.of(site).liveSite.getRecommendRooms(page: page, pageSize: kRecommendPerSite);
      return _SiteFetch(rooms: result, hasMore: result.length >= kRecommendPerSite);
    } catch (_) {
      return const _SiteFetch(rooms: <LiveRoom>[], hasMore: false);
    }
  }

  List<LiveRoom> _display(List<String> sites) => interleaveRecommendBuckets(
    sites: sites,
    buckets: _buckets,
    perSite: kRecommendPerSite,
    currentIdentityKey: _currentIdentityKey,
  );

  bool _anySiteHasMore(List<String> sites) => <String>[
    for (final site in sites)
      if (_siteHasMore[site] ?? false) site,
  ].isNotEmpty;

  /// 兜底提示(真源 `_hint` :557-564):分类兜底 > 综合兜底;分类映射全部
  /// 命中则不提示。
  String _hint(List<String> sites) {
    if (_categoryFallbackSites.isNotEmpty) return kRecommendCategoryFallbackHint;
    if (_forcedMixed) return kRecommendMixedFallbackHint;
    if (_hasContext && _hotOnlySites.length == sites.length) return kRecommendMixedFallbackHint;
    return '';
  }
}
